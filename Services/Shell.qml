pragma Singleton

import QtQuick
import Quickshell
import qs.Config

/*
 * Surface visibility state.
 *
 * Every popup in the shell is opened through here rather than by touching each
 * other's properties, which keeps mutual exclusion (only one full-screen overlay
 * at a time) in one readable place.
 *
 * The IPC handlers that drive these live in Ipc.qml at the config root, not
 * here. A singleton is only constructed when something first reads it, so a
 * handler declared inside one may not be registered when a call arrives.
 */
Singleton {
    id: root

    property bool launcherOpen: false
    property bool sessionOpen: false
    property bool controlCenterOpen: false
    property bool themeMenuOpen: false
    property bool quickSettingsOpen: false
    property bool lockOpen: false
    property bool wallpaperSelectorOpen: false
    property bool emojiOpen: false

    // Set by the surface itself while it exists. Distinguishes "the holder
    // never built it" from "it is built and not drawing" - two failures that
    // look identical from the outside and need opposite fixes.
    property bool wallpaperSelectorSurfaceAlive: false
    property string controlCenterTab: "home"

    /*
     * --- colour picker request
     *
     * Lives on this existing singleton rather than in a file of its own. The
     * previous attempt put it in a new Services/ColorPickerState.qml, alongside
     * a new Common/ColorPicker.qml, and the shell failed to load because the
     * generated module had no entry for the new component. Adding state to a
     * singleton that is already exposed cannot hit that.
     *
     * The caller hands over a function rather than connecting to a signal,
     * because the callers are Repeater delegates: they come and go as the pane
     * scrolls, and a delegate destroyed mid-edit would leave a dangling
     * connection. Holding the callback here means the request outlives the row
     * that made it.
     */
    /*
     * Set by the picker surface itself while it exists. Without it, "the
     * LazyLoader never created the surface" and "the surface exists and is not
     * drawing" are indistinguishable from the outside, and they need completely
     * different fixes.
     */
    property bool colorPickerSurfaceAlive: false

    property bool colorPickerOpen: false
    property string colorPickerTitle: ""
    property color colorPickerInitial: "#000000"
    property bool colorPickerResettable: false
    property var colorPickerApply: null
    property var colorPickerReset: null

    function requestColor(title, initial, onApply, onReset) {
        root.colorPickerTitle = title;
        root.colorPickerInitial = initial;
        root.colorPickerApply = onApply;
        root.colorPickerReset = onReset || null;
        root.colorPickerResettable = onReset !== undefined && onReset !== null;
        root.colorPickerOpen = true;
    }

    function applyColor(hex) {
        if (root.colorPickerApply) root.colorPickerApply(hex);
        root.closeColorPicker();
    }

    function resetColor() {
        if (root.colorPickerReset) root.colorPickerReset();
        root.closeColorPicker();
    }

    function closeColorPicker() {
        root.colorPickerOpen = false;
        root.colorPickerApply = null;
        root.colorPickerReset = null;
    }

    /*
     * --- font picker request
     *
     * Same shape as the colour picker above, and for the same reason: the row
     * that asks for a font is a child of a pane that can be swapped out from
     * under it, so the request has to outlive the asker.
     *
     * It is a request rather than an inline expansion because the picker is
     * keyboard-driven and modal - it takes the arrow keys away from the pane
     * for as long as it is up, and something that steals the navigation keys
     * should look like it has taken over the screen.
     */
    property bool fontPickerOpen: false
    property string fontPickerTitle: ""
    property string fontPickerHint: ""
    property string fontPickerCurrent: ""
    property var fontPickerApply: null

    function requestFont(title, hint, current, onApply) {
        root.fontPickerTitle = title;
        root.fontPickerHint = hint || "";
        root.fontPickerCurrent = current;
        root.fontPickerApply = onApply;
        root.fontPickerOpen = true;
    }

    function applyFont(family) {
        if (root.fontPickerApply) root.fontPickerApply(family);
        root.closeFontPicker();
    }

    function closeFontPicker() {
        root.fontPickerOpen = false;
        root.fontPickerApply = null;
    }


    /*
     * --- OSD requests from outside
     *
     * The compositor's key bindings run their own command - playerctl,
     * brightnessctl - and then report here which key it was, because the
     * result alone cannot say: MPRIS reports a new track the same way for
     * Previous as for Next, and the backlight is only polled. OsdLayer listens.
     */
    signal osdRequested(string kind, string detail)

    function osd(kind, detail) {
        osdRequested(kind, detail || "");
    }

    function closeAll() {
        launcherOpen = false;
        sessionOpen = false;
        controlCenterOpen = false;
        themeMenuOpen = false;
        quickSettingsOpen = false;
        wallpaperSelectorOpen = false;
        emojiOpen = false;
    }

    function toggleEmoji() {
        const next = !emojiOpen;
        closeAll();
        emojiOpen = next;
    }

    function toggleLauncher() {
        const next = !launcherOpen;
        closeAll();
        launcherOpen = next;
    }

    function toggleQuickSettings() {
        const next = !quickSettingsOpen;
        closeAll();
        quickSettingsOpen = next;
    }

    function toggleThemeMenu() {
        const next = !themeMenuOpen;
        closeAll();
        themeMenuOpen = next;
    }

    function toggleSession() {
        const next = !sessionOpen;
        closeAll();
        sessionOpen = next;
    }

    function toggleWallpaperSelector() {
        const next = !wallpaperSelectorOpen;
        closeAll();
        wallpaperSelectorOpen = next;
    }

    /*
     * Enter desktop edit mode and get out of the way.
     *
     * Edit mode is a mode you act in, not a setting you leave on: you drag
     * widgets around the desktop and then leave. Turning it on from a switch
     * inside the Control Center left the Control Center covering the thing you
     * had just made editable, so the switch appeared to do nothing until you
     * closed the window yourself.
     *
     * Both entry points call this - the Desktop pane and the Overview tile -
     * so the two cannot drift into behaving differently.
     */
    function enterDesktopEditMode() {
        Settings.desktop.editMode = true;
        controlCenterOpen = false;
    }

    function toggleControlCenter(tab) {
        const sameTab = !tab || tab === controlCenterTab;
        const next = !(controlCenterOpen && sameTab);
        if (tab) controlCenterTab = tab;
        closeAll();
        controlCenterOpen = next;
    }

    function lock() {
        closeAll();
        lockOpen = true;
    }

    Connections {
        target: Session
        function onLockRequested() { root.lock(); }
    }
}
