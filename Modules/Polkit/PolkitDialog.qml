import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Config
import qs.Common
import qs.Services

/*
 * Authentication prompt for privileged actions.
 *
 * Styled as a peer of the Control Center and session menu - same Panel, same
 * SectionHeader, same dimmed backdrop - and the password field behaves like the
 * lock screen's, because it is the same interaction.
 *
 * Deliberately NOT dismissable by clicking the backdrop or pressing Escape
 * without going through cancel(): the daemon is waiting on an answer, and a
 * dialog that vanishes without one leaves the requesting application hanging.
 */
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bw77-polkit"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    property string password: ""

    // A fresh request means a fresh field, and a failed attempt clears it.
    readonly property string requestKey: Polkit.actionId + "|" + Polkit.message
    onRequestKeyChanged: password = ""

    Connections {
        target: Polkit
        function onSupplementaryIsErrorChanged() {
            if (Polkit.supplementaryIsError) root.password = "";
        }
    }

    function authenticate() {
        if (!Polkit.responseRequired) return;
        Polkit.submit(password);
        password = "";
    }

    function dismiss() {
        password = "";
        // Tells the daemon the user declined. The flow ends as a result and
        // this window closes on its own.
        Polkit.cancel();
    }

    /*
     * Still a barrier, no longer a scrim.
     *
     * It swallows clicks without dismissing - an authentication request needs
     * an explicit answer, so clicking away must not count as one - but it no
     * longer paints over the screen.
     *
     * Worth knowing what that costs: on every other surface the dimming was
     * decoration, and here it was doing a job. It said "this is modal, the rest
     * of the screen is not accepting input", which is now something you find
     * out by clicking and having nothing happen. The dialog is opaque and
     * bordered so it still reads as a prompt; restoring the fill is one line if
     * that turns out to matter.
     */
    MouseArea {
        anchors.fill: parent
    }

    // No full-screen scanlines either, for the same reason as the fill: with
    // nothing behind them they would be a grid of lines drawn over your live
    // windows. The dialog draws its own through Panel.

    GlitchBox {
        category: "menus"
        anchors.fill: parent
        shown: Polkit.active

        Panel {
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width - 120, 560)
            height: content.implicitHeight + Theme.space5 * 2

            fillColor: Theme.bgBase
            fillOpacity: 0.96
            serialSeed: "polkit"
            padding: Theme.space5

            Column {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Theme.space3

                SectionHeader {
                    width: parent.width
                    title: Settings.t("Authentication required")
                    subtitle: Polkit.selectedIdentity
                        ? Polkit.identityName(Polkit.selectedIdentity)
                        : Quickshell.env("USER")
                    accentColor: Theme.danger
                }

                // --- what is being asked for
                Row {
                    width: parent.width
                    spacing: Theme.space3

                    IconImage {
                        id: actionIcon
                        visible: Polkit.iconName !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 36
                        source: Polkit.iconName
                            ? Quickshell.iconPath(Polkit.iconName, true) : ""
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (actionIcon.visible ? 36 + Theme.space3 : 0)
                        spacing: 2

                        CyberText {
                            width: parent.width
                            text: Polkit.message !== ""
                                ? Polkit.message
                                : "An application is requesting elevated privileges"
                            role: "body"
                            caps: false
                            color: Theme.text
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        // The action id is the precise thing being authorised,
                        // which the prose message often only gestures at.
                        CyberText {
                            width: parent.width
                            visible: Polkit.actionId !== ""
                            text: Polkit.actionId
                            role: "micro"
                            caps: false
                            color: Theme.textMuted
                            elide: Text.ElideMiddle
                        }
                    }
                }

                /*
                 * --- who is authenticating
                 *
                 * Shown only when the action permits more than one user. Some
                 * actions are grantable by root but not by the account at the
                 * keyboard, and typing the wrong user's password repeatedly
                 * with no explanation is a miserable way to discover that.
                 */
                Column {
                    width: parent.width
                    visible: Polkit.identities.length > 1
                    spacing: Theme.space1

                    CyberText {
                        text: Settings.t("Authenticate as")
                        role: "micro"
                        color: Theme.textMuted
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.space1

                        Repeater {
                            model: Polkit.identities

                            CyberButton {
                                required property var modelData
                                text: Polkit.identityName(modelData)
                                hPadding: Theme.space3
                                active: modelData === Polkit.selectedIdentity
                                onClicked: Polkit.selectIdentity(modelData)
                            }
                        }
                    }
                }

                // --- password
                NotchRect {
                    width: parent.width
                    height: 40
                    visible: Polkit.responseRequired

                    fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                    strokeColor: Polkit.supplementaryIsError
                        ? Theme.danger
                        : (input.activeFocus ? Theme.accent : Theme.border)
                    notch: Theme.notchSmall

                    Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }

                    CyberText {
                        id: promptGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space3
                        height: parent.height
                        text: "\uf023"
                        role: "icon"
                        color: Theme.danger
                    }

                    TextInput {
                        id: input
                        anchors.left: promptGlyph.right
                        anchors.leftMargin: Theme.space2
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space3
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter

                        focus: true
                        // The daemon says whether the reply is a secret; a
                        // one-time code prompt is not, and hiding it would be
                        // actively unhelpful.
                        echoMode: Polkit.responseVisible
                            ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "\u25AC"

                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontBase
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.textOnAccent

                        text: root.password
                        onTextChanged: root.password = text
                        onAccepted: root.authenticate()

                        CyberText {
                            visible: input.text === ""
                            text: Polkit.prompt !== "" ? Polkit.prompt : "Password"
                            role: "body"
                            caps: false
                            color: Theme.textMuted
                        }
                    }
                }

                // --- status line
                CyberText {
                    width: parent.width
                    visible: Polkit.supplementary !== "" || Polkit.conflicted
                    // Only a confirmed conflict is reported as one. A request
                    // arriving at all proves registration worked, whatever the
                    // registered property happens to say.
                    text: Polkit.conflicted
                        ? "Another authentication agent is already running"
                        : Polkit.supplementary
                    role: "micro"
                    caps: false
                    color: Polkit.supplementaryIsError || Polkit.conflicted
                        ? Theme.textDanger : Theme.textMuted
                    wrapMode: Text.Wrap
                }

                // --- actions
                Row {
                    anchors.right: parent.right
                    spacing: Theme.space2

                    CyberButton {
                        text: Settings.t("Cancel")
                        keyHint: "ESC"
                        destructive: true
                        onClicked: root.dismiss()
                    }

                    CyberButton {
                        text: Settings.t("Authenticate")
                        keyHint: "\u21B5"
                        active: root.password !== ""
                        enabled: Polkit.responseRequired
                        onClicked: root.authenticate()
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: true

        // Escape cancels the request properly rather than just hiding the
        // dialog, so the waiting application gets its answer.
        Keys.onEscapePressed: root.dismiss()
    }
}
