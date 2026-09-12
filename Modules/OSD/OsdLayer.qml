import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.Config
import qs.Common
import qs.Services

/*
 * Transient overlay for volume, brightness, media keys, lock keys and layout.
 *
 * Two ways in:
 *
 *   - Watched state. Volume, mute and the microphone come from PipeWire the
 *     moment they change, lock keys from the LED watcher, the layout from the
 *     compositor. Only changes after startup count - binding straight to
 *     Audio.volume would flash an OSD the moment pipewire reports its first
 *     value.
 *
 *   - IPC from the compositor's key bindings: brightness and the media keys.
 *     Brightness is polled, so watching it would put the OSD up to four
 *     seconds behind the key; and MPRIS reports a new track the same way for
 *     Previous as for Next, so only the key itself can say which it was. See
 *     Ipc.qml, target "osd".
 *
 * --- one frame for everything
 *
 * Every message is drawn in the same card: a square on the left holding the
 * meter or a glyph, and a column on the right holding the prompt and one line
 * of detail. The card used to be three sizes - the arc, a fixed bar box, and
 * whatever a lock or layout readout measured - so a volume change followed by
 * Caps Lock jumped between frames. Now only the contents change. The text
 * column has a fixed width and elides rather than growing, which is what
 * keeps the frame fixed.
 */
