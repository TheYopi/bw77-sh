import QtQuick
import Quickshell
import Quickshell.Io

/*
 * niri exposes a line-delimited JSON event stream. One long-lived process gives
 * push updates for workspaces and keyboard layout without polling.
 */
Item {
    id: root

    property var workspaces: []
    property int focusedWorkspaceId: -1
    property string keyboardLayout: ""
    property var keyboardLayouts: []
    property int layoutIndex: 0

    function focusWorkspace(ws) {
        if (!ws) return;
        // `focus-workspace` accepts an index or a name, never the internal id.
        // A named workspace is addressed by name; otherwise by its index.
        const named = ws.name && isNaN(Number(ws.name));
        const key = named ? String(ws.name) : String(ws.index);
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", key]);
    }

    function cycleKeyboardLayout() {
        Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
    }

    function rebuild(list) {
        // niri reports workspaces per output with its own idx; normalise to the
        // shape the bar widget expects.
        const out = list.map(w => ({
            id: w.id,
            name: w.name || String(w.idx),
            index: w.idx,
            focused: !!w.is_focused,
            active: !!w.is_active,
            occupied: !!w.active_window_id,
            output: w.output || ""
        })).sort((a, b) => a.index - b.index);

        root.workspaces = out;
        const f = out.find(w => w.focused);
        root.focusedWorkspaceId = f ? f.id : -1;
    }

    Process {
        id: events
        running: true
        command: ["niri", "msg", "--json", "event-stream"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let e;
                try { e = JSON.parse(line); } catch (err) { return; }

                if (e.WorkspacesChanged) {
                    root.rebuild(e.WorkspacesChanged.workspaces);
                } else if (e.WorkspaceActivated) {
                    const id = e.WorkspaceActivated.id;
                    root.workspaces = root.workspaces.map(w =>
                        Object.assign({}, w, { focused: w.id === id, active: w.id === id }));
                    root.focusedWorkspaceId = id;
                } else if (e.KeyboardLayoutsChanged) {
                    const k = e.KeyboardLayoutsChanged.keyboard_layouts;
                    root.keyboardLayouts = k.names;
                    root.layoutIndex = k.current_idx;
                    root.keyboardLayout = k.names[k.current_idx] || "";
                } else if (e.KeyboardLayoutSwitched) {
                    root.layoutIndex = e.KeyboardLayoutSwitched.idx;
                    root.keyboardLayout = root.keyboardLayouts[root.layoutIndex] || "";
                }
            }
        }
    }
}
