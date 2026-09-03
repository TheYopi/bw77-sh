import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * Full-screen host for the dock's context menu.
 *
 * Separate from the dock window so the menu can be any height without being
 * clipped, and so a click anywhere else dismisses it without the dock needing
 * an oversized input mask.
 */
PanelWindow {
    id: root

    screen: DockMenuState.screenRef

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bw77-dock-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    // Any click that is not on the menu closes it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: DockMenuState.close()
    }

    /*
     * Snapshot of what the menu is showing.
     *
     * The surface outlives the menu state by the length of the closing
     * animation, so binding the contents straight to the singleton means the
     * list empties on screen and only then fades. These copies track the live
     * data right up until a click, then hold still.
     */
    property bool frozen: false
    property string heldAppId: ""
    property bool heldPinned: false
    property var heldWindows: []

    readonly property var liveWindows: Apps.toplevelsFor(DockMenuState.appId)

    function syncFromState() {
        if (frozen || !DockMenuState.open) return;
        heldAppId = DockMenuState.appId;
        heldPinned = DockMenuState.pinned;
        heldWindows = liveWindows;
    }

    Component.onCompleted: syncFromState()
    onLiveWindowsChanged: syncFromState()

    Connections {
        target: DockMenuState

        // Reopening within the closing animation reuses this surface, so the
        // freeze has to lift or the new menu shows the previous one's contents.
        function onOpenChanged() {
            if (DockMenuState.open) {
                root.frozen = false;
                root.syncFromState();
            }
        }

        function onAppIdChanged() { root.syncFromState(); }
        function onPinnedChanged() { root.syncFromState(); }
    }

    /*
     * The menu had no transition at all: it appeared and vanished on the same
     * frame. But SurfaceHolder still held the surface alive for its close
     * duration afterwards, so there was a visible pause with nothing on screen
     * before the click landed anywhere else - the "delay before hiding". The
     * hold was always meant to cover a close animation; now there is one.
     */
    GlitchBox {
        id: box

        /*
         * The box carries the placement and the menu sits at its origin.
         *
         * GlitchBox scales about the centre of what it fills, so filling the
         * whole surface would have the menu growing out of the middle of the
         * display. Sizing it to the menu makes it grow from its own centre -
         * and the menu cannot drive the box's position while living inside it,
         * which is why the placement moved up here.
         */
        width: menu.implicitWidth
        height: menu.implicitHeight

        shown: DockMenuState.open
        category: "dock"

        // Menus grow away from the edge the dock is on.
        readonly property real wantX:
            DockMenuState.anchorX + DockMenuState.anchorWidth / 2 - box.width / 2
        readonly property real wantY: Settings.dock.position === "top"
            ? DockMenuState.anchorY + DockMenuState.anchorHeight + Theme.space2
            : DockMenuState.anchorY - box.height - Theme.space2

        autoDirection: Settings.dock.position === "top" ? "down"
            : Settings.dock.position === "left" ? "right"
            : Settings.dock.position === "right" ? "left" : "up"

        // Centred on the icon along the dock. Every branch is clamped: a vertical dock on a narrow screen can push
        // the menu off the far edge just as easily as a horizontal one.
        x: {
            let want = wantX;
            if (Settings.dock.position === "left")
                want = DockMenuState.anchorX + DockMenuState.anchorWidth + Theme.space2;
            else if (Settings.dock.position === "right")
                want = DockMenuState.anchorX - box.width - Theme.space2;

            return Math.max(Theme.space2,
                     Math.min(root.width - box.width - Theme.space2, want));
        }

        y: {
            if (Settings.dock.position === "left" || Settings.dock.position === "right") {
                return Math.max(Theme.space2,
                         Math.min(root.height - box.height - Theme.space2,
                                  DockMenuState.anchorY + DockMenuState.anchorHeight / 2 - box.height / 2));
            }
            return Math.max(Theme.space2,
                     Math.min(root.height - box.height - Theme.space2, wantY));
        }

        DockMenu {
            id: menu

            appId: root.heldAppId
            pinned: root.heldPinned
            windows: root.heldWindows

            onActionStarted: root.frozen = true
            onDismiss: DockMenuState.close()
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: DockMenuState.close()
    }
}
