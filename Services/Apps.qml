pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Services

/*
 * Application identity, shared by the dock and the launcher.
 *
 * The hard part is matching a running window back to a desktop entry: a
 * toplevel's appId can be a desktop file id, a WM_CLASS, or something a
 * developer typed once and never revisited. Everything funnels through
 * resolve() so the matching rules live in one place.
 */
Singleton {
    id: root

    // Toplevels grouped by the entry they belong to.
    readonly property var running: {
        const groups = {};
        const list = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : [];
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            if (!t) continue;
            const key = normalise(t.appId);
            if (!groups[key]) groups[key] = [];
            groups[key].push(t);
        }
        return groups;
    }

    readonly property var runningIds: Object.keys(running)

    function normalise(appId) {
        if (!appId) return "";
        // Desktop ids, WM_CLASS values and binary names all end up here, so
        // lower-case and drop a trailing .desktop before comparing.
        let id = String(appId).toLowerCase();
        if (id.endsWith(".desktop")) id = id.substring(0, id.length - 8);
        return id;
    }

    /*
     * Index of every desktop entry, keyed several ways.
     *
     * Matching a window to its entry is the hard part, and Flatpak makes it
     * harder: a toplevel may report "org.telegram.desktop", "telegram-desktop",
     * or the binary name, while the entry is filed under a reverse-DNS id. One
     * heuristicLookup on the raw appId misses most of those, which is why so
     * many Flatpak apps showed a blank icon.
     *
     * Every key a window might plausibly report is registered here once, and
     * lookup is a single map hit afterwards.
     */
    /*
     * Index of every desktop entry, in tiers.
     *
     * Tiers matter. Every Steam game ships a launcher whose Exec is
     * `steam steam://rungameid/...`, so a single flat map keyed on the binary
     * name hands back whichever game happened to be indexed first when a window
     * reports "steam" - which is why the dock showed a random game for Steam
     * itself.
     *
     * Lookups therefore walk from the most authoritative key to the least:
     * a desktop id beats a StartupWMClass, which beats a display name, which
     * beats a binary name scraped out of Exec.
     */
    readonly property var entryIndex: {
        const ids = {};       // org.telegram.desktop, steam
        const classes = {};   // StartupWMClass
        const names = {};     // display name
        const binaries = {};  // executable from Exec, only where unambiguous
        const binaryOwners = {};

        const values = DesktopEntries.applications
            ? DesktopEntries.applications.values : [];

        function put(map, key, entry) {
            if (!key) return;
            const k = String(key).toLowerCase().trim();
            if (k === "" || map[k]) return;   // first writer wins within a tier
            map[k] = entry;
        }

        for (let i = 0; i < values.length; i++) {
            const e = values[i];
            if (!e) continue;

            const id = String(e.id || "");
            const bare = id.endsWith(".desktop") ? id.slice(0, -8) : id;

            put(ids, id, e);
            put(ids, bare, e);

            // Reverse-DNS tail: org.gnome.Nautilus -> nautilus, which is what
            // the window actually reports.
            const parts = bare.split(".");
            if (parts.length > 1) put(ids, parts[parts.length - 1], e);

            // The field intended for exactly this job.
            if (e.startupClass) put(classes, e.startupClass, e);

            put(names, e.name, e);

            const binary = execBinary(e);
            if (binary !== "") {
                if (!binaryOwners[binary]) binaryOwners[binary] = [];
                binaryOwners[binary].push(e);
            }
        }

        /*
         * A binary is only usable as a key when exactly one entry claims it.
         *
         * Every Steam library game has `Exec=steam steam://rungameid/...`, so
         * "steam" is claimed by dozens of entries and picking any one of them
         * means the dock shows a random game for Steam itself. The same holds
         * for wine, lutris and every other launcher that fronts a library.
         *
         * Registering only unambiguous binaries costs nothing - a contested key
         * was never going to give the right answer - and the icon theme
         * fallback in iconFor() usually has the launcher's own icon anyway.
         */
        for (const binary in binaryOwners) {
            if (binaryOwners[binary].length === 1)
                put(binaries, binary, binaryOwners[binary][0]);
        }

        return { ids: ids, classes: classes, names: names, binaries: binaries };
    }

    /*
     * The executable an entry actually launches.
     *
     * Wrapper commands are skipped so `flatpak run org.x.Y` yields the
     * application rather than "flatpak", and interpreter prefixes are stepped
     * over for the same reason.
     */
    readonly property var execWrappers: ({
        "flatpak": true, "run": true, "env": true, "sh": true, "bash": true,
        "zsh": true, "python": true, "python3": true, "java": true,
        "flatpak-spawn": true, "gtk-launch": true, "dbus-run-session": true,
        "systemd-run": true, "nohup": true, "setsid": true
    })

    function execBinary(entry) {
        if (!entry || !entry.execString) return "";
        const tokens = String(entry.execString).split(/\s+/);

        for (let t = 0; t < tokens.length; t++) {
            const tok = tokens[t];
            if (!tok) continue;
            // Field codes and switches are never the program.
            if (tok.startsWith("-") || tok.startsWith("@") || tok.startsWith("%")) continue;
            if (tok.indexOf("=") !== -1) continue;      // VAR=value prefix

            const base = tok.split("/").pop().toLowerCase();
            if (execWrappers[base]) continue;
            return base;
        }
        return "";
    }

    function lookupTiered(key) {
        if (!key) return null;
        const k = String(key).toLowerCase().trim();
        if (k === "") return null;

        if (entryIndex.ids[k]) return entryIndex.ids[k];
        if (entryIndex.classes[k]) return entryIndex.classes[k];
        if (entryIndex.names[k]) return entryIndex.names[k];
        if (entryIndex.binaries[k]) return entryIndex.binaries[k];
        return null;
    }

    function resolve(id) {
        if (!id) return null;

        const raw = String(id);
        const lower = raw.toLowerCase();
        const bare = lower.endsWith(".desktop") ? lower.slice(0, -8) : lower;

        let hit = lookupTiered(bare);
        if (hit) return hit;

        if (lower !== bare) {
            hit = lookupTiered(lower);
            if (hit) return hit;
        }

        const parts = bare.split(".");
        if (parts.length > 1) {
            hit = lookupTiered(parts[parts.length - 1]);
            if (hit) return hit;
        }

        // Some toplevels append a suffix, e.g. "signal-desktop (wayland)".
        const head = bare.split(/[ ()]/)[0];
        if (head !== bare) {
            hit = lookupTiered(head);
            if (hit) return hit;
        }

        // Quickshell's own heuristic last, as a safety net.
        const direct = DesktopEntries.heuristicLookup(raw);
        if (direct) return direct;

        return null;
    }

    /*
     * The numeric Steam app id, or "" for anything that is not a Steam game.
     *
     * A game launched through Steam reports "steam_app_570" and has no desktop
     * entry of its own, so resolve() finds nothing for it and every game in the
     * dock drew the same generic executable box. Gamescope and XWayland both
     * produce this form; the capitalised variants show up from some Proton
     * builds, hence the case-insensitive match.
     */
    function steamAppId(id) {
        if (!id) return "";
        const m = String(id).toLowerCase().match(/^steam_app_(\d+)$/);
        return m ? m[1] : "";
    }

    function iconFor(id) {
        /*
         * Steam first, because the generic lookups below would otherwise
         * succeed on the wrong thing: "steam_app_570" contains "steam", and the
         * tail-of-the-dotted-name fallback happily resolves a game to Steam's
         * own client icon. Every game in the dock would show the Steam logo,
         * which looks deliberate and is therefore worse than the empty box.
         */
        const steamId = steamAppId(id);
        if (steamId !== "") {
            // Installed shortcuts land in the icon theme under this name, and
            // going through the theme gets proper size selection.
            const themed = Quickshell.iconPath("steam_icon_" + steamId, true);
            if (themed) return themed;

            // Otherwise Steam's artwork cache. Returns "" on the first call for
            // an unknown game and fills in when the scan completes.
            const cached = Steam.iconFor(steamId);
            if (cached) return cached;

            // Falling through to Steam's own icon is better than the generic
            // box: it at least says what launched this.
            const client = Quickshell.iconPath("steam", true);
            if (client) return client;
        }

        const entry = resolve(id);
        if (entry && entry.icon) {
            const path = Quickshell.iconPath(entry.icon, true);
            if (path) return path;
        }

        /*
         * No entry, or an entry naming an icon the theme does not have. Flatpak
         * installs its icons under the application id itself, so trying the
         * appId directly rescues exactly the case that was failing - and the
         * lower-cased form too, since icon files are usually lower case while
         * appIds often are not.
         */
        if (id) {
            const raw = String(id);
            const direct = Quickshell.iconPath(raw, true);
            if (direct) return direct;

            const lower = Quickshell.iconPath(raw.toLowerCase(), true);
            if (lower) return lower;

            const parts = raw.split(".");
            if (parts.length > 1) {
                const tail = Quickshell.iconPath(parts[parts.length - 1].toLowerCase(), true);
                if (tail) return tail;
            }
        }

        return Quickshell.iconPath("application-x-executable", true);
    }

    function nameFor(id) {
        const entry = resolve(id);
        if (entry && entry.name) return entry.name;
        return id;
    }

    function toplevelsFor(id) {
        const key = normalise(id);
        if (running[key]) return running[key];

        // A pinned entry's id and its window's appId often differ; compare the
        // resolved desktop entry instead of the raw strings.
        const target = resolve(id);
        if (!target) return [];
        const out = [];
        for (const k in running) {
            const candidate = resolve(k);
            if (candidate && candidate.id === target.id) {
                for (let i = 0; i < running[k].length; i++) out.push(running[k][i]);
            }
        }
        return out;
    }

    function isRunning(id) {
        return toplevelsFor(id).length > 0;
    }

    /*
     * --- desktop entry actions (jumplists)
     *
     * The extra entry points an application declares in its .desktop file:
     *
     *     Actions=new-window;new-private-window;
     *     [Desktop Action new-private-window]
     *     Name=New Incognito Window
     *     Exec=/usr/bin/brave --incognito
     *
     * This is the freedesktop standard every dock uses for its right-click
     * menu, and it is what puts "New Incognito Window" under Brave or "New
     * Spreadsheet" under LibreOffice. It is NOT the app's menu bar - see the
     * note in DockMenu about why that is a different thing entirely.
     *
     * Guarded rather than assumed: entries without an Actions key return an
     * empty list, and the caller renders nothing.
     */
    function actionsFor(id) {
        const entry = resolve(id);
        if (!entry || !entry.actions) return [];
        try {
            const list = entry.actions;
            const out = [];
            for (let i = 0; i < list.length; i++) {
                const a = list[i];
                if (!a) continue;
                out.push({
                    name: a.name || a.id || "",
                    icon: a.icon || "",
                    run: a
                });
            }
            return out;
        } catch (e) {
            return [];
        }
    }

    /*
     * DesktopAction.execute() handles the Exec quoting rules, field codes and
     * the working directory. Falling back to a raw shell split would get %U and
     * quoted paths wrong, so if it is missing we do nothing rather than run
     * something subtly different from what the entry asked for.
     */
    function runAction(action) {
        if (!action || !action.run) return false;
        if (typeof action.run.execute === "function") {
            action.run.execute();
            return true;
        }
        return false;
    }

    function launch(id) {
        const entry = resolve(id);
        if (entry) entry.execute();
        else Quickshell.execDetached(["sh", "-c", id]);
    }

    // Click behaviour: launch if nothing is running, otherwise focus. With
    // several windows open, repeated clicks walk through them.
    property var cycleIndex: ({})

    function activate(id, mode) {
        const windows = toplevelsFor(id);
        if (windows.length === 0) {
            launch(id);
            return;
        }

        if (mode === "activate" || windows.length === 1) {
            windows[0].activate();
            return;
        }

        const key = normalise(id);
        const next = ((cycleIndex[key] === undefined ? -1 : cycleIndex[key]) + 1) % windows.length;
        const map = Object.assign({}, cycleIndex);
        map[key] = next;
        cycleIndex = map;
        windows[next].activate();
    }

    function pin(id) {
        const list = Settings.dock.pinned.slice();
        const key = normalise(id);
        if (list.map(normalise).indexOf(key) === -1) {
            list.push(key);
            Settings.dock.pinned = list;
        }
    }

    function unpin(id) {
        const key = normalise(id);
        Settings.dock.pinned = Settings.dock.pinned.filter(p => normalise(p) !== key);
    }

    function isPinned(id) {
        const key = normalise(id);
        return Settings.dock.pinned.map(normalise).indexOf(key) !== -1;
    }
}
