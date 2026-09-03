//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.Config
import qs.Common
import qs.Services
import qs.Bar
import qs.Modules.Wallpaper
import qs.Modules.Session
import qs.Modules.Launcher
import qs.Modules.Notifications
import qs.Modules.Desktop
import qs.Modules.Dock
import qs.Modules.ControlCenter
import qs.Modules.Lock
import qs.Modules.Polkit
import qs.Modules.Popups
import qs.Modules.QuickSettings
import qs.Modules.OSD

/*
 * BW77-Shell - a Cyberpunk 2077 inspired Quickshell desktop.
 *
 * Everything here is a top-level surface. Popups are behind LazyLoader so an
 * unused surface costs nothing until the first time it is opened.
 */
ShellRoot {
    // IPC first: it must exist in the tree for external `ipc call` to reach it.
    Ipc {}

    // Backgrounds first, so layer ordering is obvious from reading order.
    WallpaperLayer {}
    DesktopLayer {}

    Bar {}

    Dock {}

    /*
     * Every holder names the motion category of the surface it holds, so the
     * hold ends when that surface's close animation does. The dock was the only
     * one doing this; the rest sat on SurfaceHolder's fixed fallback, which is
     * why raising Duration for, say, the Control Center made it open slower and
     * still disappear instantly.
     */
    SurfaceHolder {
        open: DockMenuState.open
        category: "dock"
        component: Component { DockMenuSurface {} }
    }

    NotificationLayer {}

    OsdLayer {}

    SurfaceHolder {
        open: Popups.open
        category: "bar"
        component: Component { PopupSurface {} }
    }

    SurfaceHolder {
        open: Shell.launcherOpen
        category: "launcher"
        component: Component { Launcher {} }
    }

    SurfaceHolder {
        open: Shell.sessionOpen
        category: "menus"
        component: Component { SessionMenu {} }
    }

    SurfaceHolder {
        open: Shell.themeMenuOpen
        category: "theme"
        component: Component { ThemeMenu {} }
    }

    SurfaceHolder {
        open: Shell.quickSettingsOpen
        category: "quickSettings"
        component: Component { QuickSettingsPanel {} }
    }

    SurfaceHolder {
        open: Shell.controlCenterOpen
        category: "controlCenter"
        component: Component { ControlCenter {} }
    }

    SurfaceHolder {
        open: Shell.wallpaperSelectorOpen
        category: "menus"
        component: Component { WallpaperSelector {} }
    }

    /*
     * After the Control Center, so it stacks above it.
     *
     * SurfaceHolder rather than LazyLoader. Every PanelWindow popup in this
     * shell - the launcher, the session menu, the dock menu, the Control Center
     * itself - is held this way; the only LazyLoader is the lock, and that is a
     * WlSessionLock, not a window. Using the mechanism that is known to put a
     * PanelWindow on screen here rather than the one that has only ever been
     * used for something else.
     */
    SurfaceHolder {
        open: Shell.colorPickerOpen
        category: "menus"
        component: Component { ColorPickerSurface {} }
    }

    LazyLoader {
        active: Shell.lockOpen
        component: LockSurface {}
    }

    SurfaceHolder {
        open: Polkit.active
        category: "menus"
        component: Component { PolkitDialog {} }
    }

    // Touch the singletons that need to run from startup rather than on demand.
    Component.onCompleted: {
        SysMon.cpu;
        Compositor.kind;
        Wallpapers.files;
        AppTheme.statePath;
    }
}
