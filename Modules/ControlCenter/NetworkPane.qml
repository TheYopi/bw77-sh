import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Network & Internet.
 *
 * The same state the quick settings tile reads, given room to be a settings
 * page rather than a drop-down: the panel's job is to switch the radio and join
 * something nearby, and this one's is everything you would otherwise open
 * nm-connection-editor for.
 *
 * Laid out the way GNOME's Network panel is - a row per kind of connection
 * saying what it is doing, each opening into its own page - because that is the
 * shape the reader already has for this. Wired is a row and not a page: there
 * is nothing to choose about a cable.
 *
 * Polling is only worth its cost while somebody is looking, which is what
 * SysState.active is for. The quick settings panel does the same.
 */
PaneScroll {
    id: pane

    Component.onCompleted: SysState.active = true
    Component.onDestruction: SysState.active = false

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Network & Internet")
        subtitle: SysState.netLabel
    }

    /*
     * --- Wi-Fi
     *
     * A page, because it is a list that grows to whatever is in the air around
     * you and the rest of this pane should not have to scroll past it.
     */
    PaneGroup {
        width: pane.innerWidth
        title: "Wi-Fi"
        page: true
        pageValue: !SysState.wifiPresent ? Settings.t("No adapter")
            : (!SysState.wifiEnabled ? Settings.t("Off")
                : (SysState.netType === "wifi" && SysState.netConnected
                    ? SysState.netName : Settings.t("Not connected")))
        accentColor: Theme.accent
        glitch: false

        SettingRow {
            label: Settings.t("Wi-Fi")
            description: Settings.t("Turns the wireless radio off entirely")
            navigable: SysState.wifiPresent
            CyberToggle {
                checked: SysState.wifiEnabled
                onToggled: () => SysState.toggleWifi()
            }
        }

        SettingRow {
            label: Settings.t("Scan for networks")
            description: Settings.t("Asks the adapter to look again; the list updates on its own otherwise")
            alternate: true
            visible: SysState.wifiPresent && SysState.wifiEnabled
            CyberButton {
                text: SysState.wifiScanning ? Settings.t("Scanning") : Settings.t("Scan")
                active: SysState.wifiScanning
                onClicked: SysState.rescanWifi()
            }
        }

        CyberText {
            width: pane.innerWidth
            visible: !SysState.wifiPresent
            text: Settings.t("No Wi-Fi adapter")
            role: "micro"
            caps: false
            color: Theme.textMuted
        }

        CyberText {
            width: pane.innerWidth
            visible: SysState.wifiPresent && !SysState.wifiEnabled
            text: Settings.t("Wi-Fi is off")
            role: "micro"
            caps: false
            color: Theme.textMuted
        }

        CyberText {
            width: pane.innerWidth
            visible: SysState.wifiPresent && SysState.wifiEnabled
                && SysState.accessPoints.length === 0
            text: Settings.t("No networks found")
            role: "micro"
            caps: false
            color: Theme.textMuted
        }

        /*
         * One row per network.
         *
         * The active one offers to disconnect and everything else offers to
         * join; a secured network that has never been joined needs a password,
         * and asking for it here rather than sending you elsewhere is the same
         * bargain the quick settings list makes. What this adds is room for the
         * signal strength and the lock to be read at a glance.
         */
        Repeater {
            model: SysState.accessPoints

            SettingRow {
                id: apRow
                required property var modelData
                required property int index

                readonly property bool current: modelData.active === true

                label: modelData.ssid
                description: (modelData.secure ? Settings.t("Secured") : Settings.t("Open"))
                    + " · " + modelData.signal + "%"
                alternate: index % 2 === 1
                visible: SysState.wifiPresent && SysState.wifiEnabled

                CyberButton {
                    text: apRow.current ? Settings.t("Disconnect") : Settings.t("Connect")
                    active: apRow.current
                    onClicked: {
                        if (apRow.current) SysState.disconnectAp();
                        else if (apRow.modelData.secure) ask.askFor(apRow.modelData.ssid);
                        else SysState.connectToAp(apRow.modelData.ssid, "");
                    }
                }
            }
        }

        /*
         * The password prompt, one of them for the whole list.
         *
         * A field per row would be twelve text inputs on a pane, eleven of them
         * for networks nobody is joining. This one names the network it is
         * asking about and goes away again once it has been answered.
         */
        Item {
            id: ask
            width: pane.innerWidth
            height: asking ? 44 : 0
            visible: height > 0
            clip: height < 44

            // Not called `open`: a property and a function cannot share a name
            // on the same object, and this needs both a state and a way in.
            property bool asking: false
            property string ssid: ""

            function askFor(name) {
                ask.ssid = name;
                ask.asking = true;
                pw.text = "";
                pw.forceActiveFocus();
            }

            Behavior on height {
                enabled: !Theme.reducedMotion && Settings.animations.surfaceOpen
                NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeSnap }
            }

            NotchRect {
                anchors.fill: parent
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                strokeColor: Theme.alpha(Theme.accent, 0.5)
                notch: Theme.notchSmall
            }

            CyberText {
                id: askLabel
                anchors.left: parent.left
                anchors.leftMargin: Theme.space3
                anchors.verticalCenter: parent.verticalCenter
                text: ask.ssid
                role: "label"
                color: Theme.accent
            }

            TextInput {
                id: pw
                anchors.left: askLabel.right
                anchors.leftMargin: Theme.space3
                anchors.right: joinButton.left
                anchors.rightMargin: Theme.space3
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                color: Theme.text
                font.family: Theme.fontBody
                font.pixelSize: Theme.fontBase
                selectionColor: Theme.accent
                selectedTextColor: Theme.textOnAccent
                clip: true

                Keys.onReturnPressed: joinButton.clicked()
                Keys.onEscapePressed: ask.asking = false
            }

            CyberButton {
                id: joinButton
                anchors.right: parent.right
                anchors.rightMargin: Theme.space3
                anchors.verticalCenter: parent.verticalCenter
                text: Settings.t("Join")
                onClicked: {
                    SysState.connectToAp(ask.ssid, pw.text);
                    ask.asking = false;
                }
            }
        }
    }

    // --- wired
    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Wired")
        subtitle: SysState.netType === "ethernet" && SysState.netConnected
            ? SysState.netName : Settings.t("Not connected")
        accentColor: Theme.accent
        glitch: false
        collapsible: false
        visible: SysState.netPresent
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Connections")
        accentColor: Theme.accent
        glitch: false
        collapsible: false

        SettingRow {
            label: Settings.t("Network settings")
            description: Settings.t("Opens NetworkManager's own editor for VPNs, static addresses and everything this page does not cover")
            CyberButton {
                text: Settings.t("Open")
                onClicked: SysState.openNetworkSettings()
            }
        }
    }
}