Scope {
    id: scope

    // "volume" | "mute" | "micmute" | "brightness" | "media"
    // | "caps" | "num" | "scroll" | "layout"
    property string kind: ""
    property bool ready: false

    /*
     * What the card is drawing, as opposed to what is currently being asked for.
     *
     * `kind` clears the moment the OSD is dismissed, and the window is held
     * past that point so the close animation has something to run on. Content
     * bindings that read `kind` saw "" for the length of that animation and
     * fell through to another layout - a Caps Lock OSD spent its last 200ms
     * turning into a volume readout.
     *
     * These latch the last thing actually shown and never go back to empty, so
     * the card looks the same on the way out as it did on the way in. Only
     * `shown` and the loader's `active` read the live `kind`.
     */
    property string displayKind: ""

    // Which way, or which key, within the kind: "up" / "down" for volume and
    // brightness, "play" / "stop" / "previous" / "next" for media.
    property string displayDetail: ""

    readonly property bool isLock:
        displayKind === "caps" || displayKind === "num" || displayKind === "scroll"

    // Kinds with a level to draw; everything else gets a glyph in the square.
    readonly property bool isMeter:
        displayKind === "volume" || displayKind === "mute"
        || displayKind === "micmute" || displayKind === "brightness"

    function show(k, detail) {
        if (!Settings.osd.enabled) return;
        if (k === "volume"     && !Settings.osd.onVolume) return;
        if (k === "mute"       && !Settings.osd.onMute) return;
        if (k === "micmute"    && !Settings.osd.onMicMute) return;
        if (k === "brightness" && !Settings.osd.onBrightness) return;
        if (k === "media"      && !Settings.osd.onMedia) return;
        if ((k === "caps" || k === "num" || k === "scroll") && !Settings.osd.onLocks) return;
        if (k === "layout" && !Settings.osd.onKeyboardLayout) return;

        scope.displayKind = k;
        scope.displayDetail = detail || "";
        kind = k;
        hideTimer.restart();
    }

    // The player the media keys act on, chosen the way Quick Settings chooses
    // it: whichever is playing, else the first. playerctl without --player
    // lands on the same one in practice.
    readonly property MprisPlayer player: {
        const list = Mpris.players.values;
        return list.find(p => p.playbackState === MprisPlaybackState.Playing)
            || list[0] || null;
    }

    /*
     * Lock keys are watched rather than pushed, so the watcher only runs while
     * the OSD wants it. See Services/Locks.qml - there is no change
     * notification on the LED nodes, so leaving it running would be a resident
     * process for a feature that is off by default.
     */
    property bool holdingLocks: false

    function syncLockPolling() {
        const want = Settings.osd.enabled && Settings.osd.onLocks;
        if (want === scope.holdingLocks) return;
        scope.holdingLocks = want;
        if (want) Locks.acquire();
        else Locks.release();
    }

    Component.onDestruction: if (scope.holdingLocks) Locks.release()

    Connections {
        target: Settings.osd
        function onOnLocksChanged() { scope.syncLockPolling(); }
        function onEnabledChanged() { scope.syncLockPolling(); }
    }

    Connections {
        target: Locks
        function onCapsChanged()   { if (scope.ready) scope.show("caps"); }
        function onNumChanged()    { if (scope.ready) scope.show("num"); }
        function onScrollChanged() { if (scope.ready) scope.show("scroll"); }
    }

    Connections {
        target: Compositor
        function onKeyboardLayoutChanged() { if (scope.ready) scope.show("layout"); }
    }

    // From the key bindings, via Ipc.qml. Anything unrecognised is dropped
    // rather than drawn as a blank card.
    Connections {
        target: Shell
        function onOsdRequested(k, detail) {
            if (k === "media"
                && ["play", "stop", "previous", "next"].indexOf(detail) !== -1)
                scope.show(k, detail);
            else if (k === "brightness" && (detail === "up" || detail === "down"))
                scope.show(k, detail);
        }
    }

    /*
     * The last volume seen, so a change can say which way it went.
     *
     * Tracked from the start, before `ready`: otherwise the first press after
     * startup is compared against zero and always reads as "+".
     */
    property real lastVolume: 0

    // Both jobs in one handler: an object gets exactly one Component.onCompleted,
    // and declaring a second is a load-time failure rather than an override.
    Component.onCompleted: {
        scope.lastVolume = Audio.volume;
        readyTimer.start();
        scope.syncLockPolling();
    }

    Timer { id: readyTimer; interval: 1200; onTriggered: scope.ready = true }
    Timer { id: hideTimer; interval: Settings.osd.timeout; onTriggered: scope.kind = "" }

    Connections {
        target: Audio
        function onVolumeChanged() {
            const dir = Audio.volume >= scope.lastVolume ? "up" : "down";
            scope.lastVolume = Audio.volume;
            if (scope.ready) scope.show("volume", dir);
        }
        function onMutedChanged()    { if (scope.ready) scope.show("mute"); }
        function onMicMutedChanged() { if (scope.ready) scope.show("micmute"); }
    }

    /*
     * Held past the flag, the same way SurfaceHolder holds the shell's other
     * popups. Tearing the window down the instant `kind` clears leaves the
     * close animation nothing to run on, so the OSD would still vanish
     * instantly however long the category's Duration was set to.
     */
    Timer {
        id: osdHold
        interval: Math.round(Theme.durationFor("osd") * 0.85) + 60
    }

    onKindChanged: {
        if (scope.kind === "") osdHold.restart();
        else osdHold.stop();
    }

    LazyLoader {
        active: scope.kind !== "" || osdHold.running

        PanelWindow {
            id: win
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "bw77-osd"

            readonly property string pos: Settings.osd.position
            readonly property bool onTop: pos.indexOf("top") !== -1
            readonly property bool onCenterX: pos.indexOf("center") !== -1
            readonly property bool onRight: pos.indexOf("right") !== -1

            anchors {
                top: win.onTop
                bottom: !win.onTop
                left: !win.onCenterX && !win.onRight
                right: !win.onCenterX && win.onRight
            }
            margins { top: 60; bottom: 90; left: 60; right: 60 }

            implicitWidth: card.width + 40
            implicitHeight: card.height + 40
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}          // display only, never takes input

            readonly property string kindShown: scope.displayKind
            readonly property string detailShown: scope.displayDetail

            readonly property bool isMic: kindShown === "micmute"
            readonly property bool isBrightness: kindShown === "brightness"

            readonly property bool muted:
                isBrightness ? false : (isMic ? Audio.micMuted : Audio.muted)

            readonly property real level:
                isBrightness ? Brightness.fraction : (isMic ? Audio.micVolume : Audio.volume)

            readonly property bool playing: scope.player !== null
                && scope.player.playbackState === MprisPlaybackState.Playing

            readonly property bool lockOn: {
                switch (kindShown) {
                case "caps":   return Locks.caps;
                case "num":    return Locks.num;
                case "scroll": return Locks.scroll;
                }
                return true;
            }

            // Arc on the left only for a level in the arc style; the bar style
            // and every non-meter message put a glyph there instead.
            readonly property bool arcMode: scope.isMeter && Settings.osd.style === "arc"

            /*
             * Lit when a lock is engaged and dim when it has just been
             * released - the OSD fires on both edges, and "Caps Lock / Off" in
             * the same colour as "Caps Lock / On" is the wrong signal at a
             * glance. Media takes the media widgets' own accent.
             */
            readonly property color tint: {
                switch (kindShown) {
                case "media":   return Theme.warn;
                case "layout":  return Theme.accent;
                case "caps":
                case "num":
                case "scroll":  return win.lockOn ? Theme.accent : Theme.textMuted;
                case "micmute": return win.muted ? Theme.danger : Theme.warn;
                case "brightness": return Theme.accent;
                }
                return win.muted ? Theme.danger : Theme.accent;
            }

            readonly property string glyph: {
                switch (kindShown) {
                case "caps":       return "\uf023";
                case "num":        return "\uf292";
                case "scroll":     return "\uf0d7";
                case "layout":     return "\u2328";
                case "brightness": return "\uf185";
                case "micmute":    return win.muted ? "\uf131" : "\uf130";
                case "media":
                    switch (detailShown) {
                    case "stop":     return "\uf04d";
                    case "previous": return "\uf048";
                    case "next":     return "\uf051";
                    }
                    return win.playing ? "\uf04b" : "\uf04c";
                }
                return win.muted ? "\uf026" : "\uf028";
            }

            /*
             * The prompt names the key that was pressed, not the state it left.
             *
             * Play is the one exception: XF86AudioPlay is play-pause, so it is
             * answered with what the player actually did. The binding is live,
             * so if the player reports its new state a moment after the IPC
             * call arrives, the card corrects itself rather than showing a
             * guess for the rest of its time on screen.
             */
            readonly property string prompt: {
                switch (kindShown) {
                case "volume":
                    return Settings.t(detailShown === "down" ? "Volume -" : "Volume +");
                case "mute":
                    return Settings.t(win.muted ? "Muted" : "Unmuted");
                case "micmute":
                    return Settings.t(win.muted ? "Microphone muted" : "Microphone on");
                case "brightness":
                    return Settings.t(detailShown === "down" ? "Brightness -" : "Brightness +");
                case "caps":   return Settings.t("Caps Lock");
                case "num":    return Settings.t("Num Lock");
                case "scroll": return Settings.t("Scroll Lock");
                case "layout": return Compositor.keyboardLayout;
                case "media":
                    switch (detailShown) {
                    case "stop":     return "[STOP]";
                    case "previous": return "[PREVIOUS]";
                    case "next":     return "[NEXT]";
                    }
                    return win.playing ? "[PLAY]" : "[PAUSE]";
                }
                return "";
            }

            readonly property string detailLine: {
                switch (kindShown) {
                case "volume":
                case "mute":
                    return Audio.sinkName;
                case "micmute":
                    return Audio.source
                        ? (Audio.source.description || Audio.source.name)
                        : Settings.t("Microphone");
                case "brightness":
                    return Settings.t("Display");
                case "caps":
                case "num":
                case "scroll":
                    return win.lockOn ? Settings.t("On") : Settings.t("Off");
                case "layout":
                    return Settings.t("Keyboard layout");
                case "media": {
                    if (!scope.player) return Settings.t("Nothing playing");
                    const title = scope.player.trackTitle || Settings.t("Unknown track");
                    const artist = scope.player.trackArtist || "";
                    return artist !== "" ? title + " \u2014 " + artist : title;
                }
                }
                return "";
            }

            readonly property string percentText:
                win.muted ? "\u2014" : Math.round(win.level * 100) + "%"

            // The one size setting drives the whole card: the square is the
            // size, and the text column is a fixed proportion of it.
            readonly property int visual: Settings.osd.size
            readonly property int textWidth: Math.max(180, Math.round(Settings.osd.size * 1.45))

            /*
             * The OSD honours the "osd" motion category like every other
             * surface family: Curve, Direction and Duration under Motion by
             * category drive the entrance and the exit, and "auto" resolves
             * against the edge the OSD is anchored to, so a top OSD drops in
             * and a bottom one rises.
             */
            GlitchBox {
                id: osdAnim
                anchors.fill: parent
                category: "osd"
                shown: scope.kind !== ""
                autoDirection: win.onTop ? "down" : "up"

                Panel {
                    id: card
                    anchors.centerIn: parent

                    serialSeed: "osd"
                    padding: Theme.space4

                    // Identical for every message. The extra 16 is room for
                    // the serial along the bottom edge.
                    width: win.visual + Theme.space4 + win.textWidth + padding * 2
                    height: win.visual + padding * 2 + 16

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.space4

                        // --- left: the meter, or the glyph
                        Item {
                            width: win.visual
                            height: win.visual

                            ArcMeter {
                                visible: win.arcMode
                                anchors.fill: parent
                                value: win.muted ? 0 : win.level
                                fillColor: win.tint
                            }

                            // The number is anchored to the centre on its own,
                            // not as part of a stack: centring a Column of
                            // number+icon puts the number above the ring's
                            // true centre.
                            CyberText {
                                id: percentLabel
                                anchors.centerIn: parent
                                visible: win.arcMode && Settings.osd.showPercent
                                text: win.percentText
                                role: "headline"
                                color: win.tint
                            }

                            CyberText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: percentLabel.bottom
                                anchors.topMargin: 2
                                visible: win.arcMode
                                text: win.glyph
                                role: "icon"
                                color: Theme.textDim
                            }

                            CyberText {
                                anchors.centerIn: parent
                                visible: !win.arcMode
                                text: win.glyph
                                role: "icon"
                                font.pixelSize: Math.round(win.visual * 0.36)
                                color: win.tint
                            }
                        }

                        // --- right: what was pressed, and on what
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: win.textWidth
                            spacing: Theme.space2

                            CyberText {
                                width: parent.width
                                text: win.prompt
                                role: "title"
                                bold: true
                                elide: Text.ElideRight
                                color: win.tint
                            }

                            CyberText {
                                width: parent.width
                                visible: text !== ""
                                text: win.detailLine
                                role: "label"
                                caps: false
                                elide: Text.ElideRight
                                color: Theme.textDim
                            }

                            // The bar style's meter lives under the prompt,
                            // since its square holds the glyph.
                            Row {
                                visible: scope.isMeter && !win.arcMode
                                width: parent.width
                                spacing: Theme.space2

                                SegmentBar {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - (pct.visible ? pct.width + parent.spacing : 0)
                                    height: 14
                                    segments: 16
                                    value: win.muted ? 0 : win.level
                                    fillColor: win.tint
                                    warnAtHigh: false
                                }

                                CyberText {
                                    id: pct
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: Settings.osd.showPercent
                                    text: win.percentText
                                    role: "mono"
                                    color: Theme.text
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
