import QtQuick
import qs.Config
import qs.Common

/*
 * A single palette on the carousel: a small mock of the shell drawn entirely in
 * that palette's own colours, so you choose by appearance rather than by name.
 *
 * Every colour here comes from the card's own palette, never from Theme - the
 * whole point is that a card looks nothing like the one next to it.
 */
Item {
    id: root

    property string name: ""
    property var palette: null
    property bool selected: false
    property bool hovered: false

    function role(key, fallback) {
        if (palette && palette[key]) return palette[key];
        return fallback;
    }

    readonly property color cBg:      role("bgBase", "#0B0D13")
    readonly property color cRaised:  role("bgRaised", "#12151E")
    readonly property color cBorder:  role("border", "#3A2028")
    readonly property color cAccent:  role("accent", "#2DE2E6")
    readonly property color cDanger:  role("danger", "#FF003C")
    readonly property color cWarn:    role("warn", "#FCEE0A")
    readonly property color cText:    role("text", "#E6F7FA")
    readonly property color cDim:     role("textDim", "#8FA9B3")

    NotchRect {
        anchors.fill: parent
        fillColor: root.cBg
        strokeColor: root.selected ? root.cAccent
            : (root.hovered ? root.cDanger : Qt.rgba(root.cBorder.r, root.cBorder.g,
                                                     root.cBorder.b, 0.9))
        strokeWidth: root.selected ? 2 : 1
        notch: 14
        notchTopLeft: false
        notchTopRight: false
        notchBottomRight: true
        notchBottomLeft: false
    }

    // --- mock top bar
    Item {
        id: mockBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        anchors.topMargin: 12
        height: 16

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.cRaised.r, root.cRaised.g, root.cRaised.b, 0.9)
        }

        // Launcher mark.
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            color: "transparent"
            border.color: root.cDanger
            border.width: 1
        }

        // Workspace pips: one focused, two idle.
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Rectangle { width: 12; height: 5; color: root.cAccent }
            Rectangle { width: 5;  height: 5; color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.35) }
            Rectangle { width: 5;  height: 5; color: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 1) }
        }

        // Clock.
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 5
            color: root.cWarn
        }

        // The bar's signature edge rule.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: root.cDanger
        }
    }

    // --- mock panel
    NotchRect {
        id: mockPanel
        anchors.top: mockBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        anchors.topMargin: 10
        height: 58

        fillColor: root.cRaised
        strokeColor: Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 1)
        notch: 8
        notchTopLeft: false
        notchTopRight: false
        notchBottomRight: true
        notchBottomLeft: false

        // Section marker plus title rule.
        Rectangle {
            id: marker
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 6
            width: 3
            height: 10
            color: root.cDanger
        }

        Rectangle {
            anchors.left: marker.right
            anchors.leftMargin: 4
            anchors.verticalCenter: marker.verticalCenter
            width: 34
            height: 4
            color: root.cDanger
        }

        // Two rows of readout text.
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: marker.bottom
            anchors.margins: 6
            anchors.topMargin: 6
            spacing: 4

            Rectangle { width: parent.width * 0.75; height: 3; color: root.cText }
            Rectangle { width: parent.width * 0.5;  height: 3; color: root.cDim }

            // Segmented meter, the shell's signature readout.
            Row {
                spacing: 2
                Repeater {
                    model: 14
                    Rectangle {
                        required property int index
                        width: 4
                        height: 6
                        color: index < 9 ? root.cAccent
                            : Qt.rgba(root.cBorder.r, root.cBorder.g, root.cBorder.b, 1)
                    }
                }
            }
        }
    }

    // --- colour swatches
    Row {
        id: swatches
        anchors.top: mockPanel.bottom
        anchors.left: parent.left
        anchors.margins: 10
        anchors.topMargin: 10
        spacing: 4

        Repeater {
            model: [root.cAccent, root.cDanger, root.cWarn, root.cText]
            Rectangle {
                required property color modelData
                width: 16
                height: 16
                color: modelData
            }
        }
    }

    // --- name
    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        text: root.name
        font.family: Theme.fontDisplay
        font.pixelSize: 15
        font.letterSpacing: Theme.trackingWide
        font.capitalization: Font.AllUppercase
        font.weight: Font.DemiBold
        color: root.selected ? root.cAccent : root.cText
        elide: Text.ElideRight
    }
}
