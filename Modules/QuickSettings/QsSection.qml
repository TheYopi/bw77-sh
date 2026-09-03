import QtQuick
import qs.Config
import qs.Common

/*
 * A quick settings section.
 *
 * Uses the same SectionHeader as the Control Center - marker, tracked title and
 * a rule fading to the right - rather than boxing each section in its own
 * frame. Individually framed sections made the panel read as a stack of
 * unrelated cards while the Control Center reads as one surface divided into
 * parts; this is the latter.
 *
 * `framed` is kept for the rare section that genuinely wants its own outline,
 * but the default is now unframed.
 */
Item {
    id: root

    default property alias content: body.data

    property string title: ""
    property string subtitle: ""
    property string accentRole: "accent"
    property real padding: 0
    property bool framed: false

    readonly property color accentColor: Theme.c(accentRole)

    implicitHeight: (title !== "" ? header.height + Theme.space2 : 0)
                    + body.childrenRect.height
                    + (framed ? padding * 2 : 0)

    NotchRect {
        anchors.fill: parent
        visible: root.framed
        fillColor: Theme.alpha(Theme.bgRaised, 0.75)
        strokeColor: Theme.alpha(root.accentColor, 0.35)
        notch: Theme.notch
        notchTopLeft: false
        notchTopRight: false
        notchBottomRight: true
        notchBottomLeft: false
    }

    SectionHeader {
        id: header
        visible: root.title !== ""
        height: visible ? implicitHeight : 0

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.framed ? root.padding : 0
        anchors.rightMargin: root.framed ? root.padding : 0
        anchors.topMargin: root.framed ? root.padding : 0

        title: root.title
        subtitle: root.subtitle
        accentColor: root.accentColor
        // The panel opens with a decode already running on the clock; a second
        // one on every section title at the same moment is noise.
        glitch: false
    }

    Item {
        id: body
        anchors.top: root.title !== "" ? header.bottom : parent.top
        anchors.topMargin: root.title !== "" ? Theme.space2 : (root.framed ? root.padding : 0)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.framed ? root.padding : 0
        anchors.rightMargin: root.framed ? root.padding : 0
        height: childrenRect.height
    }
}
