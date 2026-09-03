import QtQuick
import qs.Config
import qs.Common

/*
 * Per-widget option editor, driven by a schema rather than a hand-written form
 * per widget. Adding an option to a widget means one line here, not a new pane.
 *
 * Values live inside the widget's own entry in the bar arrays, so two instances
 * of the same widget can be configured independently.
 *
 * A field can instead declare `shared: "<settings group>"`, which reads and
 * writes Settings.<group>.<key> for every instance at once. That exists because
 * some of a widget's settings genuinely are not per-instance - two clocks
 * showing different times would be a bug, not a feature - and the alternative
 * was what this pane used to do: a second heading further down the tab holding
 * the shared half, with nothing on screen to say which block governed what.
 */
Column {
    id: root

    property string section: ""
    property int index: -1
    property var entry: null

    signal changed(string key, var value)

    readonly property var schema: ({
        "activeWindow": [
            { key: "mode", label: Settings.t("Show"), type: "choice", def: "appAndTitle",
              choices: [
                  { value: "appAndTitle", label: Settings.t("App and title") },
                  { value: "appOnly",     label: Settings.t("App only") },
                  { value: "titleOnly",   label: Settings.t("Title only") }
              ] },
            { key: "showIcon", label: Settings.t("App icon"), type: "bool", def: true },
            { key: "maxWidth", label: Settings.t("Maximum width"), type: "int",
              def: 300, min: 120, max: 700, step: 10, suffix: "px" }
        ,
            { key: "colorRole", label: Settings.t("Text colour"), type: "choice", def: "",
              choices: [
                  { value: "",         label: Settings.t("Default") },
                  { value: "text",     label: Settings.t("Text") },
                  { value: "textDim",  label: Settings.t("Dim") },
                  { value: "accent",   label: Settings.t("Accent") },
                  { value: "danger",   label: Settings.t("Crimson") },
                  { value: "warn",     label: Settings.t("Yellow") },
                  { value: "gold",     label: Settings.t("Gold") }
              ] }
        ,
            { key: "borderMode", label: Settings.t("Outline"), type: "choice", def: "inherit",
              choices: [
                  { value: "inherit", label: Settings.t("Default") },
                  { value: "hover",   label: Settings.t("On hover") },
                  { value: "always",  label: Settings.t("Always") },
                  { value: "never",   label: Settings.t("Never") }
              ],
              hint: "Default follows the setting on this tab" }
        ],
        "workspaces": [
            { key: "labelMode", label: Settings.t("Labels"), type: "choice", def: "none",
              choices: [
                  { value: "none",    label: Settings.t("Hide") },
                  { value: "numbers", label: Settings.t("Regular") },
                  { value: "roman",   label: Settings.t("Roman") }
              ] },
            { key: "boldLabels", label: Settings.t("Bold labels"), type: "bool", def: false },
            { key: "scrollToSwitch", label: Settings.t("Scroll to switch"), type: "bool", def: true,
              hint: "Hover the widget and scroll to move between workspaces" },
            { key: "activeScreenOnly", label: Settings.t("This display only"), type: "bool", def: true }
        ,
            { key: "colorRole", label: Settings.t("Text colour"), type: "choice", def: "",
              choices: [
                  { value: "",         label: Settings.t("Default") },
                  { value: "text",     label: Settings.t("Text") },
                  { value: "textDim",  label: Settings.t("Dim") },
                  { value: "accent",   label: Settings.t("Accent") },
                  { value: "danger",   label: Settings.t("Crimson") },
                  { value: "warn",     label: Settings.t("Yellow") },
                  { value: "gold",     label: Settings.t("Gold") }
              ] }
        ,
            { key: "borderMode", label: Settings.t("Outline"), type: "choice", def: "inherit",
              choices: [
                  { value: "inherit", label: Settings.t("Default") },
                  { value: "hover",   label: Settings.t("On hover") },
                  { value: "always",  label: Settings.t("Always") },
                  { value: "never",   label: Settings.t("Never") }
              ],
              hint: "Default follows the setting on this tab" }
        ],
        /*
         * Everything about a clock, in one place.
         *
         * The formats and the appearance used to be two separate blocks on this
         * tab - "CLOCK OPTIONS" for size and colour, and a second "CLOCK"
         * heading further down for the time and date format - which looked like
         * two unrelated features and gave no clue that one was per-widget and
         * the other applied to every clock at once. They are one list now, with
         * the shared ones marked as such in their descriptions.
         *
         * The formats stay shared. Two clocks on the same bar showing different
         * times is not a configuration anyone wants; the appearance keys stay
         * per-widget, because a second clock used as a date readout is.
         */
        "clock": [
            { key: "timeFormat", label: Settings.t("Time"), type: "format", shared: "clock",
              formats: ["HH:mm", "HH:mm:ss", "h:mm AP", "h:mm:ss AP"],
              hint: "Shared by every clock on the bar" },
            { key: "dateFormat", label: Settings.t("Date"), type: "format", shared: "clock",
              formats: ["ddd dd.MM.yyyy", "dd.MM.yyyy", "ddd d MMM", "MMM d yyyy", "yyyy-MM-dd"],
              hint: "Shared by every clock on the bar" },
            { key: "showDate", label: Settings.t("Show date"), type: "bool", shared: "clock",
              hint: "Shared by every clock on the bar" },

            { key: "colorRole", label: Settings.t("Text colour"), type: "choice", def: "",
              choices: [
                  { value: "",         label: Settings.t("Default") },
                  { value: "text",     label: Settings.t("Text") },
                  { value: "textDim",  label: Settings.t("Dim") },
                  { value: "accent",   label: Settings.t("Accent") },
                  { value: "danger",   label: Settings.t("Crimson") },
                  { value: "warn",     label: Settings.t("Yellow") },
                  { value: "gold",     label: Settings.t("Gold") }
              ] },
            { key: "borderMode", label: Settings.t("Outline"), type: "choice", def: "inherit",
              choices: [
                  { value: "inherit", label: Settings.t("Default") },
                  { value: "hover",   label: Settings.t("On hover") },
                  { value: "always",  label: Settings.t("Always") },
                  { value: "never",   label: Settings.t("Never") }
              ],
              hint: "Default follows the setting on this tab" }
        ],
        "keyboardLayout": [
            { key: "showIcon", label: Settings.t("Keyboard icon"), type: "bool", def: true },
            { key: "colorRole", label: Settings.t("Text colour"), type: "choice", def: "",
              choices: [
                  { value: "",         label: Settings.t("Default") },
                  { value: "text",     label: Settings.t("Text") },
                  { value: "textDim",  label: Settings.t("Dim") },
                  { value: "accent",   label: Settings.t("Accent") },
                  { value: "danger",   label: Settings.t("Crimson") },
                  { value: "warn",     label: Settings.t("Yellow") },
                  { value: "gold",     label: Settings.t("Gold") }
              ] }
        ,
            { key: "borderMode", label: Settings.t("Outline"), type: "choice", def: "inherit",
              choices: [
                  { value: "inherit", label: Settings.t("Default") },
                  { value: "hover",   label: Settings.t("On hover") },
                  { value: "always",  label: Settings.t("Always") },
                  { value: "never",   label: Settings.t("Never") }
              ],
              hint: "Default follows the setting on this tab" }
        ],
        "tray": [
            { key: "trayIconSize", label: Settings.t("Icon size"), type: "int",
              shared: "bar", min: 10, max: 32, step: 1, suffix: "px",
              hint: "Tray icons ship at inconsistent sizes; this forces them all to match. Shared by every tray widget." },
            { key: "customTrayMenu", label: Settings.t("Themed menus"), type: "bool",
              shared: "bar",
              hint: "Off uses the application's own Qt or GTK menu, which will not match the shell. Shared." },
            { key: "trayColorize", label: Settings.t("Recolour icons"), type: "bool",
              shared: "bar",
              hint: "Forces every tray icon to a single colour from the palette. Shared." },
            { key: "trayColorRole", label: Settings.t("Icon colour"), type: "choice",
              shared: "bar",
              choices: [
                  { value: "accent",   label: Settings.t("Accent") },
                  { value: "text",     label: Settings.t("Text") },
                  { value: "textDim",  label: Settings.t("Dim") },
                  { value: "danger",   label: Settings.t("Crimson") },
                  { value: "warn",     label: Settings.t("Yellow") },
                  { value: "gold",     label: Settings.t("Gold") }
              ] },

            { key: "scale", label: Settings.t("Icon scale"), type: "real",
              def: 1.0, min: 0.5, max: 2.0, step: 0.05,
              hint: "Multiplies the shared icon size, for this widget only" },
            { key: "borderMode", label: Settings.t("Outline"), type: "choice", def: "inherit",
              choices: [
                  { value: "inherit", label: Settings.t("Default") },
                  { value: "hover",   label: Settings.t("On hover") },
                  { value: "always",  label: Settings.t("Always") },
                  { value: "never",   label: Settings.t("Never") }
              ],
              hint: "Default follows the setting on this tab" }
        ],
        "quickSettings": [
            { key: "borderMode", label: Settings.t("Outline"), type: "choice", def: "inherit",
              choices: [
                  { value: "inherit", label: Settings.t("Default") },
                  { value: "hover",   label: Settings.t("On hover") },
                  { value: "always",  label: Settings.t("Always") },
                  { value: "never",   label: Settings.t("Never") }
              ],
              hint: "Default follows the setting on this tab" },
            { key: "fontSize", label: Settings.t("Icon size"), type: "int",
              def: 0, min: 0, max: 28, step: 1, suffix: "px",
              hint: "0 uses the theme size" }
        ],
        "controlCenter": [
            { key: "borderMode", label: Settings.t("Outline"), type: "choice", def: "inherit",
              choices: [
                  { value: "inherit", label: Settings.t("Default") },
                  { value: "hover",   label: Settings.t("On hover") },
                  { value: "always",  label: Settings.t("Always") },
                  { value: "never",   label: Settings.t("Never") }
              ],
              hint: "Default follows the setting on this tab" }
        ],
        "launcher": [
            { key: "borderMode", label: Settings.t("Outline"), type: "choice", def: "inherit",
              choices: [
                  { value: "inherit", label: Settings.t("Default") },
                  { value: "hover",   label: Settings.t("On hover") },
                  { value: "always",  label: Settings.t("Always") },
                  { value: "never",   label: Settings.t("Never") }
              ],
              hint: "Default follows the setting on this tab" }
        ],
        "session": [
            { key: "borderMode", label: Settings.t("Outline"), type: "choice", def: "inherit",
              choices: [
                  { value: "inherit", label: Settings.t("Default") },
                  { value: "hover",   label: Settings.t("On hover") },
                  { value: "always",  label: Settings.t("Always") },
                  { value: "never",   label: Settings.t("Never") }
              ],
              hint: "Default follows the setting on this tab" }
        ],
        "battery": [
            { key: "borderMode", label: Settings.t("Outline"), type: "choice", def: "inherit",
              choices: [
                  { value: "inherit", label: Settings.t("Default") },
                  { value: "hover",   label: Settings.t("On hover") },
                  { value: "always",  label: Settings.t("Always") },
                  { value: "never",   label: Settings.t("Never") }
              ],
              hint: "Default follows the setting on this tab" },
        ],
        "spacer": [
            { key: "width", label: Settings.t("Width"), type: "int",
              def: 16, min: 4, max: 300, step: 4, suffix: "px" }
        ,
            { key: "borderMode", label: Settings.t("Outline"), type: "choice", def: "inherit",
              choices: [
                  { value: "inherit", label: Settings.t("Default") },
                  { value: "hover",   label: Settings.t("On hover") },
                  { value: "always",  label: Settings.t("Always") },
                  { value: "never",   label: Settings.t("Never") }
              ],
              hint: "Default follows the setting on this tab" }
        ]
    })

    readonly property var fields: {
        if (!entry || !entry.id) return [];
        return schema[entry.id] !== undefined ? schema[entry.id] : [];
    }

    // Shared fields bypass the widget entry in both directions.
    function commit(field, value) {
        if (field.shared !== undefined) {
            Settings[field.shared][field.key] = value;
            return;
        }
        root.changed(field.key, value);
    }

    function valueOf(field) {
        if (field.shared !== undefined) return Settings[field.shared][field.key];
        if (entry && entry[field.key] !== undefined) return entry[field.key];
        return field.def;
    }

    width: parent ? parent.width : 0
    spacing: 1
    visible: fields.length > 0

    SectionHeader {
        width: root.width
        title: root.entry ? `${root.entry.id} options` : ""
        accentColor: Theme.accent
        glitch: false
    }

    Repeater {
        model: root.fields

        SettingRow {
            id: fieldRow
            required property var modelData
            required property int index

            label: modelData.label
            description: modelData.hint !== undefined ? modelData.hint : ""
            alternate: index % 2 === 1

            Loader {
                sourceComponent: {
                    switch (fieldRow.modelData.type) {
                    case "bool":   return boolC;
                    case "choice": return choiceC;
                    case "format": return formatC;
                    case "text":   return textC;
                    default:       return numberC;
                    }
                }

                Component {
                    id: boolC
                    CyberToggle {
                        checked: root.valueOf(fieldRow.modelData) === true
                        onToggled: (v) => root.commit(fieldRow.modelData, v)
                    }
                }

                /*
                 * Choices are a stepper, not a row of buttons.
                 *
                 * The button row printed every option at all times, so "text
                 * colour" was seven labels wide and ran off the pane - and the
                 * selected one had to be found by looking for the filled
                 * background. The stepper shows the choice you have made and
                 * says how many others there are.
                 */
                Component {
                    id: choiceC
                    CyberSelector {
                        width: 220
                        options: fieldRow.modelData.choices.map(c => ({ v: c.value, l: c.label }))
                        current: root.valueOf(fieldRow.modelData)
                        onPicked: (v) => root.commit(fieldRow.modelData, v)
                    }
                }

                /*
                 * Date and time formats.
                 *
                 * Same stepper, but each option is labelled with what that
                 * format looks like right now rather than with the format
                 * string. "HH:mm:ss" tells you nothing at a glance; "14:32:07"
                 * tells you everything.
                 */
                Component {
                    id: formatC
                    CyberSelector {
                        width: 220
                        options: fieldRow.modelData.formats.map(f => ({
                            v: f, l: Qt.formatDateTime(new Date(), f)
                        }))
                        current: root.valueOf(fieldRow.modelData)
                        onPicked: (v) => root.commit(fieldRow.modelData, v)
                    }
                }

                Component {
                    id: numberC
                    CyberSlider {
                        width: 220
                        from: fieldRow.modelData.min
                        to: fieldRow.modelData.max
                        stepSize: fieldRow.modelData.step
                        decimals: fieldRow.modelData.type === "real" ? 2 : 0
                        suffix: fieldRow.modelData.suffix !== undefined
                            ? fieldRow.modelData.suffix : ""
                        value: root.valueOf(fieldRow.modelData)
                        onMoved: (v) => root.commit(fieldRow.modelData, v)
                    }
                }

                Component {
                    id: textC
                    NotchRect {
                        width: 220
                        height: 28
                        fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                        strokeColor: Theme.border
                        notch: 5

                        TextInput {
                            anchors.fill: parent
                            anchors.margins: Theme.space2
                            verticalAlignment: Text.AlignVCenter
                            text: String(root.valueOf(fieldRow.modelData))
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSmall
                            selectionColor: Theme.accent
                            onEditingFinished: root.commit(fieldRow.modelData, text)
                        }
                    }
                }
            }
        }
    }
}
