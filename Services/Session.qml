pragma Singleton

import QtQuick
import Quickshell
import qs.Config

/* Power actions in one place, so the session menu, launcher and IPC agree. */
Singleton {
    id: root

    property string lockCommand: ""   // empty = use the built-in lock surface

    signal lockRequested()

    function shutdown()  { Quickshell.execDetached(["systemctl", "poweroff"]); }
    function reboot()    { Quickshell.execDetached(["systemctl", "reboot"]); }
    function suspend()   { Quickshell.execDetached(["systemctl", "suspend"]); }
    function hibernate() { Quickshell.execDetached(["systemctl", "hibernate"]); }

    function lock() {
        if (lockCommand !== "")
            Quickshell.execDetached(["sh", "-c", lockCommand]);
        else
            root.lockRequested();
    }

    function logout() {
        switch (Compositor.kindName) {
        case "niri":     Quickshell.execDetached(["niri", "msg", "action", "quit", "-s"]); break;
        case "hyprland": Quickshell.execDetached(["hyprctl", "dispatch", "exit"]); break;
        case "sway":     Quickshell.execDetached(["swaymsg", "exit"]); break;
        default:         Quickshell.execDetached(["loginctl", "terminate-session", "self"]);
        }
    }
}
