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

    /*
     * Whether niri's overview is on screen.
     *
     * The wallpaper backdrop surface is only ever seen there, so knowing this
     * is what lets the shell build it on demand rather than hold a full-screen
     * surface per monitor for the whole session - see Modules/Wallpaper.
     */
    property bool overviewOpen: false

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

                    /*
                     * `focused` is global, `active` is per output.
                     *
                     * This used to set active the same way as focused, which
                     * quietly cleared the active flag on every other monitor's
                     * workspaces until the next full WorkspacesChanged rebuilt
                     * them. Nothing read the flag closely enough to notice
                     * before; the bar's compact workspace style does, because
                     * on a monitor that does not hold the keyboard focus it is
                     * the only thing that can say which workspace is showing
                     * there.
                     */
                    const target = root.workspaces.find(w => w.id === id);
                    const output = target ? target.output : "";

                    root.workspaces = root.workspaces.map(w =>
                        Object.assign({}, w, {
                            focused: w.id === id,
                            active: w.output === output ? w.id === id : w.active
                        }));
                    root.focusedWorkspaceId = id;
                } else if (e.KeyboardLayoutsChanged) {
                    const k = e.KeyboardLayoutsChanged.keyboard_layouts;
                    root.keyboardLayouts = k.names;
                    root.layoutIndex = k.current_idx;
                    root.keyboardLayout = k.names[k.current_idx] || "";
                } else if (e.OverviewOpenedOrClosed) {
                    root.overviewOpen = !!e.OverviewOpenedOrClosed.is_open;
                } else if (e.KeyboardLayoutSwitched) {
                    root.layoutIndex = e.KeyboardLayoutSwitched.idx;
                    root.keyboardLayout = root.keyboardLayouts[root.layoutIndex] || "";
                }
            }
        }
    }
}
