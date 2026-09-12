pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Config

/*
 * The laptop battery, in the shell's own vocabulary.
 *
 * Quickshell already talks to UPower over D-Bus, so there is no polling and
 * nothing to shell out to. This is a translation layer on top of it, and it
 * exists for the same reason Power.qml does: the service speaks in enum values
 * and raw seconds, and every surface that shows a battery wants a glyph, a
 * duration in words and a colour.
 *
 * Two surfaces read it - the bar widget and the desktop widget - and the glyph
 * table is the reason it is a service rather than a property on either. Two
 * copies of a twenty-entry icon table drift the first time one of them is
 * corrected, and the drift is invisible until someone happens to have both on
 * screen at the same percentage.
 *
 * --- what is guarded and why
 *
 * UPowerDevice exposes more than the shell strictly needs, and not every field
 * is populated on every machine: a battery that does not report its design
 * capacity has no health figure, and a desktop has no battery at all. Reading a
 * property that is absent yields undefined rather than throwing, so the honest
 * thing is to test for it and say "not reported" - which is a different
 * statement from "0%", and the difference matters on exactly the readings
 * people go looking for.
 */
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice

    readonly property bool present: dev !== null && dev !== undefined
        && dev.isLaptopBattery === true

    // 0..1, as UPower reports it.
    readonly property real fraction: present && dev.percentage !== undefined
        ? dev.percentage : 0
    readonly property int percent: Math.round(fraction * 100)

    readonly property int state: present && dev.state !== undefined
        ? dev.state : UPowerDeviceState.Unknown

    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool fullyCharged: state === UPowerDeviceState.FullyCharged
    readonly property bool discharging: state === UPowerDeviceState.Discharging

    // Below this, and not on the cable, the bar widget pulses. Ten percent is
    // where the icon set stops having a step of its own, which is as good a
    // definition of "the battery is now the thing you should be looking at" as
    // any the hardware offers.
    readonly property real criticalFraction: 0.10
    readonly property bool critical: present && !charging && !fullyCharged
        && fraction < criticalFraction

    // Seconds. Zero means UPower has not worked it out yet, which it will not
    // have done for the first minute or so after a state change.
    readonly property int secondsToEmpty: present && dev.timeToEmpty !== undefined
        ? dev.timeToEmpty : 0
    readonly property int secondsToFull: present && dev.timeToFull !== undefined
        ? dev.timeToFull : 0

    /*
     * Wear, as a percentage of the capacity the pack shipped with.
     *
     * UPower calls it health and only reports it for batteries that publish a
     * design capacity. `healthSupported` is the flag that says so; without it a
     * missing figure and a genuinely dead pack both read as zero.
     */
    readonly property bool healthKnown: present
        && dev.healthSupported === true
        && dev.healthPercentage !== undefined
        && dev.healthPercentage > 0
    readonly property int health: healthKnown ? Math.round(dev.healthPercentage) : 0

    // Watts, positive in both directions. UPower signs it by state rather than
    // by value, so the sign here carries no information and is dropped.
    readonly property real watts: present && dev.changeRate !== undefined
        ? Math.abs(dev.changeRate) : 0
    readonly property bool wattsKnown: watts > 0.05

    readonly property real energy: present && dev.energy !== undefined ? dev.energy : 0
    readonly property real energyCapacity: present && dev.energyCapacity !== undefined
        ? dev.energyCapacity : 0

    // ------------------------------------------------------------- the icons
    /*
     * Nerd Font's Material Design battery set.
     *
     * Indexed by tens, so entry 7 is the icon for 70-79%. The discharging run
     * is contiguous in the font (F0079 through F0083) and the charging run is
     * emphatically not - Material added the 10, 50 and 70 steps years after the
     * rest, so they sit at F089C-F089E while their neighbours are at F0086 and
     * up. That is the whole reason this is a table rather than arithmetic on a
     * base codepoint, which is what it looked like it could be.
     *
     * Written as surrogate pairs because these are astral-plane codepoints and
     * QML string escapes are UTF-16, the same as everywhere else in the shell.
     */
    readonly property var dischargeGlyphs: [
        "󰂃",  //  0-9  battery-alert, the warning
        "󰁺",  // 10-19
        "󰁻",  // 20-29
        "󰁼",  // 30-39
        "󰁽",  // 40-49
        "󰁾",  // 50-59
        "󰁿",  // 60-69
        "󰂀",  // 70-79
        "󰂁",  // 80-89
        "󰂂"   // 90-99
    ]

    readonly property string fullGlyph: "󰁹"          // battery, 100%

    readonly property var chargeGlyphs: [
        "󰢜",  //  0-9   charging-10, because a battery on the cable
                         //        is not in trouble and should not say alert
        "󰢜",  // 10-19
        "󰂆",  // 20-29
        "󰂇",  // 30-39
        "󰂈",  // 40-49
        "󰢝",  // 50-59
        "󰂉",  // 60-69
        "󰢞",  // 70-79
        "󰂊",  // 80-89
        "󰂋"   // 90-99
    ]

    readonly property string chargeFullGlyph: "󰂅"    // charging-100

    function glyphFor(pct, isCharging) {
        const p = Math.max(0, Math.min(100, Math.round(pct * 100)));
        if (p >= 100) return isCharging ? root.chargeFullGlyph : root.fullGlyph;

        // Floor rather than round: 89% is still in the eighties, and rounding
        // would light the 90 icon a percent early at every step of the scale.
        const tens = Math.floor(p / 10);
        return isCharging ? root.chargeGlyphs[tens] : root.dischargeGlyphs[tens];
    }

    // Charging and fully-charged are different states and only one of them has
    // a bolt through the icon. A pack sitting at 100% on the cable is done.
    readonly property string glyph: glyphFor(fraction, charging)

    // ------------------------------------------------------- words and colour
    /*
     * A duration, in the largest units that still say something useful.
     *
     * UPower reports zero while it is still working an estimate out, and for a
     * few seconds either side of plugging in. That is not "no time remaining",
     * so it is reported as not known rather than as "0m".
     */
    function duration(seconds) {
        if (!seconds || seconds <= 0) return "";
        const mins = Math.round(seconds / 60);
        if (mins < 60) return `${mins}m`;
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        return m === 0 ? `${h}h` : `${h}h ${m}m`;
    }

    readonly property string timeToEmptyLabel: duration(secondsToEmpty)
    readonly property string timeToFullLabel: duration(secondsToFull)

    // The one line that answers "what is the battery doing". Empty when there
    // is nothing to say, so a caller can hide the row rather than print a
    // placeholder.
    readonly property string statusLabel: {
        if (!present) return "";
        if (fullyCharged) return Settings.t("Fully charged");
        if (charging) {
            const t = timeToFullLabel;
            return t === "" ? Settings.t("Charging")
                            : `${t} ${Settings.t("to full")}`;
        }
        const t = timeToEmptyLabel;
        return t === "" ? Settings.t("On battery")
                        : `${t} ${Settings.t("remaining")}`;
    }

    readonly property color tint: {
        if (charging || fullyCharged) return Theme.warn;
        if (critical) return Theme.danger;
        if (fraction < 0.25) return Theme.warn;
        return Theme.accent;
    }

    // ------------------------------------------------------------- history
    /*
     * Percentage over time, for the desktop widget's graph.
     *
     * Reference counted on the same pattern as SysMon, so a shell with no
     * battery widget on the desktop keeps no samples and runs no timer. A
     * battery moves in single percent steps over tens of minutes, so this
     * samples far slower than anything else in the shell: sixty samples at
     * thirty seconds is half an hour of context, which is the scale a discharge
     * curve is actually read at.
     */
    property int users: 0
    readonly property bool active: users > 0

    function acquire() { users = users + 1; }
    function release() { users = Math.max(0, users - 1); }

    property int historyLength: 60
    property var history: []

    onActiveChanged: if (!active) history = [];

    function sample() {
        if (!present) return;
        const next = history.slice(-(historyLength - 1));
        next.push(percent);
        history = next;
    }

    Timer {
        running: root.active && root.present
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }
}
