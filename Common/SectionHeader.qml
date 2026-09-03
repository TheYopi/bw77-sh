import QtQuick
import qs.Config

/*
 * The angled title slab used above every screen in the game: a filled chevron
 * on the left, the title in tracked caps, and a rule running to the right edge.
 */
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property color accentColor: Theme.danger
    property bool glitch: true

    /*
     * The trailing rule.
     *
     * Off by default. It is centred across the header, which puts it exactly on
     * the boundary between the title and the subtitle - so with a subtitle
     * present it reads as a line struck through the text below rather than as
     * an underline for the text above.
     */
    property bool rule: false

    implicitHeight: Math.max(28, label.implicitHeight + Theme.space2)

    // Solid marker block, mirrors the game's left-edge tab.
    NotchRect {
        id: marker
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 5
        height: parent.height * 0.7
        fillColor: root.accentColor
        strokeColor: "transparent"
        strokeWidth: 0
        notch: 2
        notchTopLeft: false
        notchBottomRight: false
        notchTopRight: true
        notchBottomLeft: true
    }

    Column {
        id: label
        anchors.left: marker.right
        anchors.leftMargin: Theme.space3
        anchors.verticalCenter: parent.verticalCenter
        // Hard cap rather than min(implicitWidth, ...): taking the implicit
        // width when it was the smaller of the two is what allowed a long title
        // to size the column and then overflow it.
        width: Math.max(0, root.width - marker.width - Theme.space3 * 2)
        spacing: 1

        /*
         * Width pinned to the column, not left to the text.
         *
         * GlitchText sizes itself from its content, and the Column above caps
         * itself at `implicitWidth` - so a title longer than the surface simply
         * made the whole header wider than its parent and ran off the edge with
         * no elide to stop it. It showed up first in the dock's right-click
         * menu, where the heading is an application name and some of those are
         * very long, but every surface with a long title had it.
         */
        GlitchText {
            id: titleText
            width: parent.width
            textWidth: parent.width
            text: root.title
            role: "title"
            color: root.accentColor
            decodeOnChange: root.glitch
            elide: Text.ElideRight
        }

        CyberText {
            visible: root.subtitle !== ""
            width: parent.width
            text: root.subtitle
            role: "micro"
            color: Theme.textMuted
            elide: Text.ElideRight
        }
    }

    Rectangle {
        visible: root.rule
        anchors.left: label.right
        anchors.right: parent.right
        anchors.leftMargin: Theme.space3
        // Aligned to the title's centre line, not the header's, so a subtitle
        // cannot end up sitting on it.
        anchors.verticalCenter: titleText.verticalCenter
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.alpha(root.accentColor, 0.8) }
            GradientStop { position: 1.0; color: Theme.alpha(root.accentColor, 0.0) }
        }
    }
}
