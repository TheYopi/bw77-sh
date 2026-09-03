pragma Singleton

import QtQuick
import Quickshell
import qs.Config

/*
 * Anchored popup state for bar widgets.
 *
 * Clicking a bar widget should open a small panel under that widget, not throw
 * the whole Control Center at you. Widgets call open() with themselves as the
 * anchor; this stores which popup and where, and a single overlay surface draws
 * it.
 *
 * Coordinates are scene coordinates inside the bar window. The bar spans the
 * full width of its screen, so scene x lines up with screen x and the overlay
 * can use it directly.
 */
Singleton {
    id: root

    property string current: ""      // "" = nothing open
    property real anchorX: 0
    property real anchorWidth: 0
    property var anchorScreen: null

    // Set when opening the tray menu; the surface hands it to QsMenuOpener.
    property var menuHandle: null

    readonly property bool open: current !== ""

    function openAt(name, item, screenRef) {
        if (!item) return;
        if (current === name) { close(); return; }

        // mapToItem(null, ...) gives scene coordinates within the bar window.
        const p = item.mapToItem(null, 0, 0);
        anchorX = p.x;
        anchorWidth = item.width;
        anchorScreen = screenRef;
        current = name;
    }

    // Tray menus are keyed by the item that opened them, so clicking a second
    // tray icon swaps the menu instead of toggling the popup shut.
    function openMenu(handle, item, screenRef) {
        if (!item) return;
        const p = item.mapToItem(null, 0, 0);
        anchorX = p.x;
        anchorWidth = item.width;
        anchorScreen = screenRef;
        menuHandle = handle;
        current = "trayMenu";
    }

    function close() {
        current = "";
        menuHandle = null;
    }
}
