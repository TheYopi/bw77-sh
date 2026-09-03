import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services

/*
 * IPC surface, deliberately instantiated in the shell tree rather than inside a
 * singleton. Handlers declared in a singleton are not reliably registered -
 * a singleton is only constructed when something first reads it, so the handler
 * may not exist when an external `ipc call` arrives.
 *
 * Everything here just forwards to the Shell singleton, which owns the state.
 *
 * Discover these at runtime with:
 *   qs -c bw77-shell ipc show
 */
Scope {
    IpcHandler {
        target: "shell"

        function toggleLauncher(): void { Shell.toggleLauncher(); }
        function toggleSession(): void { Shell.toggleSession(); }
        function toggleControlCenter(tab: string): void { Shell.toggleControlCenter(tab); }
        function openControlCenter(tab: string): void {
            Shell.controlCenterTab = tab === "" ? "home" : tab;
            Shell.controlCenterOpen = true;
        }
        function lock(): void { Shell.lock(); }
        function closeAll(): void { Shell.closeAll(); }

        /*
         * Build stamp. Bumped every time the config is handed over, so
         * "is the shell running the files I just copied in" is one command
         * rather than an argument.
         */
        function build(): string { return "r40 2026-09-03"; }

        // Switch language without opening the Control Center.
        function language(code: string): void {
            Settings.general.language = code === "" ? "en" : code;
        }
    }

    // Grouped separately so `ipc show` reads as a menu rather than one long list.
    IpcHandler {
        target: "theme"

        function set(name: string): void { Settings.theme.name = name; }
        function menu(): void { Shell.toggleThemeMenu(); }
        function current(): string { return Settings.theme.name; }

        /*
         * Opens the colour picker directly, bypassing the Theme pane's swatch.
         *
         * Diagnostic as much as convenience: it splits "the picker is broken"
         * from "the swatch is not reaching the picker", which are two very
         * different bugs and cannot be told apart by clicking a square.
         *
         *   qs -c bw77-shell ipc call theme pick accent
         */
        function pick(role: string): void {
            const r = role === "" ? "accent" : role;
            Shell.controlCenterOpen = true;
            Shell.controlCenterTab = "theme";
            Shell.requestColor(r, Theme.c(r),
                (hex) => {
                    const o = Object.assign({}, Settings.theme.overrides);
                    o[r] = hex;
                    Settings.theme.overrides = o;
                },
                () => {
                    const o = Object.assign({}, Settings.theme.overrides);
                    delete o[r];
                    Settings.theme.overrides = o;
                });
        }

        // Reports the picker's state, so "is it open and invisible" and "it
        // never opened" are distinguishable without reading the log.
        function pickerState(): string {
            return (Shell.colorPickerOpen ? "open, title=" + Shell.colorPickerTitle : "closed")
                 + "; surface=" + (Shell.colorPickerSurfaceAlive ? "alive" : "NOT BUILT");
        }
    }

    IpcHandler {
        target: "wallpaper"

        function random(): void { Wallpapers.random(); }
        function rescan(): void { Wallpapers.scan(); }
        function set(path: string): void { Wallpapers.set(path, ""); }
        function current(): string { return Wallpapers.current; }

        /*
         * The full-screen picker.
         *
         *   qs -c bw77-shell ipc call wallpaper toggle
         *
         * `toggle` is the one to bind to a key - pressing it again should put
         * the surface away, which is what every other surface in the shell
         * does. `open` and `close` exist for scripts that need to be sure which
         * way they are going.
         */
        function toggle(): void { Shell.toggleWallpaperSelector(); }
        function open(): void { Shell.closeAll(); Shell.wallpaperSelectorOpen = true; }
        function close(): void { Shell.wallpaperSelectorOpen = false; }

        // Reports both halves of the picker, so a failure can be placed.
        // "open, surface=NOT BUILT" means the flag is set and the surface
        // failed to load - check the shell log for a QML error in
        // WallpaperSelector.qml. "closed" means the call never reached here.
        function state(): string {
            return (Shell.wallpaperSelectorOpen ? "open" : "closed")
                 + "; surface=" + (Shell.wallpaperSelectorSurfaceAlive ? "alive" : "NOT BUILT")
                 + "; images=" + Wallpapers.files.length;
        }
    }

    IpcHandler {
        target: "audio"

        function toggleMute(): void { Audio.toggleMute(); }
        function toggleMicMute(): void { Audio.toggleMicMute(); }
        function volumeUp(): void { Audio.setVolume(Audio.volume + 0.02); }
        function volumeDown(): void { Audio.setVolume(Audio.volume - 0.02); }
        function setVolume(percent: int): void { Audio.setVolume(percent / 100); }
    }

    IpcHandler {
        target: "quickSettings"

        function toggle(): void { Shell.toggleQuickSettings(); }
        function open(): void { Shell.closeAll(); Shell.quickSettingsOpen = true; }
        function close(): void { Shell.quickSettingsOpen = false; }
    }

    IpcHandler {
        target: "polkit"

        // Prints the properties and methods the polkit objects actually expose.
        // Run this while a prompt is open to find the real cancel method:
        //   qs -c bw77-shell ipc call polkit describe
        function describe(): void { Polkit.describe(); }

        function cancel(): void { Polkit.cancel(); }
        function status(): string {
            if (!Polkit.supported) return "module unavailable";
            if (Polkit.conflicted) return "another agent is registered";
            return Polkit.registered ? "registered" : "waiting for first request";
        }
    }

    IpcHandler {
        target: "desktop"

        function toggleEdit(): void {
            Settings.desktop.editMode = !Settings.desktop.editMode;
        }
        function toggleDnd(): void {
            Settings.notifications.doNotDisturb = !Settings.notifications.doNotDisturb;
        }

        /*
         * What is actually stored for each widget, and what displays exist.
         *
         *   qs -c bw77-shell ipc call desktop widgets
         *
         * Here because moving a widget between displays failed three times in
         * a row and every diagnosis was guesswork - the write, the model, the
         * surface and the compositor all looked plausible from the outside and
         * there was no way to tell which of them was not doing its job. This
         * prints the stored assignment next to the real output names, so
         * "the setting never changed" and "the setting changed and the surface
         * did not follow" stop looking identical.
         */
        function widgets(): string {
            const names = [];
            for (let i = 0; i < Quickshell.screens.length; i++)
                names.push(Quickshell.screens[i].name);

            const list = Settings.desktop.widgets;
            const out = ["displays: " + (names.join(", ") || "none"),
                         "widgets: " + list.length];

            for (let j = 0; j < list.length; j++) {
                const w = list[j];
                out.push("  [" + j + "] " + w.type
                    + " screen=" + (w.screen && w.screen !== ""
                        ? w.screen : "(unset -> first display)")
                    + " at " + w.x + "," + w.y + " " + w.w + "x" + w.h);
            }
            return out.join("\n");
        }

        /*
         * Move a widget to a named display from outside the shell.
         *
         *   qs -c bw77-shell ipc call desktop moveWidget 0 DP-1
         *
         * The same write the Control Center stepper performs. If this works
         * and the stepper does not, the fault is in the control; if neither
         * works, it is in the write or below it.
         */
        function moveWidget(index: int, screenName: string): string {
            const list = Settings.desktop.widgets.slice();
            if (index < 0 || index >= list.length)
                return "no widget at index " + index;

            list[index] = Object.assign({}, list[index], { screen: screenName });
            Settings.desktop.widgets = list;

            const now = Settings.desktop.widgets[index];
            return "wrote screen=" + screenName + "; reads back as "
                 + (now && now.screen !== undefined ? now.screen : "(missing)");
        }
    }
}
