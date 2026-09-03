import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Config
import qs.Common
import qs.Services

/*
 * Themed replacement for the platform tray menu.
 *
 * The menu content still comes from the application over StatusNotifierItem;
 * QsMenuOpener walks that model and this renders it. Restyling the Qt or GTK
 * menu was never going to work - the app owns that widget, not the shell.
 *
 * Submenus expand in place rather than flying out, which avoids a second
 * positioned surface and reads better in a narrow panel.
 */
Item {
    id: root

    implicitWidth: 260
    implicitHeight: Math.max(40, column.implicitHeight)

    property var expanded: ({})

    function toggleExpanded(key) {
        const next = Object.assign({}, expanded);
        next[key] = !next[key];
        expanded = next;
    }

    QsMenuOpener {
        id: opener
        menu: Popups.menuHandle
    }

    Column {
        id: column
        width: parent.width
        spacing: 1

        CyberText {
            visible: opener.children.values.length === 0
            width: parent.width
            text: Settings.t("No menu")
            role: "micro"
            caps: false
            color: Theme.textMuted
        }

        Repeater {
            model: opener.children

            Column {
                id: entryCol
                required property QsMenuEntry modelData
                required property int index

                readonly property string key: "e" + index
                readonly property bool open: root.expanded[key] === true

                width: column.width
                spacing: 1

                // --- separator
                Rectangle {
                    visible: entryCol.modelData.isSeparator
                    width: parent.width
                    height: 1
                    color: Theme.alpha(Theme.border, 0.9)
                }

                // --- entry
                Item {
                    visible: !entryCol.modelData.isSeparator
                    width: parent.width
                    height: entryCol.modelData.isSeparator ? 0 : 28

                    NotchRect {
                        anchors.fill: parent
                        visible: entryMouse.containsMouse && entryCol.modelData.enabled
                        fillColor: Theme.alpha(Theme.accent, 0.18)
                        strokeColor: Theme.alpha(Theme.accent, 0.7)
                        notch: 5
                        notchTopLeft: false
                        notchTopRight: false
                        notchBottomRight: true
                        notchBottomLeft: false
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.space2
                        anchors.rightMargin: Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.space2

                        // Checkbox and radio states, drawn in the shell's language.
                        Item {
                            width: 14
                            height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            visible: entryCol.modelData.buttonType !== QsMenuButtonType.None

                            NotchRect {
                                anchors.fill: parent
                                fillColor: entryCol.modelData.checkState === Qt.Checked
                                    ? Theme.accent : "transparent"
                                strokeColor: Theme.alpha(Theme.accent, 0.8)
                                notch: 3
                                notchTopLeft: false
                                notchTopRight: false
                                notchBottomRight: true
                                notchBottomLeft: false
                            }
                        }

                        IconImage {
                            visible: entryCol.modelData.icon !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 16
                            source: entryCol.modelData.icon
                        }

                        CyberText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            text: entryCol.modelData.text
                            role: "body"
                            caps: false
                            color: entryCol.modelData.enabled
                                ? (entryMouse.containsMouse ? Theme.accent : Theme.text)
                                : Theme.textMuted
                        }
                    }

                    CyberText {
                        visible: entryCol.modelData.hasChildren
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space2
                        anchors.verticalCenter: parent.verticalCenter
                        text: entryCol.open ? "\u25BE" : "\u25B8"
                        role: "micro"
                        color: Theme.accent
                    }

                    MouseArea {
                        id: entryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: entryCol.modelData.enabled
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (entryCol.modelData.hasChildren) {
                                root.toggleExpanded(entryCol.key);
                            } else {
                                entryCol.modelData.triggered();
                                Popups.close();
                            }
                        }
                    }
                }

                // --- submenu, expanded in place
                Loader {
                    active: entryCol.modelData.hasChildren && entryCol.open
                    width: column.width

                    sourceComponent: Column {
                        spacing: 1

                        QsMenuOpener {
                            id: subOpener
                            menu: entryCol.modelData
                        }

                        Repeater {
                            model: subOpener.children

                            Item {
                                required property QsMenuEntry modelData
                                visible: !modelData.isSeparator
                                width: column.width
                                height: modelData.isSeparator ? 0 : 26

                                NotchRect {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.space4
                                    visible: subMouse.containsMouse && modelData.enabled
                                    fillColor: Theme.alpha(Theme.accent, 0.16)
                                    strokeColor: Theme.alpha(Theme.accent, 0.6)
                                    notch: 4
                                    notchTopLeft: false
                                    notchTopRight: false
                                    notchBottomRight: true
                                    notchBottomLeft: false
                                }

                                CyberText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.space4 + Theme.space2
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.text
                                    role: "body"
                                    caps: false
                                    color: modelData.enabled
                                        ? (subMouse.containsMouse ? Theme.accent : Theme.textDim)
                                        : Theme.textMuted
                                }

                                MouseArea {
                                    id: subMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: modelData.enabled
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        modelData.triggered();
                                        Popups.close();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
