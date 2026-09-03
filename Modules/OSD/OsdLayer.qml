import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * Transient overlay for volume and mute changes.
 *
 * Only reacts to changes after startup - binding straight to Audio.volume would
 * flash an OSD the moment the shell loads and pipewire reports its first value.
 */
Scope {
    id: scope

    // "volume" | "mute" | "micmute" | "caps" | "num" | "scroll" | "layout"
    property string kind: ""
    property bool ready: false

    /*
     * What the card is drawing, as opposed to what is currently being asked for.
     *
     * `kind` clears the moment the OSD is dismissed, and the window is now held
     * past that point so the close animation has something to run on. Every
     * content binding used to read `kind` directly, so for the length of that
     * animation they all saw "" - which is neither a lock nor text, and so fell
     * through to the audio layout. A Caps Lock OSD spent its last 200ms turning
     * into a volume readout.
     *
     * This latches the last thing actually shown and never goes back to empty,
     * so the card looks the same on the way out as it did on the way in. Only
     * `shown` and the loader's `active` read the live `kind`.
     */
    property string displayKind: ""

    readonly property bool isLock:
        displayKind === "caps" || displayKind === "num" || displayKind === "scroll"

    readonly property bool isText: isLock || displayKind === "layout"

    function show(k) {
        if (!Settings.osd.enabled) return;
        if (k === "volume"  && !Settings.osd.onVolume) return;
        if (k === "mute"    && !Settings.osd.onMute) return;
        if (k === "micmute" && !Settings.osd.onMicMute) return;
        if ((k === "caps" || k === "num" || k === "scroll") && !Settings.osd.onLocks) return;
        if (k === "layout" && !Settings.osd.onKeyboardLayout) return;
        kind = k;
        hideTimer.restart();
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

    // Both jobs in one handler: an object gets exactly one Component.onCompleted,
    // and declaring a second is a load-time failure rather than an override.
    Component.onCompleted: {
        readyTimer.start();
        scope.syncLockPolling();
    }

    Timer { id: readyTimer; interval: 1200; onTriggered: scope.ready = true }
    Timer { id: hideTimer; interval: Settings.osd.timeout; onTriggered: scope.kind = "" }

    Connections {
        target: Audio
        function onVolumeChanged()   { if (scope.ready) scope.show("volume"); }
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
        if (scope.kind === "") {
            osdHold.restart();
        } else {
            scope.displayKind = scope.kind;
            osdHold.stop();
        }
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

            readonly property bool isMic: scope.displayKind === "micmute"
            readonly property bool muted: isMic ? Audio.micMuted : Audio.muted
            readonly property real level: isMic ? Audio.micVolume : Audio.volume
            readonly property color tint: muted ? Theme.danger
                                        : (isMic ? Theme.warn : Theme.accent)

            readonly property bool lockOn: {
                switch (scope.displayKind) {
                case "caps":   return Locks.caps;
                case "num":    return Locks.num;
                case "scroll": return Locks.scroll;
                }
                return true;
            }

            // Lit when the lock is engaged, dim when it has just been released -
            // the OSD fires on both edges and "Caps Lock / Off" in the same
            // colour as "Caps Lock / On" is the wrong signal at a glance.
            readonly property color textTint:
                scope.displayKind === "layout" ? Theme.accent
                    : (lockOn ? Theme.accent : Theme.textMuted)

            /*
             * The OSD honours the "osd" motion category like every other
             * surface family.
             *
             * It used to be the one surface with no per-category motion at all:
             * a bare fade at Theme.durFast, so Curve, Direction and Duration
             * under Motion by category had nothing to act on and the three
             * controls did nothing whatsoever. The category now drives the
             * entrance and the exit, and "auto" resolves against the edge the
             * OSD is anchored to, so a top OSD drops in and a bottom one rises.
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

                    /*
                     * Sized to the content when there is no meter.
                     *
                     * The two audio styles have a known size - the arc is whatever
                     * the size setting says, the bar is a fixed 300x120 - so those
                     * stay declared. The lock and layout readouts do not: they are
                     * a glyph and one or two lines of text whose width depends on
                     * the layout name and the interface font. Forcing them into the
                     * bar's box is what pushed "ENGLISH (US)" through the bottom of
                     * the frame and over the serial.
                     */
                    readonly property bool sized: !scope.isText

                    width: sized
                        ? (Settings.osd.style === "arc"
                            ? Settings.osd.size + Theme.space5 * 2
                            : 300)
                        : Math.max(240, body.implicitWidth + Theme.space5 * 2)

                    height: sized
                        ? (Settings.osd.style === "arc"
                            ? Settings.osd.size + Theme.space5 * 2 + 20
                            : 120)
                        : body.implicitHeight + Theme.space5 * 2

                    serialSeed: "osd"
                    padding: Theme.space4

                    Column {
                        id: body
                        anchors.centerIn: parent
                        spacing: Theme.space2

                        CyberText {
                            // The audio heading only. The lock and layout readouts
                            // carry their own name, and this printed "OUTPUT" above
                            // a keyboard icon.
                            visible: !scope.isText
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: card.width - Theme.space4 * 2
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: win.isMic
                                ? (win.muted ? Settings.t("Microphone muted") : Settings.t("Microphone on"))
                                : (win.muted ? Settings.t("Output muted") : Settings.t("Output"))
                            role: "label"
                            color: win.tint
                        }

                        /*
                         * --- lock keys and layout
                         *
                         * A word and a state, not a meter. Caps Lock is on or off;
                         * drawing that as a ring at 0% or 100% would be a gauge of
                         * a boolean, and the layout has no numeric value at all.
                         */
                        Column {
                            visible: scope.isText
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Theme.space2

                            CyberText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    switch (scope.displayKind) {
                                    case "caps":   return "\uf023";
                                    case "num":    return "\uf292";
                                    case "scroll": return "\uf0d7";
                                    default:       return "\u2328";
                                    }
                                }
                                role: "icon"
                                font.pixelSize: Math.round(Settings.osd.size * 0.32)
                                color: win.textTint
                            }

                            CyberText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    switch (scope.displayKind) {
                                    case "caps":   return Settings.t("Caps Lock");
                                    case "num":    return Settings.t("Num Lock");
                                    case "scroll": return Settings.t("Scroll Lock");
                                    default:       return Compositor.keyboardLayout;
                                    }
                                }
                                role: "label"
                                bold: true
                                color: Theme.text
                            }

                            CyberText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: scope.isLock
                                text: win.lockOn ? Settings.t("On") : Settings.t("Off")
                                role: "micro"
                                color: win.textTint
                            }
                        }

                        // --- arc style
                        Item {
                            visible: !scope.isText && Settings.osd.style === "arc"
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Settings.osd.size
                            height: Settings.osd.size

                            ArcMeter {
                                anchors.fill: parent
                                value: win.muted ? 0 : win.level
                                fillColor: win.tint
                            }

                            // The number is anchored to the centre on its own, not
                            // as part of a stack: centring a Column of number+icon
                            // puts the number above the ring's true centre.
                            CyberText {
                                id: percentLabel
                                anchors.centerIn: parent
                                visible: Settings.osd.showPercent
                                text: win.muted ? "\u2014" : Math.round(win.level * 100) + "%"
                                role: "headline"
                                color: win.tint
                            }

                            CyberText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: percentLabel.bottom
                                anchors.topMargin: 2
                                text: win.isMic ? "\uf130" : (win.muted ? "\uf026" : "\uf028")
                                role: "icon"
                                color: Theme.textDim
                            }
                        }

                        // --- bar style
                        Row {
                            visible: !scope.isText && Settings.osd.style !== "arc"
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Theme.space3

                            CyberText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: win.isMic ? "\uf130" : (win.muted ? "\uf026" : "\uf028")
                                role: "icon"
                                color: win.tint
                            }

                            SegmentBar {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 180
                                height: 16
                                segments: 20
                                value: win.muted ? 0 : win.level
                                fillColor: win.tint
                                warnAtHigh: false
                            }

                            CyberText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: Settings.osd.showPercent
                                text: win.muted ? "\u2014" : Math.round(win.level * 100) + "%"
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
