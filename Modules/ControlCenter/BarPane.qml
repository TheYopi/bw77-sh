import QtQuick
import Quickshell
import qs.Config
import qs.Common

/*
 * Bar layout editor.
 *
 * Widgets are dragged between the three sections and reordered by dropping at a
 * position. Click-to-select still works and drives the options editor below, so
 * the two interactions do not fight: a click selects, a drag moves.
 */
PaneScroll {
    id: pane

    property string selectedSection: ""
    property int selectedIndex: -1

    // Set while a chip is being dragged, so the three scrolling boxes stop
    // treating the drag as a flick of their own content.
    property bool chipDragging: false

    readonly property var available: [
        "controlCenter", "quickSettings", "launcher", "workspaces", "activeWindow", "clock", "sysmon",
        "tray", "volume", "network", "battery", "keyboardLayout", "session", "spacer"
    ]

    readonly property var selectedEntry: {
        if (selectedSection === "" || selectedIndex < 0) return null;
        const list = sectionList(selectedSection);
        return (selectedIndex < list.length) ? list[selectedIndex] : null;
    }

    function sectionList(name) {
        return name === "left" ? Settings.bar.left
             : name === "center" ? Settings.bar.center
             : Settings.bar.right;
    }

    function writeSection(name, list) {
        if (name === "left") Settings.bar.left = list;
        else if (name === "center") Settings.bar.center = list;
        else Settings.bar.right = list;
    }

    // One function for every move, including within a section. Removing before
    // inserting means the target index is computed against the shortened list,
    // which is what makes same-section reordering land where it was dropped.
    function relocate(fromSection, fromIndex, toSection, toIndex) {
        if (fromSection === "" || fromIndex < 0) return;

        const src = sectionList(fromSection).slice();
        if (fromIndex >= src.length) return;
        const item = src.splice(fromIndex, 1)[0];

        if (fromSection === toSection) {
            const clamped = Math.max(0, Math.min(src.length, toIndex));
            src.splice(clamped, 0, item);
            writeSection(fromSection, src);
            pane.selectedSection = toSection;
            pane.selectedIndex = clamped;
            return;
        }

        writeSection(fromSection, src);
        const dst = sectionList(toSection).slice();
        const clamped = Math.max(0, Math.min(dst.length, toIndex));
        dst.splice(clamped, 0, item);
        writeSection(toSection, dst);
        pane.selectedSection = toSection;
        pane.selectedIndex = clamped;
    }

    function reorder(section, index, delta) {
        relocate(section, index, section, index + delta);
    }

    function remove(section, index) {
        const list = sectionList(section).slice();
        list.splice(index, 1);
        writeSection(section, list);
        pane.selectedSection = "";
        pane.selectedIndex = -1;
    }

    function add(section, id) {
        const list = sectionList(section).slice();
        list.push({ id: id });
        writeSection(section, list);
        pane.selectedSection = section;
        pane.selectedIndex = list.length - 1;
    }

    function setOption(key, value) {
        if (selectedSection === "" || selectedIndex < 0) return;
        const list = sectionList(selectedSection).slice();
        const updated = Object.assign({}, list[selectedIndex]);
        updated[key] = value;
        list[selectedIndex] = updated;
        writeSection(selectedSection, list);
    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Top bar")
        subtitle: Settings.t("Drag widgets between sections to move them, click to configure")
        expanded: true


        SettingRow {
            label: Settings.t("Position")
            CyberButton {
                text: Settings.bar.position === "top" ? "Top" : "Bottom"
                onClicked: Settings.bar.position =
                    Settings.bar.position === "top" ? "bottom" : "top"
            }
        }

        SettingRow {
            label: Settings.t("Style")
            description: Settings.t("Attached sits flush against the screen edge; floating is a detached block")
            CyberSelector {
                options: [{ v: "attached", l: Settings.t("Attached") }, { v: "floating", l: Settings.t("Floating") }]
                current: Settings.bar.style
                onPicked: (v) => Settings.bar.style = v
            }
        }

        SettingRow {
            visible: Settings.bar.style === "floating"
            label: Settings.t("Side margin")
            CyberSlider {
                width: 240
                from: 0; to: 200; stepSize: 4
                value: Settings.bar.marginH
                suffix: "px"
                onMoved: (v) => Settings.bar.marginH = v
            }
        }

        SettingRow {
            visible: Settings.bar.style === "floating"
            label: Settings.t("Edge margin")
            alternate: true
            CyberSlider {
                width: 240
                from: 0; to: 60; stepSize: 2
                value: Settings.bar.marginV
                suffix: "px"
                onMoved: (v) => Settings.bar.marginV = v
            }
        }

        SettingRow {
            visible: Settings.bar.style === "floating"
            label: Settings.t("Block width")
            description: Settings.t("0 fills the space left by the side margins")
            CyberSlider {
                width: 240
                from: 0; to: 3000; stepSize: 20
                value: Settings.bar.floatingWidth
                suffix: "px"
                onMoved: (v) => Settings.bar.floatingWidth = v
            }
        }

        SettingRow {
            visible: Settings.bar.style === "floating"
            label: Settings.t("Corner cut")
            alternate: true
            CyberSlider {
                width: 240
                from: 0; to: 24; stepSize: 1
                value: Settings.bar.notch
                suffix: "px"
                onMoved: (v) => Settings.bar.notch = v
            }
        }

        SettingRow {
            label: Settings.t("Height")
            alternate: true
            CyberSlider {
                width: 240
                from: 22; to: 60; stepSize: 1
                value: Settings.bar.height
                suffix: "px"
                onMoved: (v) => Settings.bar.height = v
            }
        }

        SettingRow {
            label: Settings.t("Text size")
            description: Settings.t("Every widget on the bar. Zero follows the base text size from Theme")
            CyberSlider {
                width: 240
                from: 0; to: 24; stepSize: 1
                value: Settings.bar.fontSize
                suffix: "px"
                onMoved: (v) => Settings.bar.fontSize = v
            }
        }

        SettingRow {
            label: Settings.t("Text weight")
            description: Settings.t("Workspace numbers stay a step heavier than this")
            alternate: true
            CyberSlider {
                width: 240
                // Qt's weight scale. Stepping by 100 keeps the slider on the named
                // weights rather than on values between them, which a font can
                // only round to anyway.
                from: 200; to: 900; stepSize: 100
                value: Settings.bar.fontWeight
                onMoved: (v) => Settings.bar.fontWeight = v
            }
        }


        SettingRow {
            label: Settings.t("Reserve space")
            description: Settings.t("Windows avoid the bar instead of drawing underneath it")
            alternate: true
            CyberToggle {
                checked: Settings.bar.exclusive
                onToggled: (v) => Settings.bar.exclusive = v
            }
        }

        CyberText {
            width: pane.innerWidth
            text: "The edge decoration is shared with the quick settings panel and the dock. "
                + "It lives under Overview."
            role: "micro"
            caps: false
            color: Theme.textMuted
            wrapMode: Text.Wrap
        }

    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Widget outlines")
        accentColor: Theme.accent
        glitch: false
        expanded: false


        SettingRow {
            label: Settings.t("Show outlines")
            description: Settings.t("Always keeps them visible at reduced opacity and goes solid on hover")
            CyberSelector {
                options: [{ v: "hover", l: Settings.t("On hover") }, { v: "always", l: Settings.t("Always") },
                { v: "never", l: Settings.t("Never") }]
                current: Settings.bar.widgetBorders
                onPicked: (v) => Settings.bar.widgetBorders = v
            }
        }

        SettingRow {
            visible: Settings.bar.widgetBorders === "always"
            label: Settings.t("Resting opacity")
            description: Settings.t("Hovering always goes fully opaque")
            alternate: true
            CyberSlider {
                width: 240
                from: 0.05; to: 1.0; stepSize: 0.05
                decimals: 2
                value: Settings.bar.widgetBorderOpacity
                onMoved: (v) => Settings.bar.widgetBorderOpacity = v
            }
        }

    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Widget spacing")
        accentColor: Theme.accent
        glitch: false
        expanded: false


        SettingRow {
            label: Settings.t("Gap between widgets")
            CyberSlider {
                width: 240
                from: 0; to: 32; stepSize: 1
                value: Settings.bar.widgetSpacing
                suffix: "px"
                onMoved: (v) => Settings.bar.widgetSpacing = v
            }
        }

        SettingRow {
            label: Settings.t("Padding inside widgets")
            alternate: true
            CyberSlider {
                width: 240
                from: 0; to: 24; stepSize: 1
                value: Settings.bar.widgetPadding
                suffix: "px"
                onMoved: (v) => Settings.bar.widgetPadding = v
            }
        }

        SettingRow {
            label: Settings.t("Edge padding")
            description: Settings.t("Space between the screen edge and the first widget")
            CyberSlider {
                width: 240
                from: 0; to: 40; stepSize: 2
                value: Settings.bar.sectionPadding
                suffix: "px"
                onMoved: (v) => Settings.bar.sectionPadding = v
            }
        }

        // --- section editor
        Row {
            width: pane.innerWidth
            height: 300
            spacing: Theme.space3

            Repeater {
                model: [
                    { key: "left",   label: Settings.t("Left") },
                    { key: "center", label: Settings.t("Center") },
                    { key: "right",  label: Settings.t("Right") }
                ]

                Panel {
                    id: sectionPanel
                    required property var modelData
                    readonly property string key: modelData.key

                    width: (pane.innerWidth - Theme.space3 * 2) / 3
                    height: 300
                    emphasis: dropArea.containsDrag ? "alert" : "quiet"
                    serial: false
                    scanlines: false
                    padding: Theme.space2

                    CyberText {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        text: sectionPanel.modelData.label
                        role: "label"
                        color: dropArea.containsDrag ? Theme.accent : Theme.danger
                    }

                    DropArea {
                        id: dropArea
                        anchors.fill: parent
                        anchors.topMargin: 22

                        /*
                         * Index is derived from where the cursor is, so dropping
                         * between two chips inserts there rather than appending.
                         *
                         * Offset by the scroll position: the drop area is the fixed
                         * viewport while the chips move underneath it, so `drag.y`
                         * alone answers "how far down the box" when the question is
                         * "how far down the list".
                         */
                        readonly property int dropIndex: {
                            const count = pane.sectionList(sectionPanel.key).length;
                            if (!containsDrag) return count;
                            return Math.max(0, Math.min(count,
                                Math.round((drag.y + chipScroll.contentY) / 28)));
                        }

                        onDropped: (drop) => {
                            const src = drop.source;
                            if (!src || src.sourceSection === undefined) {
                                drop.accepted = false;
                                return;
                            }
                            pane.relocate(src.sourceSection, src.sourceIndex,
                                          sectionPanel.key, dropIndex);
                            drop.accept();
                        }

                        // Insertion caret. Drawn in viewport coordinates, so it
                        // tracks the cursor rather than the list under it.
                        Rectangle {
                            visible: dropArea.containsDrag
                            width: parent.width
                            height: 2
                            color: Theme.accent
                            y: dropArea.dropIndex * 28 - chipScroll.contentY
                        }
                    }

                    /*
                     * The chip list scrolls.
                     *
                     * The box is a fixed 300px and the widget list is not: eleven
                     * widgets in one section is about where the column ran past the
                     * bottom edge, and because a Panel does not clip, the overflow
                     * drew straight over the section below it rather than being cut
                     * off - so it was not even obvious that anything was wrong,
                     * just that the pane had gone strange.
                     */
                    Flickable {
                        id: chipScroll

                        anchors.top: parent.top
                        anchors.topMargin: 22
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom

                        clip: true
                        contentWidth: width
                        contentHeight: chipColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        // A chip being dragged out of the list must not also drag
                        // the list, or pulling one towards a neighbouring section
                        // scrolls this one instead.
                        interactive: !pane.chipDragging

                        Column {
                            id: chipColumn
                            width: chipScroll.width
                            spacing: 2

                        Repeater {
                            model: pane.sectionList(sectionPanel.key)

                            Item {
                                id: chip
                                required property var modelData
                                required property int index

                                // Read by the DropArea to know what is being moved.
                                property string sourceSection: sectionPanel.key
                                property int sourceIndex: index

                                readonly property bool selected:
                                    pane.selectedSection === sectionPanel.key
                                    && pane.selectedIndex === index

                                width: chipColumn.width - 5   // clear of the scrollbar
                                height: 26

                                Drag.active: dragHandle.drag.active
                                Drag.source: chip
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                // Lift out of the Column while dragging so the chip
                                // follows the cursor instead of being re-laid out.
                                states: State {
                                    when: chip.Drag.active
                                    ParentChange { target: chip; parent: pane }
                                    AnchorChanges {
                                        target: chip
                                        anchors.horizontalCenter: undefined
                                        anchors.verticalCenter: undefined
                                    }
                                }

                                NotchRect {
                                    anchors.fill: parent
                                    fillColor: chip.selected ? Theme.alpha(Theme.accent, 0.25)
                                        : (chip.Drag.active ? Theme.alpha(Theme.accent, 0.4)
                                                            : Theme.alpha(Theme.bgDeep, 0.6))
                                    strokeColor: chip.selected || chip.Drag.active
                                        ? Theme.accent : Theme.border
                                    notch: 5
                                }

                                CyberText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.space2
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.modelData.id
                                    role: "micro"
                                    color: chip.selected ? Theme.accent : Theme.textDim
                                }

                                MouseArea {
                                    id: dragHandle
                                    anchors.fill: parent
                                    cursorShape: drag.active ? Qt.ClosedHandCursor
                                                             : Qt.PointingHandCursor
                                    drag.target: chip
                                    drag.smoothed: false

                                    onPressed: {
                                        pane.selectedSection = sectionPanel.key;
                                        pane.selectedIndex = chip.index;
                                        pane.chipDragging = true;
                                    }

                                    onReleased: {
                                        pane.chipDragging = false;
                                        if (chip.Drag.active) chip.Drag.drop();
                                    }

                                    onCanceled: pane.chipDragging = false
                                }

                                // Controls sit above the drag handle, declared after
                                // it so their clicks are not swallowed.
                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.space1
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3
                                    visible: chip.selected && !chip.Drag.active

                                    Repeater {
                                        model: [
                                            { glyph: "\u25B2", act: "up",     danger: false },
                                            { glyph: "\u25BC", act: "down",   danger: false },
                                            { glyph: "\u2715", act: "remove", danger: true  }
                                        ]

                                        CyberText {
                                            required property var modelData
                                            text: modelData.glyph
                                            role: "icon"
                                            color: modelData.danger ? Theme.danger : Theme.accent

                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const key = sectionPanel.key;
                                                    if (modelData.act === "up")
                                                        pane.reorder(key, chip.index, -1);
                                                    else if (modelData.act === "down")
                                                        pane.reorder(key, chip.index, 1);
                                                    else
                                                        pane.remove(key, chip.index);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        }

                        // Same crimson bar as the settings panes. `parent` is the
                        // Flickable, not its content, or it would scroll itself.
                        Rectangle {
                            parent: chipScroll
                            x: chipScroll.width - width
                            y: chipScroll.contentHeight > 0
                                ? chipScroll.visibleArea.yPosition * chipScroll.height : 0
                            width: 3
                            height: Math.max(20, chipScroll.visibleArea.heightRatio * chipScroll.height)
                            color: Theme.alpha(Theme.danger, 0.85)
                            visible: chipScroll.contentHeight > chipScroll.height
                        }
                    }
                }
            }
        }

        // --- per-widget options for whatever is selected
        WidgetOptions {
            width: pane.innerWidth
            section: pane.selectedSection
            index: pane.selectedIndex
            entry: pane.selectedEntry
            onChanged: (key, value) => pane.setOption(key, value)
        }

    }

    PaneGroup {
        width: pane.innerWidth
        title: Settings.t("Add a widget")
        subtitle: pane.selectedSection !== ""
        ? `Adds to the ${pane.selectedSection} section`
        : "Adds to the right section; select a widget first to choose another"
        accentColor: Theme.accent
        glitch: false
        expanded: false


        Flow {
            width: pane.innerWidth
            spacing: Theme.space2

            Repeater {
                model: pane.available
                CyberButton {
                    required property string modelData
                    text: modelData
                    hPadding: Theme.space3
                    onClicked: pane.add(
                        pane.selectedSection !== "" ? pane.selectedSection : "right",
                        modelData)
                }
            }
        }

        /*
         * The Tray and Clock blocks used to live here.
         *
         * They were shared settings shown under their own headings while the
         * matching widget was selected, which put a widget's configuration in two
         * places on the same tab with nothing to say which was which. Both sets are
         * fields in the per-widget options above now, marked in their descriptions
         * as shared; see WidgetOptions.
         */
    }
}
