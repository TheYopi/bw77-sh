pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Config

/*
 * power-profiles-daemon, in the shell's own vocabulary.
 *
 * Quickshell already talks to the daemon over D-Bus - PowerProfiles in
 * Quickshell.Services.UPower - so there is no polling and no shelling out to
 * powerprofilesctl here. This is a thin translation layer on top of it: the
 * service speaks in enum values, and every surface that wants to show a profile
 * wants a name, a glyph and a list to pick from.
 *
 * Keeping that translation in one place rather than in the tile means the bar,
 * the panel and anything added later cannot disagree about what to call
 * "PowerSaver" or which icon goes with it.
 *
 * --- what is not here
 *
 * There is no "is the daemon installed" property, because the service does not
 * expose one. A machine without power-profiles-daemon reports Balanced and
 * ignores writes, which is indistinguishable from a machine sitting on
 * Balanced. `available` below is the closest honest answer: a daemon that
 * reports no performance profile on a desktop is normal, so it is not proof of
 * absence and is not treated as such - the tile can be switched off in
 * Settings if the machine has no daemon at all.
 */
Singleton {
    id: root

    readonly property int profile: PowerProfiles.profile

    // Only Performance is conditional; every daemon has the other two.
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    readonly property var profiles: {
        const out = [
            { v: PowerProfile.PowerSaver, l: Settings.t("Power saver"),
              glyph: "\uf06c" },
            { v: PowerProfile.Balanced,   l: Settings.t("Balanced"),
              glyph: "\uf24e" }
        ];
        // Listing a profile that cannot be set would be a row that does
        // nothing when pressed.
        if (root.hasPerformance)
            out.push({ v: PowerProfile.Performance, l: Settings.t("Performance"),
                       glyph: "\uf0e7" });
        return out;
    }

    function entryFor(p) {
        for (let i = 0; i < root.profiles.length; i++)
            if (root.profiles[i].v === p) return root.profiles[i];
        return null;
    }

    readonly property string label: {
        const e = root.entryFor(root.profile);
        return e ? e.l : Settings.t("Unknown");
    }

    readonly property string glyph: {
        const e = root.entryFor(root.profile);
        return e ? e.glyph : "\uf24e";
    }

    /*
     * True for anything that is not the default.
     *
     * Drives the tile's lit state. Balanced is the daemon's default and the
     * state most machines sit in, so lighting the tile for it would mean a
     * permanently lit tile that says nothing - the same reason the network
     * tile is not lit merely for having an adapter.
     */
    readonly property bool active: root.profile !== PowerProfile.Balanced

    /*
     * Another application is holding a profile.
     *
     * Worth surfacing because it explains a profile the person did not choose:
     * a game holds Performance, a battery daemon holds PowerSaver. Setting a
     * profile explicitly clears every hold, which is the daemon's behaviour,
     * not something imposed here.
     */
    readonly property bool held: PowerProfiles.holds.length > 0

    readonly property string holdReason: {
        const list = PowerProfiles.holds;
        if (list.length === 0) return "";
        const h = list[0];
        const who = h.applicationId || Settings.t("An application");
        return list.length > 1
            ? `${who} ${Settings.t("and others are holding this profile")}`
            : `${who}: ${h.reason || Settings.t("holding this profile")}`;
    }

    // Reported by the daemon when it has had to throttle - a hot laptop, or one
    // detected as being on a lap. Explains a Performance profile that is not
    // behaving like one.
    readonly property string degradation: {
        switch (PowerProfiles.degradationReason) {
        case PerformanceDegradationReason.LapDetected:
            return Settings.t("Throttled: lap detected");
        case PerformanceDegradationReason.HighTemperature:
            return Settings.t("Throttled: high temperature");
        }
        return "";
    }

    function setProfile(p) {
        if (p === PowerProfile.Performance && !root.hasPerformance) return;
        PowerProfiles.profile = p;
    }

    // Steps to the next profile, for the tile body and for a keybind. Wraps,
    // because the three profiles are a set rather than a range.
    function cycle() {
        const list = root.profiles;
        if (list.length === 0) return;
        let at = -1;
        for (let i = 0; i < list.length; i++)
            if (list[i].v === root.profile) { at = i; break; }
        root.setProfile(list[(at + 1) % list.length].v);
    }
}
