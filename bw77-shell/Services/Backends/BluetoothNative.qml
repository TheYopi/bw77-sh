import QtQuick
import Quickshell
import Quickshell.Bluetooth

/*
 * Native bluez integration.
 *
 * Loaded through a Loader with a string source rather than imported directly,
 * because an import of a module the build lacks fails the WHOLE file that
 * imports it - and if that file is a singleton the entire shell refuses to
 * start. Isolated here, a missing module only sets Loader.status to Error and
 * SysState falls back to the polled script.
 *
 * This gives live updates with no polling, plus connect and disconnect, which
 * bluetoothctl scraping cannot match.
 */
Item {
    id: root

    readonly property bool ok: true

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool powered: adapter ? adapter.enabled : false

    // Devices from the default adapter, connected ones first so the panel
    // shows what matters without scrolling.
    readonly property var devices: {
        const list = adapter && adapter.devices ? adapter.devices.values : [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            if (!d) continue;
            out.push(d);
        }
        return out.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            return String(a.name || "").localeCompare(String(b.name || ""));
        });
    }

    readonly property int connectedCount: devices.filter(d => d.connected).length

    /*
     * Discovery.
     *
     * bluez only reports nearby unpaired devices while the adapter is
     * scanning, so without this the list can never contain anything new - which
     * is exactly why a controller in pairing mode was nowhere to be seen.
     */
    readonly property bool discovering: adapter ? adapter.discovering : false

    function setDiscovering(on) {
        if (adapter) adapter.discovering = on;
    }

    readonly property string primaryName: {
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].connected) return devices[i].name || devices[i].deviceName || "";
        }
        return "";
    }

    function setPowered(on) {
        if (adapter) adapter.enabled = on;
    }

    /*
     * Connect and disconnect only.
     *
     * Pairing deliberately does NOT happen here: bluez needs a registered agent
     * to accept one, and this module does not provide it, so device.pair()
     * starts an exchange nothing can finish. SysState routes pairing through
     * bluetoothctl instead and lets this handle everything afterwards.
     */
    function toggleDevice(device) {
        if (!device) return;
        if (!device.paired) return;      // SysState handles unpaired devices

        // An untrusted device cannot reconnect on its own, so fix that on the
        // way through - it also repairs anything left untrusted by an earlier
        // pairing attempt.
        if (!device.trusted) device.trusted = true;
        device.connected = !device.connected;
    }

    // Kept for the UI: reports a pairing started elsewhere.
    readonly property string pendingPath: ""

    function forgetDevice(device) {
        if (!device) return;
        if (root.pendingPath === device.dbusPath) root.pendingPath = "";
        device.forget();
    }

    function setTrusted(device, on) {
        if (device) device.trusted = on;
    }

    function cancelPairing(device) {
        if (device && device.pairing) device.cancelPair();
    }
}
