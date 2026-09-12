import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * Full-screen wallpaper chooser, reachable from IPC or the bar.
 *
 *   qs -c bw77-shell ipc call wallpaper toggle
 *
 * The Control Center already has a wallpaper pane, but that pane is where you
 * go to configure wallpapers - the folder to scan, the niri backdrop, the
 * randomiser. Picking one is a different job that you do far more often.
 *
 * --- shape
 *
 * Built as a centred card on a dimmed backdrop, the same as the palette
 * switcher, rather than as a bare full-bleed grid. The two surfaces do the same
 * kind of job - pick one of these, apply it, get out - and they were the only
 * two shell surfaces that did not look like each other.
 *
 * --- the switch row
 *
 * Source, Style and Colour sit above the body as steppers. They are the whole
 * of what the picker can change beyond the image itself, and having them here
 * means the common case - switch to a theme colour, change the gradient, go
 * back to an image - never needs the Control Center at all.
 *
 * Style is the one switch whose meaning follows Source, because the two modes
 * have nothing in common to put there: for an image it is the transition used
 * when the wallpaper changes, and for a colour it is solid against gradient.
 * Colour has no meaning at all in image mode, so it dims and drops out of the
 * keyboard ring rather than sitting there accepting keys and doing nothing.
 *
 * --- keyboard
 *
 * Arrow keys and Enter or Space throughout, per the footer.
 *
 *   left / right   step the focused switch, or move across the grid
 *   up / down      move between the switch row and the body
 *   enter / space  confirm - advance the ring on a switch, apply on a tile
 *   tab            same as down, for anyone who expects it
 *
 * The ring is built rather than written out, so a disabled switch cannot be
 * focused and the grid is simply not in it when there is no grid.
 *
 * Tiles are square and images are cropped to fill rather than fitted inside:
 * a folder of 16:9 photos fitted into squares is a grid of letterboxed strips
 * with a third of every tile empty, and the eye has to work past the bars to
 * compare them. Cropping loses the edges of a wide photo, which costs nothing
 * when the thing being chosen is a background.
 */
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bw77-wallpaper-selector"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // Without this the compositor shrinks the surface out of the bar's reserved
    // zone, so the backdrop stops short of the bar and the dock.
    exclusionMode: ExclusionMode.Ignore

    /*
     * Announce that the surface actually got built.
     *
     * Without it, "the IPC handler was never reached", "the handler ran but the
     * SurfaceHolder never built anything" and "it is on screen and drawing
     * nothing" are indistinguishable from the outside, and they need three
     * completely different fixes. Same reason the colour picker carries one.
     * Read it with: qs -c bw77-shell ipc call wallpaper state
     */
    Component.onDestruction: Shell.wallpaperSelectorSurfaceAlive = false

    readonly property var files: Wallpapers.files
    property int highlight: 0

    readonly property bool colorMode: Settings.wallpaper.mode === "color"
    readonly property bool gradient: Settings.wallpaper.colorStyle === "gradient"

    // --- switch vocabulary

    // Same list the Control Center's colour editor offers, so the two surfaces
    // cannot drift apart on which roles are pickable.
    readonly property var roleChoices: [
        "bgDeep", "bgBase", "bgRaised", "bgOverlay", "bgHover", "bgActive",
        "accent", "accentDim", "accentGlow", "danger", "dangerDim",
        "warn", "gold", "magenta", "success", "border"
    ]

    readonly property var roleOptions: roleChoices.map(r => ({ v: r, l: r }))

    readonly property var sourceOptions: [
        { v: "image", l: Settings.t("Image") },
        { v: "color", l: Settings.t("Theme colour") }
    ]

    readonly property var transitionOptions: [
        { v: "glitch", l: Settings.t("Glitch") },
        { v: "fade",   l: Settings.t("Fade") },
        { v: "none",   l: Settings.t("None") }
    ]

    readonly property var colorStyleOptions: [
        { v: "solid",    l: Settings.t("Solid") },
        { v: "gradient", l: Settings.t("Gradient") }
    ]

    // --- keyboard ring
    //
    // Only what is actually reachable. "colour2" appears with the gradient's
    // second stop and "grid" only exists in image mode, so the ring is rebuilt
    // whenever the mode or the style changes.
    readonly property var ring: {
        const out = ["source", "style"];
        if (root.colorMode) {
            out.push("colour");
            if (root.gradient) out.push("colour2");
        } else {
            out.push("grid");
        }
        return out;
    }

    property string focusedStop: "source"

    // A stop that has just been removed from the ring - the gradient's second
    // stop when the style goes back to solid - must not keep the focus, or the
    // arrows land on a control that is no longer on screen.
    onRingChanged: {
        if (ring.indexOf(root.focusedStop) === -1)
            root.focusedStop = ring[0];
    }

    function focusBy(delta) {
        const at = root.ring.indexOf(root.focusedStop);
        const next = Math.max(0, Math.min(root.ring.length - 1,
                                          (at < 0 ? 0 : at) + delta));
        root.focusedStop = root.ring[next];
    }

    function focusStop(name) {
        if (root.ring.indexOf(name) !== -1) root.focusedStop = name;
    }

    // --- entrance

    function syncToCurrent() {
        const at = files.indexOf(Wallpapers.current);
        highlight = at >= 0 ? at : 0;
        grid.positionViewAtIndex(highlight, GridView.Contain);
    }

    Component.onCompleted: {
        Shell.wallpaperSelectorSurfaceAlive = true;
        // Deferred: the window has not been given its size yet, so the grid's
        // column count and cell size are still being computed against zero and
        // positionViewAtIndex has nothing meaningful to scroll to.
        Qt.callLater(syncToCurrent);
    }

    Connections {
        target: Shell
        function onWallpaperSelectorOpenChanged() {
            if (Shell.wallpaperSelectorOpen) {
                root.focusedStop = root.ring[0];
                Qt.callLater(root.syncToCurrent);
            }
        }
    }

    function applySelected(index) {
        if (index < 0 || index >= files.length) return;
        Wallpapers.set(files[index], "");
    }

    /*
     * --- backdrop: a click target, not a scrim.
     *
     * Covers the screen so a click outside dismisses, and paints nothing. The
     * card is opaque and bordered; the dimming was compensating for a legibility
     * problem it does not have.
     *
     * The full-screen scanlines went with it - they had the scrim to sit on and
     * would otherwise be a grid of lines over your live windows. The card draws
     * its own through Panel.
     */
    MouseArea {
        anchors.fill: parent
        onClicked: Shell.wallpaperSelectorOpen = false
    }

    GlitchBox {
        category: "menus"
        anchors.fill: parent
        shown: Shell.wallpaperSelectorOpen

        Panel {
            id: card

            anchors.centerIn: parent
            width: Math.min(parent.width - Theme.space6 * 2, 1180)
            height: Math.min(parent.height - Theme.space6 * 2, 760)

            // Matches the palette switcher and the quick settings panel: these
            // are surfaces in their own right, not cards resting on one, so
            // they take the base background rather than the raised tone.
            fillColor: Theme.bgBase
            serialSeed: "wallpaper"
            padding: Theme.space5

            SectionHeader {
                id: head
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                title: Settings.t("Wallpaper")
                subtitle: root.colorMode
                    ? `${Settings.t("Theme colour")} · ${Settings.wallpaper.colorStyle}`
                    : (Wallpapers.scanning
                        ? Settings.t("Scanning...")
                        : `${root.files.length} images · ${Settings.wallpaper.folder}`)
                accentColor: Theme.danger
            }

            // --- switch row
            Row {
                id: switches

                anchors.top: head.bottom
                anchors.topMargin: Theme.space4
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Theme.space4

                WallpaperSwitch {
                    width: 200
                    label: Settings.t("Source")
                    options: root.sourceOptions
                    current: Settings.wallpaper.mode
                    focused: root.focusedStop === "source"
                    accentColor: Theme.danger
                    onFocusRequested: root.focusStop("source")
                    onPicked: (v) => {
                        Settings.wallpaper.mode = v;
                        root.focusStop("source");
                    }
                }

                WallpaperSwitch {
                    width: 200
                    label: Settings.t("Style")
                    options: root.colorMode ? root.colorStyleOptions
                                            : root.transitionOptions
                    current: root.colorMode ? Settings.wallpaper.colorStyle
                                            : Settings.wallpaper.transition
                    focused: root.focusedStop === "style"
                    onFocusRequested: root.focusStop("style")
                    onPicked: (v) => {
                        if (root.colorMode) Settings.wallpaper.colorStyle = v;
                        else Settings.wallpaper.transition = v;
                        root.focusStop("style");
                    }
                }

                WallpaperSwitch {
                    width: 200
                    // Becomes "From" once there is a second stop to tell it
                    // apart from, which is how the Control Center's colour
                    // editor labels the same pair.
                    label: root.gradient ? Settings.t("From") : Settings.t("Colour")
                    enabled: root.colorMode
                    options: root.roleOptions
                    current: Settings.wallpaper.colorRole
                    focused: root.focusedStop === "colour"
                    accentColor: Theme.warn
                    onFocusRequested: root.focusStop("colour")
                    onPicked: (v) => {
                        Settings.wallpaper.colorRole = v;
                        // A literal hex overrides the role, so picking a role
                        // here has to clear it or nothing appears to happen.
                        Settings.wallpaper.colorCustom = "";
                        root.focusStop("colour");
                    }
                }

                WallpaperSwitch {
                    width: 200
                    label: Settings.t("To")
                    visible: root.colorMode && root.gradient
                    options: root.roleOptions
                    current: Settings.wallpaper.colorRole2
                    focused: root.focusedStop === "colour2"
                    accentColor: Theme.warn
                    onFocusRequested: root.focusStop("colour2")
                    onPicked: (v) => {
                        Settings.wallpaper.colorRole2 = v;
                        Settings.wallpaper.colorCustom2 = "";
                        root.focusStop("colour2");
                    }
                }
            }

            Rectangle {
                id: headRule
                anchors.top: switches.bottom
                anchors.topMargin: Theme.space4
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.alpha(Theme.danger, 0.55) }
                    GradientStop { position: 1.0; color: Theme.alpha(Theme.danger, 0.0) }
                }
            }

            // --- body: the grid, or the colour preview
            Item {
                id: body

                anchors.top: headRule.bottom
                anchors.topMargin: Theme.space4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: footRule.top
                anchors.bottomMargin: Theme.space4

                GridView {
                    id: grid

                    anchors.fill: parent
                    visible: !root.colorMode
                    clip: true
                    model: root.files
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 600

                    /*
                     * Square cells, sized to fill the row exactly.
                     *
                     * A fixed cell size leaves a ragged margin down the right
                     * that changes width with the window; deriving the count
                     * from a target size and then dividing the width by it
                     * keeps the grid flush at any width. The tile is square, so
                     * cellHeight follows.
                     */
                    readonly property int columns:
                        Math.max(2, Math.floor(width / (200 * Theme.scale)))

                    cellWidth: Math.floor(width / columns)
                    cellHeight: cellWidth

                    delegate: Item {
                        id: tile
                        required property string modelData
                        required property int index

                        readonly property bool current: modelData === Wallpapers.current
                        readonly property bool focused:
                            index === root.highlight && root.focusedStop === "grid"

                        width: grid.cellWidth
                        height: grid.cellHeight

                        Item {
                            anchors.fill: parent
                            anchors.margins: Theme.space1
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: "file://" + tile.modelData
                                // Fill the square and let the overflow be
                                // clipped. See the note at the top: fitting
                                // would letterbox every wide photo.
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                // Decoded at roughly tile size rather than full
                                // resolution: a folder of 4K photos decoded in
                                // full is hundreds of megabytes of thumbnails.
                                sourceSize.width: 480
                                sourceSize.height: 480
                            }

                            // Dim everything that is not the tile in play, so
                            // the grid reads as a selection, not a collage.
                            Rectangle {
                                anchors.fill: parent
                                color: Theme.bgDeep
                                opacity: (tile.focused || tile.current
                                          || tileMouse.containsMouse) ? 0.0 : 0.35
                                Behavior on opacity {
                                    NumberAnimation { duration: Theme.durFast }
                                }
                            }

                            NotchRect {
                                anchors.fill: parent
                                fillColor: "transparent"
                                strokeColor: tile.current ? Theme.accent
                                    : (tile.focused || tileMouse.containsMouse
                                        ? Theme.danger : Theme.alpha(Theme.border, 0.5))
                                strokeWidth: (tile.current || tile.focused) ? 2 : 1
                                notch: Theme.notch
                                notchTopLeft: false
                                notchTopRight: false
                                notchBottomRight: true
                                notchBottomLeft: false

                                // In step with the dimming above it, which was
                                // already easing while the frame it belongs to
                                // changed colour on the frame.
                                Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
                            }

                            // File name, only for the tile in play - a caption
                            // under every thumbnail is forty lines of path on
                            // screen at once.
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 22
                                color: Theme.alpha(Theme.bgDeep, 0.88)
                                opacity: tile.focused || tile.current
                                         || tileMouse.containsMouse ? 1 : 0
                                visible: opacity > 0.01

                                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

                                CyberText {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.space2
                                    anchors.rightMargin: Theme.space2
                                    verticalAlignment: Text.AlignVCenter
                                    text: tile.modelData.split("/").pop()
                                    role: "micro"
                                    caps: false
                                    elide: Text.ElideMiddle
                                    color: tile.current ? Theme.accent : Theme.text
                                }
                            }

                            // In-use marker, so the applied wallpaper is
                            // identifiable while the cursor is elsewhere.
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Theme.space2
                                width: 8
                                height: 8
                                rotation: 45
                                color: Theme.accent
                                visible: tile.current
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                root.highlight = tile.index;
                                root.focusStop("grid");
                            }
                            onClicked: root.applySelected(tile.index)
                        }
                    }

                    // Same crimson bar as everywhere else.
                    Rectangle {
                        parent: grid
                        x: grid.width - width
                        y: grid.contentHeight > 0
                            ? grid.visibleArea.yPosition * grid.height : 0
                        width: 3
                        height: Math.max(24, grid.visibleArea.heightRatio * grid.height)
                        color: Theme.alpha(Theme.danger, 0.85)
                        visible: grid.contentHeight > grid.height
                    }

                    // `parent: grid` for the same reason as the scrollbar
                    // above: a view puts its declared children into
                    // contentItem, which for an empty model has no size to
                    // centre anything in.
                    Column {
                        parent: grid
                        anchors.centerIn: grid
                        visible: root.files.length === 0 && !Wallpapers.scanning
                        spacing: Theme.space2

                        CyberText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Settings.t("No images in that folder")
                            role: "label"
                            color: Theme.textMuted
                        }

                        CyberText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Settings.wallpaper.folder
                            role: "micro"
                            caps: false
                            color: Theme.alpha(Theme.textMuted, 0.7)
                        }
                    }
                }

                // --- colour mode: what the switches are actually building
                //
                // The same construction the desktop uses - an oversized square
                // rotated for the angle, clipped to the frame - so this is a
                // preview rather than an approximation of one.
                NotchRect {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height * 16 / 9)
                    height: width * 9 / 16
                    visible: root.colorMode
                    fillColor: root.fillA
                    strokeColor: Theme.border
                    notch: Theme.notch

                    Item {
                        anchors.fill: parent
                        clip: true
                        visible: root.gradient

                        Item {
                            anchors.centerIn: parent
                            width: Math.sqrt(parent.width * parent.width
                                             + parent.height * parent.height)
                            height: width
                            rotation: Settings.wallpaper.gradientAngle

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: root.fillA }
                                    GradientStop { position: 1.0; color: root.fillB }
                                }
                            }
                        }
                    }

                    // Kept inside the frame so the preview reads as a desktop
                    // rather than as a swatch.
                    Scanlines { anchors.fill: parent; anchors.margins: 1 }

                    CyberText {
                        anchors.centerIn: parent
                        text: Settings.t("Preview")
                        role: "micro"
                        color: Theme.alpha(Theme.text, 0.6)
                    }
                }
            }

            Rectangle {
                id: footRule
                anchors.bottom: footer.top
                anchors.bottomMargin: Theme.space3
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.alpha(Theme.border, 0.8)
            }

            Item {
                id: footer
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 32

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space5

                    Repeater {
                        model: [
                            { k: "\u2190 \u2192",  t: Settings.t("Change"),  on: true },
                            { k: "\u2191 \u2193",  t: Settings.t("Move"),    on: true },
                            { k: "\u21B5",         t: Settings.t("Confirm"), on: true },
                            { k: "R",              t: Settings.t("Random"),  on: !root.colorMode },
                            { k: "F5",             t: Settings.t("Rescan"),  on: !root.colorMode }
                        ]

                        Row {
                            required property var modelData
                            visible: modelData.on
                            spacing: Theme.space2

                            KeyChip {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.k
                            }

                            CyberText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.t
                                role: "micro"
                                color: Theme.textMuted
                            }
                        }
                    }
                }

                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: closeRow.implicitWidth
                    height: parent.height

                    Row {
                        id: closeRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.space2

                        KeyChip {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "ESC"
                        }

                        CyberText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Settings.t("Close")
                            role: "label"
                            color: closeMouse.containsMouse ? Theme.text : Theme.textDim

                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        }
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Shell.wallpaperSelectorOpen = false
                    }
                }
            }
        }
    }

    // The two gradient stops, resolved the same way the desktop resolves them:
    // a literal hex wins, otherwise the palette role.
    readonly property color fillA: Settings.wallpaper.colorCustom !== ""
        ? Settings.wallpaper.colorCustom
        : Theme.c(Settings.wallpaper.colorRole)

    readonly property color fillB: Settings.wallpaper.colorCustom2 !== ""
        ? Settings.wallpaper.colorCustom2
        : Theme.c(Settings.wallpaper.colorRole2)

    // --- keyboard
    Item {
        anchors.fill: parent
        focus: true

        // Steps whichever switch holds the ring. The switches are stateless -
        // they write straight to Settings - so this walks the option list for
        // the focused one rather than asking the control to move itself.
        function stepSwitch(delta) {
            switch (root.focusedStop) {
            case "source":
                cycle(root.sourceOptions, Settings.wallpaper.mode, delta,
                      (v) => Settings.wallpaper.mode = v);
                return;
            case "style":
                if (root.colorMode)
                    cycle(root.colorStyleOptions, Settings.wallpaper.colorStyle, delta,
                          (v) => Settings.wallpaper.colorStyle = v);
                else
                    cycle(root.transitionOptions, Settings.wallpaper.transition, delta,
                          (v) => Settings.wallpaper.transition = v);
                return;
            case "colour":
                cycle(root.roleOptions, Settings.wallpaper.colorRole, delta, (v) => {
                    Settings.wallpaper.colorRole = v;
                    Settings.wallpaper.colorCustom = "";
                });
                return;
            case "colour2":
                cycle(root.roleOptions, Settings.wallpaper.colorRole2, delta, (v) => {
                    Settings.wallpaper.colorRole2 = v;
                    Settings.wallpaper.colorCustom2 = "";
                });
                return;
            }
        }

        // Wraps, like CyberSelector's own stepper does, so the end of a list is
        // never a dead arrow.
        function cycle(options, current, delta, write) {
            if (!options || options.length === 0) return;
            let at = -1;
            for (let i = 0; i < options.length; i++)
                if (options[i].v === current) { at = i; break; }
            if (at < 0) at = delta > 0 ? -1 : 0;
            let next = (at + delta) % options.length;
            if (next < 0) next += options.length;
            write(options[next].v);
        }

        function moveInGrid(delta) {
            if (root.files.length === 0) return;
            root.highlight = Math.max(0, Math.min(root.files.length - 1,
                                                  root.highlight + delta));
            grid.positionViewAtIndex(root.highlight, GridView.Contain);
        }

        Keys.onPressed: (event) => {
            event.accepted = true;

            const onGrid = root.focusedStop === "grid";

            switch (event.key) {
            case Qt.Key_Escape:
                Shell.wallpaperSelectorOpen = false;
                return;

            case Qt.Key_Left:
                if (onGrid) moveInGrid(-1); else stepSwitch(-1);
                return;
            case Qt.Key_Right:
                if (onGrid) moveInGrid(1); else stepSwitch(1);
                return;

            case Qt.Key_Up:
                // Leaving the grid from its top row is how you get back to the
                // switches; anywhere else in the grid it is a row up.
                if (onGrid && root.highlight >= grid.columns)
                    moveInGrid(-grid.columns);
                else
                    root.focusBy(-1);
                return;

            case Qt.Key_Down:
                if (onGrid) moveInGrid(grid.columns);
                else root.focusBy(1);
                return;

            case Qt.Key_Tab:
                root.focusBy(1);
                return;
            case Qt.Key_Backtab:
                root.focusBy(-1);
                return;

            case Qt.Key_PageUp:
                if (onGrid) moveInGrid(-grid.columns * 3);
                return;
            case Qt.Key_PageDown:
                if (onGrid) moveInGrid(grid.columns * 3);
                return;

            case Qt.Key_Home:
                if (onGrid) {
                    root.highlight = 0;
                    grid.positionViewAtBeginning();
                }
                return;
            case Qt.Key_End:
                if (onGrid) {
                    root.highlight = Math.max(0, root.files.length - 1);
                    grid.positionViewAtEnd();
                }
                return;

            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                // On a tile, confirm means apply. On a switch the value is
                // already live - these settings take effect as they change -
                // so confirm means "done with this one" and moves on.
                if (onGrid) root.applySelected(root.highlight);
                else root.focusBy(1);
                return;

            case Qt.Key_F5:
                if (!root.colorMode) Wallpapers.scan();
                return;
            }

            if (!root.colorMode && event.text.toLowerCase() === "r") {
                Wallpapers.random();
                Qt.callLater(root.syncToCurrent);
                return;
            }

            event.accepted = false;
        }
    }
}
