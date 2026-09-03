import QtQuick
import qs.Config
import qs.Common

/*
 * Drop-down list under an expandable tile.
 *
 * Capped at five visible rows and scrollable past that, so a long list of
 * access points cannot push the rest of the panel off screen.
 */
Item {
    id: root

    default property alias content: column.data

    property int visibleRows: 5
    property int rowHeight: 34
    property color tint: Theme.accent
    property int rowCount: 0
    property string emptyText: "Nothing found"

    readonly property real maxHeight: visibleRows * rowHeight + Theme.space2

    implicitHeight: Math.min(maxHeight, Math.max(rowHeight, column.implicitHeight + Theme.space2))

    NotchRect {
        anchors.fill: parent
        fillColor: Theme.alpha(Theme.bgDeep, 0.7)
        strokeColor: Theme.alpha(root.tint, 0.3)
        notch: Theme.notchSmall
        notchTopLeft: false
        notchTopRight: false
        notchBottomRight: true
        notchBottomLeft: false
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Theme.space1
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: column
            width: flick.width
            spacing: 1
        }
    }

    CyberText {
        anchors.centerIn: parent
        visible: root.rowCount === 0
        text: root.emptyText
        role: "micro"
        caps: false
        color: Theme.textMuted
    }

    // Scroll hint, since a capped list gives no other clue there is more.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 2
        y: flick.contentHeight > 0 ? flick.visibleArea.yPosition * parent.height : 0
        width: 2
        height: Math.max(16, flick.visibleArea.heightRatio * parent.height)
        color: Theme.alpha(root.tint, 0.7)
        visible: flick.contentHeight > flick.height
    }
}
