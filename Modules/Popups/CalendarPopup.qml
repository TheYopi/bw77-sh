import QtQuick
import Quickshell
import qs.Config
import qs.Common

/*
 * Month view. Purely visual - no events, no app. Scroll or use the arrows to
 * move between months; clicking the title jumps back to today.
 */
Item {
    id: root

    implicitWidth: 300
    implicitHeight: col.implicitHeight

    readonly property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()      // 0-11

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"]

    function shift(delta) {
        let m = viewMonth + delta;
        let y = viewYear;
        while (m < 0)  { m += 12; y -= 1; }
        while (m > 11) { m -= 12; y += 1; }
        viewMonth = m;
        viewYear = y;
    }

    function reset() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }

    // Monday-first grid. getDay() is Sunday-first, so rotate it.
    readonly property int firstWeekday: {
        const d = new Date(viewYear, viewMonth, 1).getDay();
        return (d + 6) % 7;
    }
    readonly property int daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()

    readonly property var cells: {
        const out = [];
        for (let i = 0; i < firstWeekday; i++) out.push(0);
        for (let d = 1; d <= daysInMonth; d++) out.push(d);
        while (out.length % 7 !== 0) out.push(0);
        return out;
    }

    MouseArea {
        anchors.fill: parent
        onWheel: (w) => root.shift(w.angleDelta.y > 0 ? -1 : 1)
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.space2

        Row {
            width: parent.width
            height: 28

            CyberText {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u25C1"
                role: "icon"
                color: prevMouse.containsMouse ? Theme.accent : Theme.textDim
                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shift(-1)
                }
            }

            Item {
                width: parent.width - 40
                height: parent.height

                CyberText {
                    anchors.centerIn: parent
                    text: `${root.monthNames[root.viewMonth]} ${root.viewYear}`
                    role: "title"
                    color: Theme.danger
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.reset()
                }
            }

            CyberText {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u25B7"
                role: "icon"
                color: nextMouse.containsMouse ? Theme.accent : Theme.textDim
                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shift(1)
                }
            }
        }

        Grid {
            width: parent.width
            columns: 7
            spacing: 2

            Repeater {
                model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                Item {
                    required property string modelData
                    required property int index
                    width: (col.width - 12) / 7
                    height: 18
                    CyberText {
                        anchors.centerIn: parent
                        text: modelData
                        role: "micro"
                        color: index >= 5 ? Theme.alpha(Theme.danger, 0.8) : Theme.textMuted
                    }
                }
            }

            Repeater {
                model: root.cells

                Item {
                    required property int modelData
                    required property int index

                    readonly property bool isToday:
                        modelData === root.today.getDate()
                        && root.viewMonth === root.today.getMonth()
                        && root.viewYear === root.today.getFullYear()
                    readonly property bool weekend: (index % 7) >= 5

                    width: (col.width - 12) / 7
                    height: 26

                    // Padding cells stay VISIBLE and simply draw nothing.
                    // Grid skips invisible children, so hiding them collapsed
                    // the leading offset and shifted every date in the month
                    // left by a different amount each month - which is why the
                    // red weekend columns looked random.
                    opacity: modelData > 0 ? 1 : 0

                    NotchRect {
                        anchors.fill: parent
                        visible: parent.isToday
                        fillColor: Theme.alpha(Theme.accent, 0.9)
                        strokeColor: Theme.accent
                        notch: 4
                        notchTopLeft: false
                        notchTopRight: false
                        notchBottomRight: true
                        notchBottomLeft: false
                    }

                    CyberText {
                        anchors.centerIn: parent
                        text: parent.modelData > 0 ? String(parent.modelData) : ""
                        role: "mono"
                        font.pixelSize: Theme.fontSmall
                        color: parent.isToday ? Theme.textOnAccent
                            : (parent.weekend ? Theme.alpha(Theme.danger, 0.85) : Theme.text)
                    }
                }
            }
        }
    }
}
