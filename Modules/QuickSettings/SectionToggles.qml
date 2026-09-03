import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * The tile grid: two columns, no frame and no title.
 *
 * Network and bluetooth lead each column and expand into submenus; the rest are
 * plain toggles. An expanded submenu spans the full width beneath its row
 * rather than squeezing into one column, so connection names stay readable.
 */
QsSection {
    id: root

    // "" | "network" | "bluetooth" | "power"
    property string openMenu: ""

    function tileEnabled(id) {
        const list = Settings.quickSettings.tiles;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) return list[i].enabled !== false;
        }
        return true;      // unknown ids default to visible
    }

    readonly property real colWidth: (width - Theme.space2) / 2

    Column {
        id: layout
        width: parent.width
        spacing: Theme.space2

        // --- row one: network and bluetooth
        //
        // Collapses entirely when both are hidden, rather than leaving the gap
        // its spacing would otherwise reserve.
        Row {
            visible: root.tileEnabled("network") || root.tileEnabled("bluetooth")
            height: visible ? implicitHeight : 0
            width: parent.width
            spacing: Theme.space2

            QsTile {
                visible: root.tileEnabled("network")
                width: visible ? root.colWidth : 0
                glyph: SysState.netIcon
                label: SysState.netConnected ? SysState.netLabel : "Network"
                detail: SysState.netConnected
                    ? (SysState.netType === "wifi"
                        ? SysState.netStrength + "%" : "Wired")
                    : "Offline"
                on: SysState.netConnected
                tint: root.accentColor
                expandable: true
                expanded: root.openMenu === "network"

                // Tapping the tile toggles the radio; the chevron lists networks.
                onActivated: SysState.toggleWifi()
                onExpandToggled: root.openMenu = root.openMenu === "network" ? "" : "network"
            }

            QsTile {
                visible: root.tileEnabled("bluetooth")
                width: visible ? root.colWidth : 0
                glyph: SysState.btPowered ? "\uf293" : "\uf294"
                label: Settings.t("Bluetooth")
                detail: SysState.btLabel
                on: SysState.btPowered
                tint: root.accentColor
                expandable: true
                expanded: root.openMenu === "bluetooth"

                onActivated: SysState.toggleBluetooth()
                onExpandToggled: {
                    const opening = root.openMenu !== "bluetooth";
                    root.openMenu = opening ? "bluetooth" : "";

                    // Scanning is expensive and drains a laptop, so it starts
                    // with the menu and stops when it closes.
                    if (opening && SysState.btPowered) SysState.setBtScanning(true);
                    else SysState.setBtScanning(false);
                }
            }
        }

        // --- network submenu
        QsSubmenu {
            width: parent.width
            visible: root.openMenu === "network"
            tint: root.accentColor
            rowCount: SysState.accessPoints.length
            emptyText: SysState.netType === "ethernet"
                ? "Wired connection active"
                : (SysState.wifiEnabled ? Settings.t("No networks found") : Settings.t("Wi-Fi is off"))

            QsSubmenuHeader {
                label: "Wi-Fi"
                tint: root.accentColor
                checked: SysState.wifiEnabled
                scanning: SysState.wifiScanning
                onToggled: SysState.toggleWifi()
                onScanRequested: SysState.rescanWifi()
            }

            Repeater {
                model: SysState.accessPoints

                Column {
                    id: apEntry
                    required property var modelData

                    // Asking for a password inline beats sending you to another
                    // application for the one thing you came here to do.
                    readonly property bool needsPassword:
                        modelData.secure && !modelData.active
                    property bool asking: false

                    width: parent.width
                    spacing: 1

                    QsDeviceRow {
                        glyph: apEntry.modelData.secure ? "\uf023" : "\uf09c"
                        label: apEntry.modelData.ssid
                        detail: apEntry.modelData.active ? "Connected" : ""
                        active: apEntry.modelData.active
                        signal: apEntry.modelData.signal
                        tint: root.accentColor

                        onActivated: {
                            if (apEntry.modelData.active) {
                                SysState.disconnectAp();
                                return;
                            }
                            // Try without a password first: a saved network
                            // connects straight away and never needs the prompt.
                            if (apEntry.needsPassword && apEntry.asking) return;
                            if (apEntry.needsPassword) {
                                apEntry.asking = true;
                                return;
                            }
                            SysState.connectToAp(apEntry.modelData.ssid, "");
                        }
                    }

                    Row {
                        width: parent.width
                        height: apEntry.asking ? 30 : 0
                        visible: apEntry.asking
                        spacing: Theme.space2

                        NotchRect {
                            width: parent.width - 92
                            height: 26
                            anchors.verticalCenter: parent.verticalCenter
                            fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                            strokeColor: Theme.alpha(root.accentColor, 0.6)
                            notch: 4

                            TextInput {
                                id: pass
                                anchors.fill: parent
                                anchors.margins: Theme.space2
                                verticalAlignment: Text.AlignVCenter
                                echoMode: TextInput.Password
                                passwordCharacter: "\u25AC"
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSmall
                                selectionColor: root.accentColor
                                focus: apEntry.asking

                                onAccepted: {
                                    SysState.connectToAp(apEntry.modelData.ssid, text);
                                    text = "";
                                    apEntry.asking = false;
                                }

                                CyberText {
                                    visible: pass.text === ""
                                    text: Settings.t("Password")
                                    role: "micro"
                                    caps: false
                                    color: Theme.textMuted
                                }
                            }
                        }

                        CyberButton {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Settings.t("Join")
                            hPadding: Theme.space2
                            onClicked: {
                                SysState.connectToAp(apEntry.modelData.ssid, pass.text);
                                pass.text = "";
                                apEntry.asking = false;
                            }
                        }

                        CyberText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u2715"
                            role: "micro"
                            color: Theme.textMuted

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { pass.text = ""; apEntry.asking = false; }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 30

                CyberText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space2
                    height: parent.height
                    text: Settings.t("Open network settings")
                    role: "micro"
                    caps: false
                    color: settingsMouse.containsMouse ? root.accentColor : Theme.textMuted
                }

                MouseArea {
                    id: settingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SysState.openNetworkSettings()
                }
            }
        }

        // --- bluetooth submenu
        QsSubmenu {
            width: parent.width
            visible: root.openMenu === "bluetooth"
            tint: root.accentColor
            visibleRows: 6
            rowCount: SysState.btDevices.length
            emptyText: SysState.btAvailable
                ? (SysState.btPowered ? Settings.t("Press SCAN to find devices") : Settings.t("Bluetooth is off"))
                : "No adapter found"

            QsSubmenuHeader {
                label: Settings.t("Bluetooth")
                tint: root.accentColor
                checked: SysState.btPowered
                toggleEnabled: SysState.btAvailable
                scanning: SysState.btScanning
                onToggled: SysState.toggleBluetooth()
                onScanRequested: SysState.toggleBtScanning()
            }

            // --- paired devices
            CyberText {
                visible: SysState.btPaired.length > 0
                width: parent.width
                leftPadding: Theme.space2
                text: Settings.t("Paired")
                role: "micro"
                color: Theme.textMuted
            }

            Repeater {
                model: SysState.btPaired

                QsDeviceRow {
                    required property var modelData
                    glyph: modelData.connected ? "\uf293" : "\uf294"
                    label: modelData.name
                    detail: {
                        if (SysState.isPairing(modelData)) return "Connecting";
                        if (modelData.connected)
                            return modelData.battery >= 0
                                ? modelData.battery + "%" : "Connected";
                        // An untrusted device cannot reconnect on its own, which
                        // is worth saying rather than leaving it to be puzzled over.
                        if (!modelData.trusted) return "Tap to connect · not trusted";
                        return "Tap to connect";
                    }
                    active: modelData.connected
                    busy: SysState.isPairing(modelData)
                    tint: root.accentColor
                    showRemove: true

                    onActivated: SysState.connectDevice(modelData)
                    onRemoved: SysState.forgetDevice(modelData)
                }
            }

            // --- newly discovered devices
            //
            // Only ever populated while scanning: bluez reports nearby unpaired
            // devices for the duration of a discovery session and no longer.
            CyberText {
                visible: SysState.btDiscovered.length > 0
                width: parent.width
                leftPadding: Theme.space2
                text: Settings.t("Available")
                role: "micro"
                color: Theme.textMuted
            }

            Repeater {
                model: SysState.btDiscovered

                QsDeviceRow {
                    required property var modelData
                    glyph: "\uf2db"
                    label: modelData.name
                    detail: SysState.isPairing(modelData) ? Settings.t("Pairing") : Settings.t("Tap to pair")
                    busy: SysState.isPairing(modelData)
                    tint: root.accentColor

                    onActivated: SysState.connectDevice(modelData)
                }
            }

            Item {
                width: parent.width
                height: SysState.pairError !== "" ? 34 : 0
                visible: SysState.pairError !== ""

                NotchRect {
                    anchors.fill: parent
                    anchors.margins: 2
                    fillColor: Theme.alpha(Theme.danger, 0.18)
                    strokeColor: Theme.danger
                    notch: 4
                }

                CyberText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space2
                    anchors.right: dismissError.left
                    anchors.rightMargin: Theme.space2
                    height: parent.height
                    text: SysState.pairError
                    role: "micro"
                    caps: false
                    color: Theme.textDanger
                    elide: Text.ElideRight
                }

                CyberText {
                    id: dismissError
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space2
                    height: parent.height
                    text: "\u2715"
                    role: "micro"
                    color: Theme.textDanger

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SysState.clearPairError()
                    }
                }
            }

            CyberText {
                visible: SysState.btPowered && !SysState.btScanning
                         && SysState.btDiscovered.length === 0
                width: parent.width
                leftPadding: Theme.space2
                text: Settings.t("Put the device in pairing mode, then press SCAN")
                role: "micro"
                caps: false
                color: Theme.textMuted
                wrapMode: Text.Wrap
            }

            Item {
                width: parent.width
                height: 30

                CyberText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space2
                    height: parent.height
                    text: Settings.t("Open bluetooth settings")
                    role: "micro"
                    caps: false
                    color: btSettingsMouse.containsMouse ? root.accentColor : Theme.textMuted
                }

                MouseArea {
                    id: btSettingsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SysState.openBluetoothSettings()
                }
            }
        }

        /*
         * --- power profile
         *
         * Full width rather than half, and on its own row.
         *
         * It is the only tile whose value is a word rather than an on/off
         * state, so the detail line carries the active profile - and "Power
         * saver" or "Performance" in half a column next to a wrapped label is
         * unreadable. The row collapses entirely when the tile is switched off
         * in Settings, rather than leaving the gap its spacing would reserve.
         */
        QsTile {
            visible: root.tileEnabled("power")
            width: parent.width
            height: visible ? implicitHeight : 0

            glyph: Power.glyph
            label: Settings.t("Power profile")
            detail: Power.label + (Power.held ? " \u00B7 " + Settings.t("held") : "")
            on: Power.active
            tint: root.accentColor
            expandable: true
            expanded: root.openMenu === "power"

            // Tapping the tile steps to the next profile, the chevron lists
            // them - the same split as the network tile, where the body does
            // the obvious thing and the chevron offers the choice.
            onActivated: Power.cycle()
            onExpandToggled: root.openMenu = root.openMenu === "power" ? "" : "power"
        }

        // --- power profile submenu
        QsSubmenu {
            width: parent.width
            visible: root.openMenu === "power"
            tint: root.accentColor
            visibleRows: 4
            rowCount: Power.profiles.length
            emptyText: Settings.t("power-profiles-daemon is not responding")

            Repeater {
                model: Power.profiles

                QsDeviceRow {
                    required property var modelData
                    glyph: modelData.glyph
                    label: modelData.l
                    detail: modelData.v === Power.profile ? Settings.t("Active") : ""
                    active: modelData.v === Power.profile
                    tint: root.accentColor

                    onActivated: Power.setProfile(modelData.v)
                }
            }

            /*
             * Why the profile might not be what was asked for.
             *
             * Two different things can override a choice: another application
             * holding a profile, and the daemon throttling for heat. Both look
             * from the outside like the setting having been ignored, so each
             * says so rather than leaving it to be puzzled over.
             */
            CyberText {
                visible: Power.held
                width: parent.width
                leftPadding: Theme.space2
                rightPadding: Theme.space2
                text: Power.holdReason
                role: "micro"
                caps: false
                color: Theme.textMuted
                wrapMode: Text.Wrap
            }

            CyberText {
                visible: Power.degradation !== ""
                width: parent.width
                leftPadding: Theme.space2
                rightPadding: Theme.space2
                text: Power.degradation
                role: "micro"
                caps: false
                color: Theme.textDanger
                wrapMode: Text.Wrap
            }
        }

        // --- the plain toggles
        Grid {
            width: parent.width
            columns: 2
            spacing: Theme.space2

            /*
             * --- the plain toggles
             *
             * The model is a static list of ids, and every tile binds its own
             * state from it.
             *
             * It used to be an array of objects built inline, holding snapshots
             * of Audio.muted, the do-not-disturb flag and so on. Because those
             * values were read while constructing the array, the whole array
             * was rebuilt whenever any of them changed - and a Repeater given a
             * new array destroys and recreates every delegate. Pressing one
             * tile therefore tore down all four and built them again, which is
             * where the stray highlight came from: for a frame the recreated
             * tiles carry whichever hover and fill state they were born with
             * before their bindings settle.
             *
             * With ids in the model the array only changes when a tile is
             * turned on or off in settings. Pressing one now updates one
             * binding on one tile and nothing is rebuilt at all.
             */
            Repeater {
                model: ["dnd", "sound", "mic", "reduceMotion"]
                    .filter(id => root.tileEnabled(id))

                QsTile {
                    id: tile
                    required property string modelData

                    width: root.colWidth
                    tint: root.accentColor

                    glyph: {
                        switch (tile.modelData) {
                        case "dnd":          return "\uf1f6";
                        case "sound":        return Audio.muted ? "\uf026" : "\uf028";
                        case "mic":          return Audio.micMuted ? "\uf131" : "\uf130";
                        case "reduceMotion": return "\uf0eb";
                        }
                        return "";
                    }

                    label: {
                        switch (tile.modelData) {
                        case "dnd":   return Settings.t("Do not disturb");
                        case "sound": return Audio.muted ? Settings.t("Muted") : Settings.t("Sound");
                        case "mic":   return Audio.micMuted ? Settings.t("Mic off") : Settings.t("Mic on");
                        case "reduceMotion": return Settings.t("Reduce motion");
                        }
                        return "";
                    }

                    on: {
                        switch (tile.modelData) {
                        case "dnd":          return Settings.notifications.doNotDisturb;
                        case "sound":        return Audio.muted;
                        case "mic":          return Audio.micMuted;
                        case "reduceMotion": return Settings.general.reducedMotion;
                        }
                        return false;
                    }

                    // Muted audio is a state worth flagging; the others are
                    // preferences and should not read as a warning.
                    danger: (tile.modelData === "sound" && Audio.muted)
                        || (tile.modelData === "mic" && Audio.micMuted)

                    onActivated: {
                        switch (tile.modelData) {
                        case "dnd":
                            Settings.notifications.doNotDisturb =
                                !Settings.notifications.doNotDisturb;
                            return;
                        case "sound":
                            Audio.toggleMute();
                            return;
                        case "mic":
                            Audio.toggleMicMute();
                            return;
                        case "reduceMotion":
                            Settings.general.reducedMotion =
                                !Settings.general.reducedMotion;
                            return;
                        }
                    }
                }
            }
        }
    }
}
