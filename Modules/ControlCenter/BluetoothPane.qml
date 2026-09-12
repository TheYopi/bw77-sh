import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Bluetooth.
 *
 * The quick settings list is built for one job - reconnect the headphones -
 * and it is the right list for that. This is the other half: what is paired,
 * what it is doing, and the two destructive things (forget, untrust) that have
 * no business being one tap away on a panel you open by accident.
 *
 * Every device is a page of its own, as in GNOME's mockups. A row in the list
 * says the name and whether it is connected; going in gives the connect switch,
 * the trust switch, the battery if bluez reports one, and the address - which
 * is the only way to tell two identically named earbuds apart.
 */
PaneScroll {
    id: pane

    Component.onCompleted: SysState.active = true
    Component.onDestruction: {
        // Scanning is expensive and drains a laptop, so it does not outlive the
        // pane that started it - the same bargain the quick settings menu makes.
        SysState.setBtScanning(false);
        SysState.active = false;
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Bluetooth")
        subtitle: SysState.btLabel
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Adapter")
        accentColor: Theme.accent
        glitch: false
        collapsible: false

        SettingRow {
            label: Settings.t("Bluetooth")
            description: Settings.t("Powers the controller; paired devices reconnect on their own once it is on")
            navigable: SysState.btAvailable
            CyberToggle {
                checked: SysState.btPowered
                onToggled: () => SysState.toggleBluetooth()
            }
        }

        SettingRow {
            label: Settings.t("Scan for devices")
            description: Settings.t("bluez only reports devices that are not yet paired while it is scanning")
            alternate: true
            visible: SysState.btAvailable && SysState.btPowered
            CyberButton {
                text: SysState.btScanning ? Settings.t("Scanning") : Settings.t("Scan")
                active: SysState.btScanning
                onClicked: SysState.toggleBtScanning()
            }
        }

        CyberText {
            width: pane.innerWidth
            visible: !SysState.btAvailable
            text: Settings.t("No Bluetooth adapter")
            role: "micro"
            caps: false
            color: Theme.textMuted
        }

        // Pairing reports its failures here rather than in a dialog: the thing
        // that went wrong is about the device you are looking at.
        CyberText {
            width: pane.innerWidth
            visible: SysState.pairError !== ""
            text: SysState.pairError
            role: "micro"
            caps: false
            color: Theme.danger
            wrapMode: Text.Wrap
        }
    }

    CyberText {
        width: pane.innerWidth
        visible: SysState.btAvailable && SysState.btPowered
            && SysState.btDevices.length === 0
        text: Settings.t("No devices yet - press SCAN and put the device in pairing mode")
        role: "micro"
        caps: false
        color: Theme.textMuted
        wrapMode: Text.Wrap
    }

    /*
     * A page per device.
     *
     * The list is rebuilt whenever bluez reports anything, so these delegates
     * come and go; a page open on a device that has just been rewritten is the
     * one case worth watching, and it survives because PaneScroll holds the
     * group object rather than an index into the model.
     */
    Repeater {
        model: SysState.btDevices

        PaneGroup {
            id: deviceGroup
            required property var modelData

            width: pane.innerWidth
            title: modelData.name
            page: true
            pageValue: modelData.connected ? Settings.t("Connected")
                : (SysState.isPairing(modelData) ? Settings.t("Pairing")
                    : (modelData.paired ? Settings.t("Paired") : Settings.t("Not paired")))
            accentColor: Theme.accent
            glitch: false

            SettingRow {
                label: modelData.connected ? Settings.t("Connected")
                                           : Settings.t("Connect")
                description: modelData.paired
                    ? Settings.t("Disconnecting leaves the pairing in place")
                    : Settings.t("Pairs first; some devices need a code entered on the device itself")
                CyberToggle {
                    checked: deviceGroup.modelData.connected
                    onToggled: () => SysState.connectDevice(deviceGroup.modelData)
                }
            }

            SettingRow {
                label: Settings.t("Trusted")
                description: Settings.t("An untrusted device cannot reconnect on its own")
                alternate: true
                visible: deviceGroup.modelData.paired
                CyberToggle {
                    checked: deviceGroup.modelData.trusted
                    onToggled: (v) => SysState.setDeviceTrusted(deviceGroup.modelData, v)
                }
            }

            SettingRow {
                label: Settings.t("Battery")
                visible: deviceGroup.modelData.battery >= 0
                navigable: false
                CyberText {
                    text: deviceGroup.modelData.battery + "%"
                    role: "label"
                    color: Theme.text
                }
            }

            SettingRow {
                label: Settings.t("Address")
                description: Settings.t("The controller's own name for this device")
                alternate: true
                navigable: false
                CyberText {
                    text: deviceGroup.modelData.mac
                    role: "mono"
                    caps: false
                    color: Theme.textMuted
                }
            }

            SettingRow {
                label: Settings.t("Forget this device")
                description: Settings.t("Removes the pairing; the device has to be paired again from scratch")
                visible: deviceGroup.modelData.paired
                CyberButton {
                    text: Settings.t("Forget")
                    destructive: true
                    onClicked: {
                        SysState.forgetDevice(deviceGroup.modelData);
                        // The device this page is about is on its way out.
                        pane.popPage();
                    }
                }
            }
        }
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Elsewhere")
        accentColor: Theme.accent
        glitch: false
        collapsible: false

        SettingRow {
            label: Settings.t("Bluetooth settings")
            description: Settings.t("Opens blueman or another manager for anything this page does not cover")
            CyberButton {
                text: Settings.t("Open")
                onClicked: SysState.openBluetoothSettings()
            }
        }
    }
}
