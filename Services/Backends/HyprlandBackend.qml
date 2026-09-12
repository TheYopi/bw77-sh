import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/* Hyprland has a first-class Quickshell module, so this is mostly a shape adapter. */
Item {
    id: root

    property var workspaces: []
    property int focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    property string keyboardLayout: ""
    property var keyboardLayouts: []
    // No overview to report; see NiriBackend.
    property bool overviewOpen: false

    function focusWorkspace(ws) {
        // Hyprland does address workspaces by id.
        if (ws) Hyprland.dispatch(`workspace ${ws.id}`);
    }

    function cycleKeyboardLayout() {
        Hyprland.dispatch("switchxkblayout current next");
        layoutQuery.running = true;
    }

    function rebuild() {
        const out = [];
        for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
            const w = Hyprland.workspaces.values[i];
            out.push({
                id: w.id,
                name: w.name,
                index: w.id,
                focused: w.focused,
                active: w.active,
                occupied: w.toplevels ? w.toplevels.values.length > 0 : false,
                output: w.monitor ? w.monitor.name : ""
            });
        }
        out.sort((a, b) => a.index - b.index);
        root.workspaces = out;
    }

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { root.rebuild(); }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const parts = event.data.split(",");
                root.keyboardLayout = parts.length > 1 ? parts[1] : "";
            } else if (event.name.startsWith("workspace") || event.name === "createworkspace"
                       || event.name === "destroyworkspace") {
                root.rebuild();
            }
        }
    }

    Component.onCompleted: {
        rebuild();
        layoutQuery.running = true;
    }

    Process {
        id: layoutQuery
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const kb = d.keyboards.find(k => k.main) || d.keyboards[0];
                    if (kb) {
                        root.keyboardLayout = kb.active_keymap;
                        root.keyboardLayouts = String(kb.layout).split(",");
                    }
                } catch (e) {}
            }
        }
    }
}
