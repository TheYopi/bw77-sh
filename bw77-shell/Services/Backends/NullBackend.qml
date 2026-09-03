import QtQuick

/* Fallback when no supported compositor is detected. */
QtObject {
    property var workspaces: []
    property int focusedWorkspaceId: -1
    property string keyboardLayout: ""
    property var keyboardLayouts: []

    function focusWorkspace(ws) {}
    function cycleKeyboardLayout() {}
}
