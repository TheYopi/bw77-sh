pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config

/*
 * Network and bluetooth state, fed by Scripts/netbt.sh.
 *
 * A script rather than the compositor services because these have to work on
 * machines with no NetworkManager and no bluez: the script reports "unknown"
 * where a tool is missing, and the panel simply shows less rather than breaking.
 *
 * Only polled while something is watching, since bluetoothctl is not free.
 */
Singleton {
    id: root

    property bool active: false
    property int intervalSec: 5

    // --- network
    property string netType: "none"       // wifi | ethernet | none
    property string netName: ""
    property int netStrength: 0           // percent, wifi only
    property bool netConnected: false

    /*
     * --- offline and "there is nothing to be offline with" are not the same
     *
     * The panel could only say Offline, so a machine with no wireless card
     * looked like a machine that had not connected yet: the Wi-Fi toggle
     * offered to turn on a radio that was not there, the list below it said
     * "Wi-Fi is off", and neither statement was true. Both of these come from
     * the poller, which asks what devices exist rather than what they are
     * doing.
     */
    property bool netPresent: false
    property bool wifiPresent: false

    readonly property string netIcon: {
        if (!netPresent) return "\uf127";                    // broken link
        if (!netConnected) return "\uf127";
        if (netType === "ethernet") return "\uDB80\uDE00";   // nf-md-ethernet
        if (netStrength >= 70) return "\uf1eb";
        if (netStrength >= 40) return "\uf6aa";
        return "\uf6ab";
    }

    readonly property string netLabel: {
        if (!netPresent) return Settings.t("No adapter");
        if (!netConnected)
            return wifiPresent && !wifiEnabled ? Settings.t("Wi-Fi off")
                                               : Settings.t("Offline");
        if (netName !== "") return netName;
        return netType === "ethernet" ? Settings.t("Wired") : Settings.t("Connected");
    }

    /*
     * What the tile calls itself, which is not what it is connected to.
     *
     * GNOME's tile keeps one word in the title and puts the network in the line
     * underneath, and it is the better arrangement for the same reason the
     * glyph sits in a fixed slot: the title stays put while the value changes,
     * so a column of tiles can be read down rather than re-read every time
     * something reconnects. It also stops a long SSID eliding the one word
     * that says which tile this is.
     */
    readonly property string netKind: {
        if (!netPresent) return Settings.t("Network");
        if (netType === "ethernet") return Settings.t("Wired");
        if (wifiPresent) return "Wi-Fi";
        return Settings.t("Network");
    }

    // --- access points from the poller
    property var accessPoints: []
    property bool wifiEnabled: false

    function toggleWifi() {
        // Nothing to switch on, and nmcli would report as much into a void.
        if (!wifiPresent) return;
        Quickshell.execDetached(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"]);
        refresh.restart();
    }

    function connectToAp(ssid, password) {
        // A saved network needs no password; a new secured one does, and the
        // panel asks for it inline rather than sending you to another app.
        if (password && password !== "") {
            Quickshell.execDetached(["nmcli", "device", "wifi", "connect", ssid,
                                     "password", password]);
        } else {
            Quickshell.execDetached(["nmcli", "device", "wifi", "connect", ssid]);
        }
        refresh.restart();
    }

    function disconnectAp() {
        Quickshell.execDetached(["sh", "-c",
            "nmcli -t -f DEVICE,TYPE device | awk -F: '$2==\"wifi\"{print $1; exit}' " +
            "| xargs -r nmcli device disconnect"]);
        refresh.restart();
    }

    property bool wifiScanning: false

    function rescanWifi() {
        wifiScanning = true;
        rescanProc.running = false;
        rescanProc.running = true;
    }

    Process {
        id: rescanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: {
            // The scan takes a moment to populate; refresh once it settles.
            root.wifiScanning = false;
            refresh.restart();
        }
    }

    // --- bluetooth
    //
    // The native backend is used when the build has the module, and its live
    // signals beat polling for both latency and cost. The polled values below
    // stay as the fallback.
    readonly property var bt: btLoader.status === Loader.Ready ? btLoader.item : null

    /*
     * --- the native backend drives only while it has an adapter
     *
     * This used to be true as soon as the module loaded, which meant every
     * bluetooth reading came from bluez's default adapter - including on a
     * machine that had none, where "no default adapter" was reported as
     * unavailable and powered off, and the polled fallback was never consulted
     * again.
     *
     * That is the state a dongle gets plugged into: bluez may hand the shell a
     * default adapter promptly or not at all, and while it does not, the tile
     * insisted bluetooth was off and unavailable while paired headphones
     * reconnected to it happily. Requiring an adapter here means the poller -
     * which reads the controller straight out of /sys and bluetoothctl every
     * few seconds - takes over for exactly as long as the native path has
     * nothing to say, so the tile agrees with the hardware either way.
     */
    readonly property bool btNative:
        bt !== null && bt.ok === true && bt.available === true

    Loader {
        id: btLoader
        // String source, not a component: a build without Quickshell.Bluetooth
        // then fails only this Loader instead of the whole shell.
        source: "Backends/BluetoothNative.qml"
        onStatusChanged: {
            if (status === Loader.Error)
                console.log("bw77: no native bluetooth module, using bluetoothctl");
        }
    }

    property bool btAvailablePolled: false
    property bool btPoweredPolled: false
    property int btCountPolled: 0
    property string btNamePolled: ""
    property var btDevicesPolled: []

    readonly property bool btAvailable: btNative || btAvailablePolled
    readonly property bool btPowered: btNative ? bt.powered : btPoweredPolled
    readonly property int btCount: btNative ? bt.connectedCount : btCountPolled
    readonly property string btName: btNative ? bt.primaryName : btNamePolled

    readonly property string btLabel: {
        if (!btAvailable) return Settings.t("No adapter");
        if (!btPowered) return Settings.t("Off");
        if (btCount === 0) return "On";
        if (btCount === 1 && btName !== "") return btName;
        return `${btCount} connected`;
    }

    function toggleBluetooth() {
        if (!btAvailable) return;
        if (btNative) {
            bt.setPowered(!btPowered);
            return;
        }
        Quickshell.execDetached(["bluetoothctl", "power", btPowered ? "off" : "on"]);
        refresh.restart();
    }

    /*
     * Devices in one shape regardless of source.
     *
     * The native path carries the live object through as `handle` so a click
     * can act on it directly; the polled path has only a MAC, so acting on it
     * means shelling out. Callers use connectDevice() and never care which.
     */
    /*
     * Devices from both sources, merged by address.
     *
     * The native adapter list is documented as the devices *connected* to the
     * adapter, so a device that is paired but idle can drop out of it - which
     * looks exactly like a freshly paired controller vanishing. The polled
     * bluetoothctl list is the complete set of known devices, so it supplies
     * membership while the native objects supply live state and the handle
     * needed to act on them.
     */
    readonly property var btDevices: {
        const byMac = {};
        const order = [];

        function put(mac, entry) {
            const key = String(mac).toUpperCase();
            if (!byMac[key]) order.push(key);
            byMac[key] = Object.assign(byMac[key] || {}, entry);
        }

        // Complete membership first.
        for (let i = 0; i < btDevicesPolled.length; i++) {
            const d = btDevicesPolled[i];
            if (!d.mac) continue;
            put(d.mac, {
                name: d.name,
                connected: d.connected,
                paired: d.paired !== undefined ? d.paired : true,
                pairing: false,
                trusted: true,
                battery: -1,
                mac: d.mac,
                dbusPath: "",
                handle: null
            });
        }

        // Live state and handles second, so they win where both exist.
        if (btNative) {
            const list = bt.devices;
            for (let i = 0; i < list.length; i++) {
                const d = list[i];
                const mac = macFromPath(d.dbusPath);
                if (mac === "") continue;
                put(mac, {
                    name: d.name || d.deviceName || "Unknown",
                    connected: d.connected,
                    paired: d.paired,
                    pairing: d.pairing,
                    trusted: d.trusted,
                    battery: d.batteryAvailable ? d.battery : -1,
                    mac: mac,
                    dbusPath: d.dbusPath,
                    handle: d
                });
            }
        }

        // Connected first, then paired, then the rest.
        return order.map(k => byMac[k]).sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return String(a.name).localeCompare(String(b.name));
        });
    }

    // Split so the panel can show what is already yours above what it just found.
    readonly property var btPaired: btDevices.filter(d => d.paired)
    readonly property var btDiscovered: btDevices.filter(d => !d.paired)

    // True while a pairing sequence is still completing, so a row can say so.
    // Covers both paths: the native watcher and the bluetoothctl session.
    readonly property string btPendingPath: btNative && bt ? bt.pendingPath : ""

    function isPairing(entry) {
        if (!entry) return false;
        if (entry.pairing) return true;
        if (pairingMac !== "") {
            const mac = entry.mac && entry.mac !== ""
                ? entry.mac : macFromPath(entry.dbusPath);
            if (mac !== "" && mac === pairingMac) return true;
        }
        return btPendingPath !== "" && btPendingPath === entry.dbusPath;
    }

    // --- discovery
    property bool btScanningPolled: false
    readonly property bool btScanning: btNative
        ? (bt.adapter ? bt.adapter.discovering : false)
        : btScanningPolled

    function setBtScanning(on) {
        if (btNative) {
            bt.setDiscovering(on);
            return;
        }

        // bluetoothctl needs a session held open for the duration, so scanning
        // runs as a timed process rather than a fire-and-forget command.
        if (on) {
            btScanningPolled = true;
            scanProc.running = false;
            scanProc.running = true;
            scanStop.restart();
        } else {
            btScanningPolled = false;
            scanProc.running = false;
        }
    }

    function toggleBtScanning() { setBtScanning(!btScanning); }

    /*
     * Trust, which is what lets a device reconnect without being asked.
     *
     * Worth exposing separately from connecting: a controller that has to be
     * woken by hand every time is usually one that was paired without ever
     * being trusted, and there is otherwise nowhere in the shell to see that,
     * let alone fix it.
     */
    function setDeviceTrusted(entry, on) {
        if (!entry) return;
        if (entry.handle) {
            bt.setTrusted(entry.handle, on);
            return;
        }
        const mac = entry.mac && entry.mac !== ""
            ? entry.mac : macFromPath(entry.dbusPath);
        if (mac === "") return;
        Quickshell.execDetached(["bluetoothctl", on ? "trust" : "untrust", mac]);
        refresh.restart();
    }

    function forgetDevice(entry) {
        if (!entry) return;

        // Remove through bluetoothctl as well as bluez: a device left in a
        // half-paired state is not always cleared by forget() alone, and this
        // is the escape hatch for exactly that case.
        const mac = entry.mac && entry.mac !== ""
            ? entry.mac : macFromPath(entry.dbusPath);

        if (entry.handle) bt.forgetDevice(entry.handle);
        if (mac !== "") Quickshell.execDetached(["bluetoothctl", "remove", mac]);
        refresh.restart();
    }

    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", "30", "scan", "on"]
        onExited: root.btScanningPolled = false
    }

    Timer {
        id: scanStop
        interval: 30000
        onTriggered: root.btScanningPolled = false
    }

    /*
     * The MAC address, derived from the bluez object path.
     *
     * A path looks like /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF, so the address
     * is the last segment with underscores turned back into colons. Needed
     * because pairing goes through bluetoothctl even on the native path.
     */
    function macFromPath(path) {
        if (!path) return "";
        const tail = String(path).split("/").pop();
        if (!tail.startsWith("dev_")) return "";
        return tail.substring(4).replace(/_/g, ":");
    }

    /*
     * Pairing always goes through bluetoothctl, even when the native module is
     * present.
     *
     * bluez will not complete a pairing without a registered agent to accept
     * it, and Quickshell's bluetooth module does not provide one - its own
     * notes say it is "missing support for things that require an agent". So
     * device.pair() starts an exchange that nothing can finish: the device
     * shows as paired for a moment, is never connected, and bluez discards the
     * entry once discovery ends. That is exactly the flashing-then-vanishing
     * behaviour.
     *
     * bluetoothctl does register an agent, so the sequence is handed to it.
     * Everything else - listing, state, connect, disconnect - stays native.
     */
    property string pairingMac: ""

    property string pairError: ""

    function pairViaAgent(mac) {
        if (!mac || mac === "") return;

        pairingMac = mac;
        pairError = "";
        setBtScanning(false);

        pairProc.command = ["bash", `${Quickshell.shellDir}/Scripts/bt-pair.sh`, mac];
        pairProc.running = false;
        pairProc.running = true;
    }

    /*
     * Pairing runs through a script rather than inline commands because
     * bluetoothctl may prompt for confirmation part-way, and a fixed pipe has
     * nothing to answer with. See Scripts/bt-pair.sh.
     */
    Process {
        id: pairProc

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = text.trim();
                if (msg !== "") root.pairError = msg.split("\n")[0];
            }
        }

        onExited: (code) => {
            root.pairingMac = "";
            if (code === 0) root.pairError = "";
            refresh.restart();
        }
    }

    function clearPairError() { pairError = ""; }

    function connectDevice(entry) {
        if (!entry) return;

        // Unpaired: hand the whole sequence to bluetoothctl regardless of path.
        if (!entry.paired) {
            const mac = entry.mac && entry.mac !== ""
                ? entry.mac : macFromPath(entry.dbusPath);
            if (mac !== "") {
                pairViaAgent(mac);
            } else if (entry.handle) {
                // No address to work with; the native attempt is better than
                // silently doing nothing.
                bt.toggleDevice(entry.handle);
            }
            return;
        }

        if (entry.handle) {
            bt.toggleDevice(entry.handle);
            return;
        }

        if (entry.mac) {
            /*
             * One interactive session rather than three separate commands.
             *
             * Each `bluetoothctl <cmd>` invocation is its own session with no
             * agent registered, and pairing without an agent fails on anything
             * that needs confirmation. Piping the sequence into a single
             * session registers an agent first and keeps it alive throughout.
             */
            if (!entry.paired) {
                Quickshell.execDetached(["sh", "-c",
                    `printf 'agent NoInputNoOutput\ndefault-agent\n` +
                    `pair ${entry.mac}\ntrust ${entry.mac}\nconnect ${entry.mac}\n` +
                    `quit\n' | bluetoothctl`]);
            } else {
                if (entry.connected) {
                    Quickshell.execDetached(["bluetoothctl", "disconnect", entry.mac]);
                } else {
                    Quickshell.execDetached(["sh", "-c",
                        `bluetoothctl trust ${entry.mac}; ` +
                        `bluetoothctl connect ${entry.mac}`]);
                }
            }
            refresh.restart();
        }
    }

    function openNetworkSettings() {
        // nm-connection-editor is the most widely installed editor; falling
        // back to the GNOME panel covers most of the rest.
        Quickshell.execDetached(["sh", "-c",
            "command -v nm-connection-editor >/dev/null && nm-connection-editor || " +
            "gnome-control-center wifi"]);
    }

    function openBluetoothSettings() {
        Quickshell.execDetached(["sh", "-c",
            "command -v blueman-manager >/dev/null && blueman-manager || " +
            "command -v overskride >/dev/null && overskride || " +
            "gnome-control-center bluetooth"]);
    }

    // Nudges the poller after a toggle, so the UI does not wait a full interval.
    Timer {
        id: refresh
        interval: 700
        onTriggered: {
            proc.running = false;
            proc.running = root.active;
        }
    }

    Process {
        id: proc
        running: root.active
        command: ["bash", `${Quickshell.shellDir}/Scripts/netbt.sh`, String(root.intervalSec)]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line || line[0] !== "{") return;
                let d;
                try { d = JSON.parse(line); } catch (e) { return; }

                if (d.net) {
                    root.netType = d.net.type;
                    root.netName = d.net.name;
                    root.netStrength = d.net.strength;
                    root.netConnected = d.net.connected;
                    root.wifiEnabled = d.net.wifiEnabled === true;
                    root.wifiPresent = d.net.wifiPresent === true;
                    root.netPresent = d.net.present === true;
                    root.accessPoints = d.net.aps || [];
                }
                if (d.bt) {
                    root.btAvailablePolled = d.bt.available;
                    root.btPoweredPolled = d.bt.powered;
                    root.btCountPolled = d.bt.count;
                    root.btNamePolled = d.bt.name;
                    root.btDevicesPolled = d.bt.devices || [];
                }
            }
        }
    }
}
