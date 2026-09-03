import QtQuick
import qs.Config
import qs.Common
import qs.Services

PaneScroll {
    id: pane

    // Device enumeration only runs while this pane is on screen.
    Component.onCompleted: Audio.devicesActive = true
    Component.onDestruction: Audio.devicesActive = false

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Audio")
        subtitle: Audio.sinkName
        expanded: true


        SettingRow {
            label: Settings.t("Output volume")
            CyberSlider {
                width: 280
                from: 0; to: 1; stepSize: 0.01
                value: Audio.volume
                decimals: 0
                displayScale: 100
                onMoved: (v) => Audio.setVolume(v)
            }
        }

        SettingRow {
            label: Settings.t("Mute output")
            alternate: true
            CyberToggle {
                checked: Audio.muted
                onToggled: () => Audio.toggleMute()
            }
        }

        SettingRow {
            label: Settings.t("Input volume")
            CyberSlider {
                width: 280
                from: 0; to: 1; stepSize: 0.01
                value: Audio.micVolume
                decimals: 0
                displayScale: 100
                barColor: Theme.warn
                onMoved: (v) => Audio.setMicVolume(v)
            }
        }

        SettingRow {
            label: Settings.t("Mute microphone")
            alternate: true
            CyberToggle {
                checked: Audio.micMuted
                onToggled: (v) => Audio.setMicMuted(v)
            }
        }

        // --- output devices
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Output device")
        subtitle: Settings.t("Sets the PipeWire default; applications follow it")
        accentColor: Theme.accent
        glitch: false
        expanded: false


        CyberText {
            visible: Audio.sinks.length === 0
            width: pane.innerWidth
            text: "Looking for output devices\u2026"
            role: "micro"
            caps: false
            color: Theme.textMuted
        }

        Repeater {
            model: Audio.sinks

            SettingRow {
                required property var modelData
                required property int index

                readonly property bool current: Audio.sink === modelData

                label: Audio.deviceLabel(modelData)
                description: current ? "Current default" : ""
                alternate: index % 2 === 1

                CyberButton {
                    text: parent.current ? Settings.t("In use") : Settings.t("Use")
                    active: parent.current
                    onClicked: Audio.setDefaultSink(modelData)
                }
            }
        }

        // --- input devices
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Input device")
        accentColor: Theme.accent
        glitch: false
        expanded: false


        CyberText {
            visible: Audio.sources.length === 0
            width: pane.innerWidth
            text: "Looking for input devices\u2026"
            role: "micro"
            caps: false
            color: Theme.textMuted
        }

        Repeater {
            model: Audio.sources

            SettingRow {
                required property var modelData
                required property int index

                readonly property bool current: Audio.source === modelData

                label: Audio.deviceLabel(modelData)
                description: current ? "Current default" : ""
                alternate: index % 2 === 1

                CyberButton {
                    text: parent.current ? Settings.t("In use") : Settings.t("Use")
                    active: parent.current
                    onClicked: Audio.setDefaultSource(modelData)
                }
            }
        }

    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Hidden sources")
        subtitle: Settings.t("Substring match on an application or node name")
        accentColor: Theme.accent
        glitch: false
        expanded: false


        Repeater {
            /*
             * Modelled on the count. See the long note in DesktopPane: these
             * lists hand back a fresh array on every read, so writing to one
             * from its own delegate replaced the model and destroyed the
             * control mid-click - the button worked once and then stopped.
             */
            model: Settings.audio.streamBlacklist.length

            SettingRow {
                required property int index

                readonly property string modelData:
                    Settings.audio.streamBlacklist[index] || ""

                label: modelData
                alternate: index % 2 === 1

                CyberButton {
                    text: Settings.t("Remove")
                    destructive: true
                    onClicked: {
                        const list = Settings.audio.streamBlacklist.slice();
                        list.splice(index, 1);
                        Settings.audio.streamBlacklist = list;
                    }
                }
            }
        }

        Row {
            width: pane.innerWidth
            spacing: Theme.space2

            NotchRect {
                id: blacklistBox
                width: 280
                height: 30
                fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                strokeColor: newEntry.activeFocus ? Theme.accent : Theme.border
                notch: 5

                TextInput {
                    id: newEntry
                    anchors.fill: parent
                    anchors.margins: Theme.space2
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSmall
                    selectionColor: Theme.accent

                    function commit() {
                        const v = text.trim();
                        if (v === "") return;
                        const list = Settings.audio.streamBlacklist.slice();
                        if (list.indexOf(v) === -1) {
                            list.push(v);
                            Settings.audio.streamBlacklist = list;
                        }
                        text = "";
                    }

                    onAccepted: commit()

                    CyberText {
                        visible: newEntry.text === ""
                        text: Settings.t("Name to hide, e.g. cava")
                        role: "micro"
                        caps: false
                        color: Theme.textMuted
                    }
                }
            }

            CyberButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Add"
                onClicked: newEntry.commit()
            }
        }

    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Visualiser")
        subtitle: Settings.t("The spectrum widget is configured with the desktop widgets")
        accentColor: Theme.accent
        glitch: false
        expanded: false


        SettingRow {
            label: Settings.t("Band count and frame rate")
            description: Settings.t("These belong to the desktop audio widget, so they live with it")
            CyberButton {
                text: Settings.t("Open Desktop")
                onClicked: Shell.controlCenterTab = "desktop"
            }
        }
    }
}
