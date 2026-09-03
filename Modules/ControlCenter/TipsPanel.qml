import QtQuick
import qs.Config
import qs.Common

/*
 * The description column on the right.
 *
 * Descriptions used to print under every label, which meant a pane was mostly
 * explanation - forty paragraphs of it, on screen at once, for the one setting
 * anybody was actually reading. Moving them here trades "always visible" for
 * "visible when it is yours", and the settings list halves in height as a side
 * effect.
 *
 * It stays mounted with nothing in it rather than appearing and disappearing:
 * a column that comes and goes would resize the settings list underneath it
 * every time the pointer crossed a row.
 */
Item {
    id: root

    // Left rule, running the full height. This is the boundary between "the
    // controls" and "the commentary", and it should hold whether or not there
    // is any commentary right now.
    Rectangle {
        id: rule
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha(Theme.border, 0.15) }
            GradientStop { position: 0.5; color: Theme.alpha(Theme.border, 0.9) }
            GradientStop { position: 1.0; color: Theme.alpha(Theme.border, 0.15) }
        }
    }

    // The lit portion of the rule tracks the tip, so the eye is told where the
    // panel's content came from without a connecting line across the gap.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: Theme.space5
        width: 2
        height: CcNav.hasTip ? Theme.space6 * 2 : 0
        color: CcNav.keyboardMode ? Theme.accent : Theme.danger

        Behavior on height { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easeSnap } }
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    Column {
        id: body

        anchors.left: rule.right
        anchors.leftMargin: Theme.space5
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.space5
        spacing: Theme.space3

        opacity: CcNav.hasTip ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

        CyberText {
            width: parent.width
            text: CcNav.tipTitle
            role: "label"
            color: Theme.accent
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }

        CyberText {
            width: parent.width
            visible: CcNav.tipBody !== ""
            text: CcNav.tipBody
            role: "body"
            caps: false
            color: Theme.textDim
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            lineHeight: 1.25
        }

        /*
         * What the arrows will do to this particular control.
         *
         * Printed per-kind rather than as one fixed legend at the bottom of the
         * screen, because the answer genuinely differs: left and right set a
         * toggle, walk a stepper, nudge a slider, and on a font row do nothing
         * useful at all until you press Enter.
         */
        Item {
            width: parent.width
            height: hintRow.implicitHeight
            visible: CcNav.keyboardMode && hintText.text !== ""

            Row {
                id: hintRow
                spacing: Theme.space2

                KeyChip {
                    anchors.verticalCenter: parent.verticalCenter
                    text: CcNav.tipKind === "picker" ? "\u21B5" : "\u2190 \u2192"
                }

                CyberText {
                    id: hintText
                    anchors.verticalCenter: parent.verticalCenter
                    role: "micro"
                    color: Theme.textMuted
                    text: {
                        switch (CcNav.tipKind) {
                        case "toggle":   return Settings.t("Off and on");
                        case "selector": return Settings.t("Previous and next");
                        case "slider":   return Settings.t("Lower and raise");
                        case "picker":   return Settings.t("Open the list");
                        default:         return "";
                        }
                    }
                }
            }
        }
    }

    // Resting state. Not a paragraph of instructions - just enough to say the
    // column is not broken, and it is gone the moment anything is focused.
    CyberText {
        anchors.left: rule.right
        anchors.leftMargin: Theme.space5
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.space5
        visible: !CcNav.hasTip
        text: Settings.t("Select a setting to read about it")
        role: "micro"
        caps: false
        color: Theme.alpha(Theme.textMuted, 0.7)
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
}
