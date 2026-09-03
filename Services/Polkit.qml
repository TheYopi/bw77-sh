pragma Singleton

import QtQuick
import Quickshell
import qs.Config

/*
 * Authentication requests from the polkit daemon.
 *
 * The backend sits behind a Loader so a build without the polkit module
 * degrades to doing nothing rather than breaking the shell.
 */
Singleton {
    id: root

    readonly property var backend: loader.status === Loader.Ready ? loader.item : null
    readonly property bool supported: backend !== null && backend.ok === true

    readonly property bool registered: supported && backend.registered
    readonly property bool conflicted: supported && backend.conflicted

    readonly property bool active: Settings.polkit.enabled && supported && backend.active

    readonly property string message: supported ? backend.message : ""
    readonly property string iconName: supported ? backend.iconName : ""
    readonly property string actionId: supported ? backend.actionId : ""
    readonly property string prompt: supported ? backend.prompt : ""
    readonly property string supplementary: supported ? backend.supplementary : ""
    readonly property bool supplementaryIsError: supported && backend.supplementaryIsError
    readonly property bool responseRequired: supported && backend.responseRequired
    readonly property bool responseVisible: supported && backend.responseVisible

    readonly property var identities: supported ? backend.identities : []
    readonly property var selectedIdentity: supported ? backend.selectedIdentity : null

    function identityName(identity) {
        return supported ? backend.identityName(identity) : "";
    }

    function selectIdentity(identity) {
        if (supported) backend.selectIdentity(identity);
    }

    function submit(text) {
        if (supported) backend.submit(text);
    }

    /*
     * Cancels the request properly.
     *
     * This tells the daemon the user declined, which releases the application
     * that was waiting. The flow then ends and the dialog closes on its own -
     * nothing here needs to hide it, and nothing should, because a hidden
     * dialog over a live request is the failure this replaced.
     */
    function cancel() {
        if (supported) backend.cancel();
    }

    function describe() {
        if (supported) backend.describe();
        else console.log("bw77 polkit ── module unavailable in this build");
    }

    Loader {
        id: loader
        active: Settings.polkit.enabled
        source: "Backends/PolkitBackend.qml"

        onStatusChanged: {
            if (status === Loader.Error)
                console.log("bw77: polkit module unavailable, agent disabled");
        }
    }
}
