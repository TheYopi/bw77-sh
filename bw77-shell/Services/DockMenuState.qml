pragma Singleton

import QtQuick
import Quickshell
import qs.Config

/*
 * Which dock menu is open, and where to draw it.
 *
 * Named DockMenuState rather than DockMenu so it does not collide with the
 * visual component of that name in Modules/Dock.
 *
 * The menu used to live inside the dock's own window, which meant it was
 * clipped by that window's height - a handful of open windows and the bottom of
 * the list was simply cut off - and required an oversized input mask to catch
 * outside clicks, which swallowed part of the screen.
 *
 * Holding the state here lets a separate full-screen surface draw it: no
 * clipping, and outside clicks land on that surface instead of a mask.
 */
Singleton {
    id: root

    property string appId: ""
    property bool pinned: false
    property string action: ""
    property var screenRef: null

    // Anchor rectangle in screen coordinates.
    property real anchorX: 0
    property real anchorY: 0
    property real anchorWidth: 0
    property real anchorHeight: 0

    readonly property bool open: appId !== "" || action !== ""

    /*
     * Anchor geometry, in SCREEN coordinates.
     *
     * mapToItem(null, ...) gives a position inside the dock's own window, and
     * that window is a thin strip along one edge - so a y of about ten meant
     * "ten pixels down the strip", which the full-screen menu surface then read
     * as ten pixels from the top of the display.
     *
     * The dock window spans the full length of its edge, so its origin on that
     * axis is zero; on the thickness axis it is either zero or the screen size
     * minus the window size, depending on which edge it is anchored to. That is
     * enough to convert.
     */
    function openFor(id, isPinned, item, dockWindow, screen) {
        if (!item || !dockWindow) return;

        const local = item.mapToItem(null, 0, 0);

        const screenW = screen ? screen.width : dockWindow.width;
        const screenH = screen ? screen.height : dockWindow.height;

        let originX = 0;
        let originY = 0;

        switch (Settings.dock.position) {
        case "bottom": originY = screenH - dockWindow.height; break;
        case "top":    originY = 0; break;
        case "right":  originX = screenW - dockWindow.width; break;
        case "left":   originX = 0; break;
        }

        anchorX = originX + local.x;
        anchorY = originY + local.y;
        anchorWidth = item.width;
        anchorHeight = item.height;

        screenRef = screen;
        pinned = isPinned;
        appId = id;
    }

    function close() {
        appId = "";
        action = "";
    }

    function toggleFor(id, isPinned, item, dockWindow, screen) {
        if (open && appId === id) { close(); return; }
        openFor(id, isPinned, item, dockWindow, screen);
    }
}
