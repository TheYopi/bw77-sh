import QtQuick
import Quickshell
import qs.Config
import qs.Common
import qs.Services

/* Clock, date, and the shortcut buttons. */
QsSection {
    id: root
    accentRole: "danger"

    Item {
        width: parent.width
        height: 76

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            GlitchText {
                text: Qt.formatDateTime(clock.date,
                    Settings.quickSettings.showSeconds ? "HH:mm:ss" : "HH:mm")
                role: "headline"
                fontSize: Theme.fontHuge
                color: root.accentColor
            }

            CyberText {
                text: Qt.formatDateTime(clock.date, "dddd dd MMMM")
                role: "micro"
                color: Theme.textDim
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space2

            // Only the buttons enabled in settings are built.
            Repeater {
                model: [
                    { glyph: "\uf013", tip: "Control Center", id: "controlCenter",
                      act: () => { Shell.quickSettingsOpen = false;
                                   Shell.toggleControlCenter("home"); } },
                    { glyph: "\udb83\ude09", tip: "Wallpapers", id: "wallpaper",
                      act: () => { Shell.quickSettingsOpen = false;
                                   Shell.toggleWallpaperSelector(); } },
                    { glyph: "\uec21", tip: "Palette", id: "theme",
                      act: () => { Shell.quickSettingsOpen = false;
                                   Shell.toggleThemeMenu(); } },
                    { glyph: "\uf011", tip: "Session", id: "session", danger: true,
                      act: () => { Shell.quickSettingsOpen = false;
                                   Shell.toggleSession(); } }
                ].filter(b => Settings.quickSettings.headerButtons
                                .some(h => h.id === b.id && h.enabled !== false))

                Item {
                    required property var modelData
                    width: 40
                    height: 40

                    NotchRect {
                        anchors.fill: parent
                        fillColor: btnMouse.containsMouse
                            ? Theme.alpha(modelData.danger ? Theme.danger : Theme.accent, 0.25)
                            : Theme.alpha(Theme.bgRaised, 0.9)
                        strokeColor: modelData.danger ? Theme.danger : Theme.accent
                        notch: Theme.notchSmall
                        notchTopLeft: false
                        notchTopRight: false
                        notchBottomRight: true
                        notchBottomLeft: false

                        Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }
                    }

                    CyberText {
                        anchors.centerIn: parent
                        text: modelData.glyph
                        role: "icon"
                        font.pixelSize: Theme.fontLarge
                        color: modelData.danger ? Theme.danger : Theme.accent
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.act()
                    }
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: Settings.quickSettings.showSeconds
            ? SystemClock.Seconds : SystemClock.Minutes
    }
}
