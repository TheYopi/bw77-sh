import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.Config
import qs.Common
import qs.Services

/*
 * One dock entry: icon, running indicator, tooltip, magnification, and the
 * right-click menu.
 *
 * Which menu is open is owned by the dock, not by the item. An item that
 * toggles its own menu can only be closed by clicking the same item again,
 * which is exactly the behaviour we are getting rid of.
 */
Item {
    id: root

    property string appId: ""
    property bool pinned: false

    // Built-in actions are not applications: no window list, no pin menu.
    property string action: ""      // "" | "launcher"
    readonly property bool isAction: action !== ""
    property int itemIndex: -1
    property int hoveredIndex: -1
    // Set by the dock from the shared menu state.
    property bool menuOpenFor: false
    property bool vertical: false
    property int baseSize: 40

    signal hoverChanged(int index, bool hovered)
    signal menuRequested(int index)
    signal menuDismissed()

    readonly property bool running: isAction ? false : Apps.isRunning(appId)

    // True when one of this application's windows currently has focus.
    readonly property bool focused: {
        const active = Compositor.activeToplevel;
        if (!active) return false;
        for (let i = 0; i < windows.length; i++) {
            if (windows[i] === active) return true;
        }
        return false;
    }

    readonly property color indicatorColor: focused
        ? (Settings.dock.focusedColorCustom !== ""
            ? Settings.dock.focusedColorCustom
            : Theme.c(Settings.dock.focusedColorRole))
        : Theme.alpha(Theme.accent, 0.75)
    readonly property var windows: isAction ? [] : Apps.toplevelsFor(appId)
    readonly property int windowCount: windows.length
    readonly property bool active: hoveredIndex === itemIndex
    readonly property bool menuOpen: menuOpenFor

    // Falls off linearly across magnifyRange neighbours.
    readonly property real magnification: {
        if (!Settings.dock.magnify || hoveredIndex < 0) return 1.0;
        const distance = Math.abs(itemIndex - hoveredIndex);
        const range = Settings.dock.magnifyRange;
        if (distance > range) return 1.0;
        const falloff = 1.0 - (distance / (range + 1));
        return 1.0 + (Settings.dock.magnifyScale - 1.0) * falloff;
    }

    readonly property int size: Math.round(baseSize * magnification)

    // Space reserved outside the hover plate for the running indicator, so the
    // two never overlap. Supplied by the dock so both agree on the panel size.
    property int indicatorLane: 8

    // How much room the dock window has spare for a tooltip, so a long
    // application name elides instead of running past the edge of the surface.
    property int tooltipSpace: 200

    width: vertical ? baseSize + indicatorLane : size
    height: vertical ? size : baseSize + indicatorLane

    Behavior on width { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOut } }
    Behavior on height { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOut } }

    // Colour every icon can be forced to, so a dock of mismatched brand colours
    // reads as one piece of hardware.
    readonly property color tintColor: Settings.dock.iconColorCustom !== ""
        ? Settings.dock.iconColorCustom
        : Theme.c(Settings.dock.iconColorRole)

    readonly property bool tinted: Settings.dock.colorizeIcons && !isAction
        // The focused app can opt out, which leaves one icon in its own colours
        // as a second focus cue.
        && !(Settings.dock.colorizeFocusedApp && focused)

    IconImage {
        id: icon
        width: root.size
        height: root.size
        anchors.centerIn: parent

        /*
         * Nudged INWARD, away from the screen edge, so the indicator lane on
         * the edge side stays clear.
         *
         * The vertical pair used to have the sign of the horizontal pair, which
         * pushed the icon toward the edge instead of away from it - so on a
         * left or right dock the indicator was anchored to a side that had no
         * room left and drew outside the panel.
         */
        anchors.verticalCenterOffset: root.vertical ? 0
            : (Settings.dock.position === "bottom" ? -root.indicatorLane / 2
                                                   : root.indicatorLane / 2)
        anchors.horizontalCenterOffset: !root.vertical ? 0
            : (Settings.dock.position === "left" ? root.indicatorLane / 2
                                                 : -root.indicatorLane / 2)

        source: root.isAction ? "" : Apps.iconFor(root.appId)
        // Hidden but still rendered when tinted: MultiEffect needs it as a
        // source, and showing both would double the icon.
        visible: !root.isAction && !root.tinted
        smooth: true

        Behavior on width { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOut } }
        Behavior on height { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeOut } }
    }

    MultiEffect {
        anchors.fill: icon
        source: icon
        visible: root.tinted
        colorization: Settings.dock.colorizeStrength
        colorizationColor: root.tintColor
        brightness: 0
    }

    // Launcher mark: the same chamfered block with a slash used in the bar, so
    // the two read as the same control.
    Item {
        visible: root.action === "launcher"
        anchors.centerIn: icon
        width: root.size * 0.62
        height: root.size * 0.62

        NotchRect {
            anchors.fill: parent
            fillColor: root.active ? Theme.danger : "transparent"
            strokeColor: Theme.danger
            strokeWidth: 2
            notch: Math.max(3, parent.width * 0.28)
            notchTopLeft: false
            notchTopRight: false
            notchBottomRight: true
            notchBottomLeft: false

            Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 2
            height: parent.height * 0.72
            rotation: 35
            color: root.active ? Theme.bgDeep : Theme.danger
        }
    }

    // Hover plate. Same three modes as the bar widgets.
    NotchRect {
        id: plate
        anchors.fill: icon
        anchors.margins: -3
        z: -1

        readonly property string borderMode: Settings.dock.itemBorders
        readonly property real strength: {
            if (borderMode === "never") return 0;
            if (root.active || root.menuOpen) return 1.0;
            return borderMode === "always" ? Settings.dock.itemBorderOpacity : 0;
        }

        visible: strength > 0
        opacity: strength

        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

        fillColor: Theme.alpha(Theme.accent, 0.16)
        strokeColor: Theme.alpha(Theme.accent, 0.7)
        notch: 5
        notchTopLeft: false
        notchTopRight: false
        notchBottomRight: true
        notchBottomLeft: false
    }

    /*
     * Running indicator, in its own lane outside the plate rather than on top
     * of the border.
     *
     * The pips run ALONG the dock, so the lane only ever has to be one pip
     * thick whichever way the dock is turned. As a Row they always ran left to
     * right: on a vertical dock that is three pips plus spacing across an 8px
     * lane, which is why they spilled out of the side of the panel.
     */
    Grid {
        id: pips

        readonly property int count: Math.min(3, Math.max(1, root.windowCount))
        // Across the lane, and along the dock. Focus lengthens the pip rather
        // than fattening it, so the lane width never has to change.
        readonly property int thickness: 3

        // Gap between dashes. Also the Grid's spacing, so the arithmetic below
        // and the layout cannot disagree.
        readonly property int dashGap: 2

        /*
         * Dash length is derived from the plate, not fixed.
         *
         * A fixed length meant the group grew with the window count: three
         * windows at 10px plus two gaps came to 36px beneath a 32px icon, so
         * the indicator was wider than the thing it belonged to. Dividing the
         * plate between however many dashes there are keeps the group one
         * constant width whether an app has one window or three - which is what
         * makes a row of dock items scannable, because every indicator then
         * starts and ends on the same two x positions.
         *
         * Floored at 4px: below that a dash is a dot and the count stops being
         * readable anyway.
         */
        readonly property int span: Math.max(8, Math.round(
            (root.vertical ? plate.height : plate.width) * 0.7))

        readonly property int length: Math.max(4, Math.floor(
            (span - dashGap * (count - 1)) / Math.max(1, count)))

        visible: Settings.dock.showIndicators && root.running

        columns: root.vertical ? 1 : pips.count
        rows: root.vertical ? pips.count : 1
        spacing: pips.dashGap

        /*
         * Positioned with x/y for the same reason the dock body is.
         *
         * Turning the dock swaps `top` for `verticalCenter` and `left` for
         * `horizontalCenter`, and those bindings re-evaluate one at a time.
         * For a frame both are set, QML rejects the conflicting pair, and the
         * pips keep whatever offset they had - which is why a position change
         * left them slightly out of place until the shell was restarted.
         */
        readonly property int gap: 3

        // Sits between the icon and the screen edge: below the icon on a bottom
        // dock, above it on a top dock. Putting it on the inner side made it
        // read as floating above the app rather than belonging to it.
        x: root.vertical
            ? (Settings.dock.position === "left"
                ? plate.x - pips.gap - pips.width
                : plate.x + plate.width + pips.gap)
            : Math.round((root.width - pips.width) / 2)

        y: root.vertical
            ? Math.round((root.height - pips.height) / 2)
            : (Settings.dock.position === "top"
                ? plate.y - pips.gap - pips.height
                : plate.y + plate.height + pips.gap)

        Repeater {
            model: pips.count
            Rectangle {
                width: root.vertical ? pips.thickness : pips.length
                height: root.vertical ? pips.length : pips.thickness
                color: root.indicatorColor

                Behavior on width { NumberAnimation { duration: Theme.durFast } }
                Behavior on height { NumberAnimation { duration: Theme.durFast } }
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onEntered: root.hoverChanged(root.itemIndex, true)
        onExited: root.hoverChanged(root.itemIndex, false)

        onClicked: (m) => {
            if (root.isAction) {
                root.menuDismissed();
                if (root.action === "launcher") Shell.toggleLauncher();
                return;
            }

            if (m.button === Qt.LeftButton) {
                root.menuDismissed();
                Apps.activate(root.appId, Settings.dock.clickAction);
            } else if (m.button === Qt.MiddleButton) {
                root.menuDismissed();
                Apps.launch(root.appId);       // always a new instance
            } else {
                root.menuRequested(root.itemIndex);
            }
        }
    }

    // --- tooltip
    Loader {
        id: tip

        /*
         * Kept loaded through the fade so there is something to fade out;
         * `active` alone destroyed it on the frame the cursor left and the
         * label simply vanished.
         */
        readonly property bool wanted: Settings.dock.showLabels && root.active && !root.menuOpen
        active: wanted || tip.opacity > 0.01
        z: 100

        opacity: tip.wanted ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            enabled: Settings.animations.surfaceOpen && !Theme.reducedMotion
            NumberAnimation {
                duration: Theme.durationFor("dock")
                easing.type: Theme.curveFor("dock")
            }
        }

        // Slides the short way out of the icon it belongs to.
        transform: Translate {
            x: tip.wanted ? 0 : (root.vertical
                ? (Settings.dock.position === "left" ? -6 : 6) : 0)
            y: tip.wanted ? 0 : (root.vertical ? 0
                : (Settings.dock.position === "top" ? -6 : 6))

            Behavior on x {
                enabled: Settings.animations.surfaceOpen && !Theme.reducedMotion
                NumberAnimation { duration: Theme.durationFor("dock"); easing.type: Theme.curveFor("dock") }
            }
            Behavior on y {
                enabled: Settings.animations.surfaceOpen && !Theme.reducedMotion
                NumberAnimation { duration: Theme.durationFor("dock"); easing.type: Theme.curveFor("dock") }
            }
        }

        // Same anchor-swap hazard as the indicator, same fix.
        readonly property int gap: Theme.space2

        x: root.vertical
            ? (Settings.dock.position === "left"
                ? root.width + tip.gap
                : -tip.width - tip.gap)
            : Math.round((root.width - tip.width) / 2)

        y: root.vertical
            ? Math.round((root.height - tip.height) / 2)
            : (Settings.dock.position === "top"
                ? root.height + tip.gap
                : -tip.height - tip.gap)

        sourceComponent: Item {
            implicitWidth: Math.min(root.tooltipSpace,
                                    tipText.implicitWidth + Theme.space3 * 2)
            implicitHeight: 24

            NotchRect {
                anchors.fill: parent
                fillColor: Theme.alpha(Theme.bgDeep, 0.96)
                strokeColor: Theme.accent
                notch: 5
                notchTopLeft: false
                notchTopRight: false
                notchBottomRight: true
                notchBottomLeft: false
            }

            CyberText {
                id: tipText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, root.tooltipSpace - Theme.space3 * 2)
                elide: Text.ElideRight
                text: root.action === "launcher"
                    ? "Applications" : Apps.nameFor(root.appId)
                role: "micro"
                color: Theme.text
            }
        }
    }

    // The context menu itself is drawn by DockMenuSurface, which is not
    // confined to the dock's window and so cannot clip a long window list.
}
