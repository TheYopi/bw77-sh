pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Services.Backends

/*
 * One interface over the running compositor, so bar widgets never care which WM
 * is underneath.
 *
 * Focused-window data comes from the wlr foreign-toplevel protocol, which every
 * supported compositor implements, so only workspaces and keyboard layout need
 * per-compositor backends.
 *
 * Quickshell 0.3 added a generic WindowManager interface built on ext-workspace.
 * Once your compositor exposes it, the niri/Hyprland backends below can be
 * dropped in favour of that - the rest of the shell will not notice.
 */
Singleton {
    id: root

    readonly property string kind: {
        if (Quickshell.env("NIRI_SOCKET")) return "niri";
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) return "hyprland";
        if (Quickshell.env("SWAYSOCK")) return "sway";
        return "unknown";
    }

    readonly property string kindName: kind

    // --- workspaces: [{ id, name, index, focused, active, occupied, output }]
    property var workspaces: backendLoader.item ? backendLoader.item.workspaces : []
    property int focusedWorkspaceId: backendLoader.item ? backendLoader.item.focusedWorkspaceId : -1

    // --- keyboard layout
    property string keyboardLayout: backendLoader.item ? backendLoader.item.keyboardLayout : ""
    property var keyboardLayouts: backendLoader.item ? backendLoader.item.keyboardLayouts : []

    // --- the compositor's overview, where the wallpaper backdrop is shown
    property bool overviewOpen: backendLoader.item ? !!backendLoader.item.overviewOpen : false

    // --- focused window, protocol-level so it works everywhere
    readonly property Toplevel activeToplevel: ToplevelManager.activeToplevel
    readonly property string activeTitle: activeToplevel ? activeToplevel.title : ""
    readonly property string activeAppId: activeToplevel ? activeToplevel.appId : ""

    readonly property DesktopEntry activeEntry:
        activeAppId ? DesktopEntries.heuristicLookup(activeAppId) : null
    readonly property string activeAppName:
        activeEntry ? activeEntry.name : (activeAppId || "")
    readonly property string activeIcon:
        activeEntry ? activeEntry.icon : ""

    // Takes the whole workspace object, not an id. niri and Hyprland identify
    // workspaces differently, and passing niri an internal id made every switch
    // land on the last workspace because it read the id as an index.
    function focusWorkspace(ws) {
        if (backendLoader.item && ws) backendLoader.item.focusWorkspace(ws);
    }

    function cycleKeyboardLayout() {
        if (backendLoader.item) backendLoader.item.cycleKeyboardLayout();
    }

    Loader {
        id: backendLoader
        active: true
        sourceComponent: {
            switch (root.kind) {
            case "niri":     return niriBackend;
            case "hyprland": return hyprBackend;
            default:         return nullBackend;
            }
        }
    }

    Component { id: niriBackend; NiriBackend {} }
    Component { id: hyprBackend; HyprlandBackend {} }
    Component { id: nullBackend; NullBackend {} }
}
