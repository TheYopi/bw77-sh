import QtQuick
import Quickshell
import Quickshell.Services.Polkit

/*
 * Polkit agent backend.
 *
 * Loaded through a Loader with a string source rather than imported directly:
 * an import of a module the build lacks fails the whole file, and if that file
 * is a singleton the shell refuses to start.
 *
 * Property names here come from the module's own type description rather than
 * the prose documentation, which names neither the cancel method nor the `is`
 * prefix the state properties actually use.
 */
Item {
    id: root

    readonly property bool ok: true

    PolkitAgent {
        id: agent
    }

    // Only one agent may register per session; false means another already has.
    readonly property bool registered: agent.isRegistered === true
    readonly property bool conflicted: agent.isRegistered === false

    // Null when no request is in flight.
    readonly property var flow: agent.flow
    readonly property bool active: flow !== null && flow !== undefined
                                   && flow.isActive !== false

    readonly property string message: active && flow.message ? String(flow.message) : ""
    readonly property string iconName: active && flow.iconName ? String(flow.iconName) : ""
    readonly property string actionId: active && flow.actionId ? String(flow.actionId) : ""

    readonly property string prompt:
        active && flow.inputPrompt ? String(flow.inputPrompt) : ""
    readonly property string supplementary:
        active && flow.supplementaryMessage ? String(flow.supplementaryMessage) : ""
    readonly property bool supplementaryIsError:
        active && flow.supplementaryIsError === true

    readonly property bool responseRequired:
        active && flow.isResponseRequired === true

    // The daemon says whether the reply is a secret. A one-time code prompt is
    // not, and masking it would be actively unhelpful.
    readonly property bool responseVisible:
        active && flow.responseVisible === true

    /*
     * Which user is authenticating.
     *
     * Some actions are only grantable by particular users - often root, or a
     * wheel-group account rather than the one at the keyboard. The identity
     * list says who is permitted, and selectedIdentity is which of them the
     * password will be checked against.
     */
    readonly property var identities: active && flow.identities ? flow.identities : []
    readonly property var selectedIdentity: active ? flow.selectedIdentity : null

    function selectIdentity(identity) {
        if (active && identity) flow.selectedIdentity = identity;
    }

    function identityName(identity) {
        if (!identity) return "";
        if (identity.name !== undefined) return String(identity.name);
        if (identity.userName !== undefined) return String(identity.userName);
        return String(identity);
    }

    readonly property bool cancelSupported: active

    function submit(text) {
        if (active) flow.submit(text);
    }

    /*
     * The real cancel. Named cancelAuthenticationRequest, and it lives on the
     * agent rather than the flow - calling it tells the daemon the user
     * declined, which is what releases the waiting application.
     */
    function cancel() {
        if (!active) return false;

        if (typeof agent.cancelAuthenticationRequest === "function") {
            agent.cancelAuthenticationRequest();
            return true;
        }
        if (typeof flow.cancelAuthenticationRequest === "function") {
            flow.cancelAuthenticationRequest();
            return true;
        }
        return false;
    }

    function describe() {
        console.log("bw77 polkit ── registered: " + agent.isRegistered
                  + ", active: " + active
                  + ", cancel on agent: "
                  + (typeof agent.cancelAuthenticationRequest === "function")
                  + ", cancel on flow: "
                  + (active && typeof flow.cancelAuthenticationRequest === "function"));
        if (active) {
            console.log("bw77 polkit ── action: " + actionId
                      + ", identities: " + identities.length
                      + ", responseRequired: " + responseRequired);
        }
    }
}
