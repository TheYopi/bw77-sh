import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * Colour picker, in the shape of the game's tuning panels.
 *
 * Its own layer-shell surface, above the Control Center's.
 *
 * It began as an Item overlay inside the Control Center window and would not
 * draw - `ipc call theme pickerState` reported it open while the screen showed
 * nothing, both as a direct child of the PanelWindow and as a child of the
 * card. Rather than keep guessing at why, this uses the mechanism every working
 * popup in the shell already uses: a PanelWindow of its own, held by a
 * LazyLoader in shell.qml, exactly like the dock menu and the launcher.
 *
 * No dimming - the Control Center stays fully legible underneath - so the mask
 * is the card alone. Everything outside it belongs to whatever is below.
 *
 * HSV is the canonical state rather than RGB. Going the other way loses
 * information: every shade of grey has the same undefined hue, so storing RGB
 * and deriving HSV makes the hue slider snap to zero the moment saturation
 * reaches it, and you cannot get back out again. Holding h/s/v and deriving
 * RGB means the hue survives a trip through black, white or grey.
 */
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bw77-colorpicker"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Only the card takes input; clicks elsewhere reach the Control Center.
    mask: Region { item: card }

    Component.onCompleted: Shell.colorPickerSurfaceAlive = true
    Component.onDestruction: Shell.colorPickerSurfaceAlive = false

    // --- canonical state
    property real hh: 0      // 0..1
    property real ss: 0      // 0..1
    property real vv: 0      // 0..1

    property bool hsvMode: false

    readonly property color current: Qt.hsva(root.hh, root.ss, root.vv, 1)
    readonly property string hex: {
        const r = Math.round(root.current.r * 255);
        const g = Math.round(root.current.g * 255);
        const b = Math.round(root.current.b * 255);
        return "#" + [r, g, b].map(n => n.toString(16).padStart(2, "0")).join("").toUpperCase();
    }

    // Coercion target: assigning a "#rrggbb" string to a typed colour property
    // parses it, which a plain function argument would not do.
    property color scratch: "#000000"

    function loadFrom(value) {
        root.scratch = value;
        // hsvHue is -1 for anything achromatic; keep whatever hue was showing
        // rather than yanking the slider to red.
        root.hh = root.scratch.hsvHue >= 0 ? root.scratch.hsvHue : root.hh;
        root.ss = root.scratch.hsvSaturation;
        root.vv = root.scratch.hsvValue;
    }

    function setRgb(r, g, b) {
        const c = Qt.rgba(r / 255, g / 255, b / 255, 1);
        root.loadFrom(c);
    }

    Connections {
        target: Shell
        function onColorPickerOpenChanged() {
            if (Shell.colorPickerOpen) root.loadFrom(Shell.colorPickerInitial);
        }
    }

    Panel {
        id: card

        anchors.centerIn: parent
        width: 380

        /*
         * Floored, not purely derived.
         *
         * A Column's implicitHeight is the sum of its children, and any one of
         * them resolving to zero - a component that fails to load, a binding
         * Qt breaks as a loop - takes the whole card down with it and leaves a
         * sliver that reads as "the picker never opened". The floor means a
         * broken row costs you that row, not the window.
         */
        height: Math.max(360, body.implicitHeight + Theme.space5 * 2 + serialRoom)
        readonly property int serialRoom: 14

        fillColor: Theme.bgBase
        fillOpacity: 0.98
        emphasis: "alert"
        serialSeed: "colorpicker"
        padding: Theme.space5

        Column {
            id: body
            width: parent.width
            spacing: Theme.space3

            SectionHeader {
                width: parent.width
                title: Shell.colorPickerTitle || "Colour"
                subtitle: root.hsvMode ? "Hue, saturation, value" : "Red, green, blue"
                accentColor: Theme.danger
            }

            // --- before / after
            Row {
                width: parent.width
                height: 46
                spacing: Theme.space2

                Column {
                    width: (parent.width - Theme.space2) / 2
                    spacing: 2

                    CyberText { text: Settings.t("Was"); role: "micro"; color: Theme.textMuted }

                    NotchRect {
                        width: parent.width
                        height: 28
                        fillColor: Shell.colorPickerInitial
                        strokeColor: Theme.alpha(Theme.text, 0.3)
                        notch: 5

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            // Handy while comparing: one click puts it back.
                            onClicked: root.loadFrom(Shell.colorPickerInitial)
                        }
                    }
                }

                Column {
                    width: (parent.width - Theme.space2) / 2
                    spacing: 2

                    CyberText { text: Settings.t("Now"); role: "micro"; color: Theme.textMuted }

                    NotchRect {
                        width: parent.width
                        height: 28
                        fillColor: root.current
                        strokeColor: Theme.accent
                        notch: 5
                    }
                }
            }

            // --- mode switch
            CyberSelector {
                options: [{ v: false, l: "RGB" }, { v: true, l: "HSV" }]
                current: root.hsvMode
                onPicked: (v) => root.hsvMode = v
            }

            // --- channels
            Repeater {
                model: root.hsvMode
                    ? [{ k: "h", l: Settings.t("Hue"),        max: 360, suffix: "\u00B0" },
                       { k: "s", l: Settings.t("Saturation"), max: 100, suffix: "%" },
                       { k: "v", l: Settings.t("Value"),      max: 100, suffix: "%" }]
                    : [{ k: "r", l: Settings.t("Red"),   max: 255, suffix: "" },
                       { k: "g", l: Settings.t("Green"), max: 255, suffix: "" },
                       { k: "b", l: Settings.t("Blue"),  max: 255, suffix: "" }]

                Row {
                    id: chan
                    required property var modelData
                    width: body.width
                    spacing: Theme.space3

                    readonly property real channelValue: {
                        switch (chan.modelData.k) {
                        case "h": return Math.round(root.hh * 360);
                        case "s": return Math.round(root.ss * 100);
                        case "v": return Math.round(root.vv * 100);
                        case "r": return Math.round(root.current.r * 255);
                        case "g": return Math.round(root.current.g * 255);
                        default:  return Math.round(root.current.b * 255);
                        }
                    }

                    // The bar takes the colour of the channel it drives, so the
                    // three rows are distinguishable at a glance.
                    readonly property color channelColor: {
                        switch (chan.modelData.k) {
                        case "r": return "#ff4444";
                        case "g": return "#44ff88";
                        case "b": return "#4488ff";
                        case "h": return Qt.hsva(root.hh, 1, 1, 1);
                        default:  return root.current;
                        }
                    }

                    CyberText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 74
                        text: chan.modelData.l
                        role: "label"
                        color: Theme.textDim
                    }

                    CyberSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 74 - Theme.space3
                        from: 0
                        to: chan.modelData.max
                        stepSize: 1
                        suffix: chan.modelData.suffix
                        barColor: chan.channelColor
                        value: chan.channelValue

                        onMoved: (v) => {
                            const c = root.current;
                            switch (chan.modelData.k) {
                            case "h": root.hh = v / 360; break;
                            case "s": root.ss = v / 100; break;
                            case "v": root.vv = v / 100; break;
                            case "r": root.setRgb(v, c.g * 255, c.b * 255); break;
                            case "g": root.setRgb(c.r * 255, v, c.b * 255); break;
                            case "b": root.setRgb(c.r * 255, c.g * 255, v); break;
                            }
                        }
                    }
                }
            }

            // --- hex
            Row {
                width: parent.width
                spacing: Theme.space3

                CyberText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 74
                    text: Settings.t("Hex")
                    role: "label"
                    color: Theme.textDim
                }

                NotchRect {
                    width: 120
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                    strokeColor: Theme.border
                    notch: 5

                    TextInput {
                        id: hexInput
                        anchors.fill: parent
                        anchors.margins: Theme.space2
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSmall
                        selectionColor: Theme.accent
                        maximumLength: 7

                        /*
                         * Pushed in rather than bound. Editing a TextInput
                         * breaks any binding on `text` permanently, so a bound
                         * field would track the sliders until the first
                         * keystroke and then quietly stop.
                         */
                        Component.onCompleted: text = root.hex

                        onTextChanged: {
                            if (!activeFocus) return;
                            if (/^#[0-9A-Fa-f]{6}$/.test(text)) root.loadFrom(text);
                        }

                        Connections {
                            target: root
                            function onHexChanged() {
                                if (!hexInput.activeFocus) hexInput.text = root.hex;
                            }
                        }
                    }
                }
            }

            // --- actions
            Item {
                width: parent.width
                height: actions.implicitHeight

            Row {
                id: actions
                x: parent.width - width
                spacing: Theme.space2

                CyberButton {
                    visible: Shell.colorPickerResettable
                    text: Settings.t("Reset")
                    onClicked: Shell.resetColor()
                }

                CyberButton {
                    text: Settings.t("Cancel")
                    onClicked: Shell.closeColorPicker()
                }

                CyberButton {
                    text: Settings.t("Apply")
                    destructive: true
                    onClicked: Shell.applyColor(root.hex)
                }
            }
            }
        }
    }

    // The picker must not outlive the surface it was opened from.
    Connections {
        target: Shell
        function onControlCenterOpenChanged() {
            if (!Shell.controlCenterOpen) Shell.closeColorPicker();
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Shell.closeColorPicker()
    }
}
