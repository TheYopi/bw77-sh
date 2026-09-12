import QtQuick
import qs.Config
import qs.Common

/*
 * Shared chrome for bar widgets: hover state, click handling, and the angled
 * hover fill. Widgets put their contents inside and get consistent behaviour.
 */
Item {
    id: root

    default property alias content: inner.data
    property var config: ({})
    property var screenRef: null

    // Draws the hover frame and reacts to the wheel.
    property bool interactive: true

    /*
     * Whether this widget's own MouseArea takes button presses.
     *
     * A widget whose children handle their own clicks - the tray's icons, the
     * workspace pips - needs the frame and the hover state but must not
     * intercept those clicks. The MouseArea is declared after the content, so
     * it paints above it and would otherwise swallow everything.
     *
     * With this false the area still tracks hover and the wheel, but buttons
     * pass straight through to the children.
     */
    property bool captureClicks: true
    property bool active: false
    property color accentColor: Theme.accent
    property real hPadding: Settings.bar.widgetPadding

    /*
     * Text size and weight for the widget's contents.
     *
     * Both come from the bar as a whole now, not from `config`. Every widget
     * used to carry its own "Text size" slider defaulting to 0; the only
     * sensible way to set them was identically, and the only thing the
     * per-widget version bought was the ability to end up with a bar whose
     * widgets disagreed by a pixel or two for no reason anyone could
     * reconstruct later.
     *
     * Zero still means "use the theme size", which is what an untouched config
     * carries, so nothing moves until the slider is touched. A `fontSize` left
     * in a widget's entry by an older build is simply ignored rather than
     * migrated - it is one dead key in settings.json and rewriting people's
     * config to remove it is the more disruptive of the two options.
     */
    readonly property real cfgFontSize: Settings.bar.fontSize
    readonly property int cfgFontWeight: Settings.bar.fontWeight

    /*
     * Icon size, which is a different thing and stays per-widget.
     *
     * Unifying the TEXT size does not mean unifying the glyphs: a launcher
     * logo and a battery icon are pictures sitting at the ends of the bar, and
     * wanting one of them larger than the running text is a normal thing to
     * want. The key is still "fontSize" inside the widget's entry because that
     * is what existing configs have written in them.
     */
    readonly property real cfgIconSize: (config && config.fontSize) ? config.fontSize : 0

    readonly property string cfgColorRole: (config && config.colorRole) ? config.colorRole : ""
    function cfgColor(fallback) {
        return cfgColorRole !== "" ? Theme.c(cfgColorRole) : fallback;
    }

    /*
     * The frame's colour, separately from the text's.
     *
     * The outline and its fill used to take the widget's own accentColor with
     * no way to change it, while the text beside them could be recoloured - so
     * a clock set to gold sat in a cyan frame. Default still follows the
     * widget, which matters: several widgets change their accent with their
     * state (a muted volume turns crimson, an empty notification bell goes
     * dim), and an unset frame keeps saying so.
     */
    readonly property string cfgFrameRole: (config && config.frameRole) ? config.frameRole : ""
    readonly property color frameColor:
        cfgFrameRole !== "" ? Theme.c(cfgFrameRole) : root.accentColor
    property string tooltip: ""

    signal clicked(var mouse)
    signal wheel(var delta)

    readonly property bool hovered: mouse.containsMouse

    // Collapse to nothing when hidden, so widgets that opt out on a given
    // machine - Battery on a desktop, Tray with no items - leave no hole in the
    // Row. Safe here because this reads children, never the parent.
    implicitWidth: visible ? inner.childrenRect.width + hPadding * 2 : 0
    implicitHeight: Settings.bar.height

    // Border modes:
    //   hover  - appears under the cursor only
    //   always - always drawn, faded, and goes fully opaque on hover
    //   never  - no outline at all
    NotchRect {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4

        // A widget can override the global setting. "inherit" follows it.
        readonly property string mode: {
            const own = (root.config && root.config.borderMode)
                ? String(root.config.borderMode) : "inherit";
            return own === "inherit" ? Settings.bar.widgetBorders : own;
        }
        readonly property bool lit: root.hovered || root.active
        /*
         * The outline follows the border mode, not whether the widget can be
         * clicked.
         *
         * This used to return 0 for anything non-interactive, which is one
         * widget - the active window readout - and meant it alone never drew a
         * frame however the setting was left, including a per-widget
         * borderMode of "always" set on that widget explicitly.
         */
        readonly property real strength: {
            if (mode === "never") return 0;
            if (lit) return 1.0;
            return mode === "always" ? Settings.bar.widgetBorderOpacity : 0;
        }

        visible: strength > 0
        opacity: strength

        Behavior on opacity {
            enabled: Settings.animations.barHover
            NumberAnimation { duration: Theme.durFast }
        }

        fillColor: Theme.alpha(root.frameColor, root.active ? 0.22 : 0.12)
        strokeColor: Theme.alpha(root.frameColor, root.active ? 0.9 : 0.5)
        notch: Theme.notchSmall
        // Bar widgets take both cuts, matching the bar they sit in.
        notchTopLeft: true
        notchTopRight: false
        notchBottomRight: true
        notchBottomLeft: false

        Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
    }

    // Full height, so text inside can align to the line box instead of being
    // centred as a box. Fonts with heavy descenders were sitting low otherwise.
    Item {
        id: inner
        anchors.horizontalCenter: parent.horizontalCenter
        width: childrenRect.width
        height: parent.height
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        /*
         * Left enabled even when the widget is not interactive, so that hover
         * still registers and a "hover" border lights under the cursor. What a
         * non-interactive widget gives up is buttons, not the pointer: with
         * none accepted, a click travels through to the bar behind - which is
         * what opens quick settings on a right-click.
         */
        acceptedButtons: (root.interactive && root.captureClicks)
            ? (Qt.LeftButton | Qt.RightButton | Qt.MiddleButton)
            : Qt.NoButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (m) => { if (root.interactive) root.clicked(m); }
        onWheel: (w) => {
            // Not ours to consume; let it reach whatever is underneath.
            if (!root.interactive) { w.accepted = false; return; }
            root.wheel(w.angleDelta.y);
        }
    }
}
