import QtQuick
import qs.Config
import qs.Common

/*
 * A quick settings tile.
 *
 * Two shapes in one: a plain toggle, or an expandable entry with a chevron that
 * opens a submenu underneath. Network and bluetooth use the latter; everything
 * else is a plain toggle.
 */
Item {
    id: root

    property string glyph: ""
    property string label: ""
    property string detail: ""
    property bool on: false
    property bool danger: false
    property bool expandable: false
    property bool expanded: false
    property color tint: Theme.accent

    signal activated()
    signal expandToggled()

    readonly property color activeTint: danger ? Theme.danger : tint

    /*
     * --- a tile whose state is a value, not a switch
     *
     * `on` normally does three things at once: it fills the tile, thickens its
     * outline and lights the glyph. That is right for a switch, where there is
     * one thing to say and lit says it.
     *
     * A tile that carries one of several values has more to say than lit or
     * not, and saying it by filling the frame ends up shouting: the power
     * profile tile is the full width of the panel, so a lit frame put a slab of
     * colour across it for what is a one-word difference - while Balanced, the
     * state most machines sit in, could only be drawn as the same nothing the
     * tile shows when the daemon is missing.
     *
     * So the two are separable. `frameEmphasis` keeps the frame neutral - hover
     * still answers, the tile is still a target - and `glyphColor` carries the
     * state on its own, at whatever colour the value means. Both default to
     * exactly what every other tile already does.
     */
    property bool frameEmphasis: true
    property color glyphColor: root.on ? root.activeTint : Theme.textDim

    readonly property bool lit: root.on && root.frameEmphasis

    /*
     * --- height
     *
     * Derived from the text rather than fixed at 48.
     *
     * 48 was set when the label was the only line and there was room to spare.
     * On a 1080p screen the panel has to fit a header, two sliders, three
     * expandable tiles, four rows of plain ones, the media block and the
     * calendar - and a fixed 48 spent that budget on padding inside tiles that
     * only needed room for one line of nine-pixel text. Deriving it means the
     * tile is as tall as what is in it, and the space comes back to the rest of
     * the panel.
     *
     * The floor keeps a single-line tile a comfortable pointer target rather
     * than letting it collapse onto its own text.
     */
    implicitHeight: Math.max(38, text.implicitHeight + Theme.space2 * 2)

    NotchRect {
        anchors.fill: parent
        fillColor: root.lit
            ? Theme.alpha(root.activeTint, 0.28)
            : (mouse.containsMouse ? Theme.alpha(root.activeTint, 0.12)
                                   : Theme.alpha(Theme.bgRaised, 0.6))
        strokeColor: root.lit ? root.activeTint : Theme.alpha(root.activeTint, 0.4)
        strokeWidth: root.lit ? Theme.borderWidthStrong : Theme.borderWidth
        notch: Theme.notchSmall
        notchTopLeft: false
        notchTopRight: false
        notchBottomRight: true
        notchBottomLeft: false

        /*
         * The fill was already easing while the outline and the label snapped,
         * so toggling a tile half-moved and half-cut. All three now change
         * together, which is what makes the tile feel like one object.
         *
         * On an ease-out rather than the linear ramp a ColorAnimation runs by
         * default. Linear is what makes a hover feel mechanical: the colour
         * arrives at exactly the rate it left, so there is no moment where it
         * settles. Easing out front-loads the change, which under a pointer
         * reads as the tile answering rather than fading.
         */
        Behavior on fillColor {
            ColorAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad }
        }
        Behavior on strokeColor {
            ColorAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad }
        }
    }

    /*
     * --- the glyph sits in a slot, not wherever it happens to end
     *
     * A tile's glyph changes with its state: Wi-Fi on is not the same character
     * as Wi-Fi off, and a Nerd Font does not draw the two at the same width. The
     * icon used to size itself to whatever it was currently drawing and the
     * label column began at its right edge, so toggling a tile moved the icon
     * and shunted the entire text block a few pixels sideways with it. Reading
     * down a column of tiles and clicking through them made the panel twitch.
     *
     * A fixed slot the width of the widest glyph, with the character centred in
     * it, pins the label to one x for every state of every tile. The width is
     * the icon size with a little air - a Nerd Font glyph is drawn on roughly a
     * square body, and the ones that overrun it are the double-width ones this
     * panel does not use.
     */
    readonly property int iconSlot: Math.round(Theme.fontLarge * 1.6)

    CyberText {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Theme.space3
        height: parent.height
        width: root.iconSlot
        horizontalAlignment: Text.AlignHCenter
        text: root.glyph
        role: "icon"
        font.pixelSize: Theme.fontLarge
        color: root.glyphColor

        Behavior on color {
            ColorAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad }
        }
    }

    Column {
        id: text
        anchors.left: icon.right
        anchors.leftMargin: Theme.space2
        anchors.right: chevron.visible ? chevron.left : parent.right
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        spacing: -1

        CyberText {
            width: parent.width
            text: root.label
            // "label" - which is fontSmall - rather than "micro". These are
            // the panel's primary controls and they were set at the same size
            // as the secondary line underneath them, which is why a tile read
            // as two equally quiet lines instead of a label with a value
            // beneath it. The detail line stays micro, so the pair now has an
            // actual hierarchy.
            role: "label"
            color: root.on ? Theme.text : Theme.textDim
            elide: Text.ElideRight

            Behavior on color {
                ColorAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad }
            }
        }

        CyberText {
            width: parent.width
            visible: root.detail !== ""
            text: root.detail
            role: "micro"
            caps: false
            color: Theme.textMuted
            elide: Text.ElideRight
        }
    }

    // Chevron is its own hit target: tapping the tile acts, tapping the arrow
    // opens the submenu, so the primary action never costs an extra click.
    Item {
        id: chevron
        visible: root.expandable
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 26

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            width: 1
            color: Theme.alpha(root.activeTint, 0.35)
        }

        /*
         * One glyph turned, rather than two swapped.
         *
         * It used to switch between a right-pointing and a down-pointing
         * triangle, which is legible but says nothing while it happens - the
         * arrow was simply a different arrow on the next frame. Turning a single
         * glyph through the same quarter is the same two states with the
         * movement between them left in, and that movement is the thing that
         * tells you the list below is unrolling rather than appearing.
         *
         * The rotation runs on the panel's own category, so it and the submenu
         * it describes turn and unroll over exactly the same span.
         */
        CyberText {
            anchors.centerIn: parent
            text: "\u25B8"
            role: "icon"
            rotation: root.expanded ? 90 : 0
            color: chevronMouse.containsMouse ? root.activeTint : Theme.textDim

            Behavior on color {
                ColorAnimation { duration: Theme.durFast; easing.type: Easing.OutQuad }
            }

            // Ease-in-out on the way back, so the arrow and the list it
            // describes close on the same curve as well as over the same span.
            // See QsSubmenu for why a collapse does not take an ease-out.
            Behavior on rotation {
                enabled: !Theme.reducedMotion && Settings.animations.surfaceOpen
                NumberAnimation {
                    duration: Theme.durationFor("quickSettings")
                    easing.type: root.expanded
                        ? Theme.curveFor("quickSettings") : Easing.InOutCubic
                }
            }
        }

        MouseArea {
            id: chevronMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandToggled()
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.rightMargin: chevron.visible ? chevron.width : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
