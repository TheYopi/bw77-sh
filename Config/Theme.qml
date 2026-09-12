pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config

/*
 * Design tokens for the whole shell. Nothing anywhere else should contain a
 * literal hex colour, a literal pixel radius, or a literal animation duration.
 *
 * Role names are deliberately semantic (accent / danger / surfaceRaised) rather
 * than literal (cyan / red / darkGrey), so a user palette can invert the whole
 * shell without any widget knowing about it.
 */
Singleton {
    id: root

    // ---------------------------------------------------------------- palette

    // Baked-in fallback = the Night City palette pulled from the game UI.
    readonly property var fallback: ({
        "bgDeep":        "#05060A",
        "bgBase":        "#0B0D13",
        "bgRaised":      "#12151E",
        "bgOverlay":     "#1A0E14",
        "bgHover":       "#1E2430",
        "bgActive":      "#2A1218",

        "border":        "#3A2028",
        "borderStrong":  "#FF003C",
        "borderAccent":  "#2DE2E6",

        "accent":        "#2DE2E6",
        "accentDim":     "#1A8E92",
        "accentGlow":    "#7FF6F9",

        "danger":        "#FF003C",
        "dangerDim":     "#8C0021",
        "warn":          "#FCEE0A",
        "gold":          "#FF9F1C",
        "magenta":       "#C724B1",
        "success":       "#39D98A",

        "text":          "#E6F7FA",
        "textDim":       "#8FA9B3",
        "textMuted":     "#4E626C",
        "textOnAccent":  "#04070A",
        "textDanger":    "#FF4D6D",

        "chartCpu":      "#2DE2E6",
        "chartRam":      "#FCEE0A",
        "chartNet":      "#FF9F1C",
        "chartTemp":     "#FF003C"
    })

    property var palette: fallback

    // Reading a role goes through here so overrides and missing keys are handled
    // in exactly one place.
    function c(role) {
        const o = Settings.theme.overrides;
        if (o && o[role] !== undefined && o[role] !== "")
            return o[role];
        if (palette && palette[role] !== undefined)
            return palette[role];
        return fallback[role] !== undefined ? fallback[role] : "#FF00FF"; // magenta = missing role
    }

    // Named accessors. Widgets bind to these, so a palette swap repaints live.
    readonly property color bgDeep:       c("bgDeep")
    readonly property color bgBase:       c("bgBase")
    readonly property color bgRaised:     c("bgRaised")
    readonly property color bgOverlay:    c("bgOverlay")
    readonly property color bgHover:      c("bgHover")
    readonly property color bgActive:     c("bgActive")

    /*
     * The outline colour of a frame.
     *
     * Points at `border`, not at the signal red. Reading the study's colours
     * literally put every outline in the shell into the danger colour, which
     * spends the one hue that is supposed to mean something on ordinary
     * furniture - and on a theme whose accent is already a warm pink, a red
     * frame around every control is just noise. The study's note said the
     * colours were for contrast and would come from the theme; this is the
     * theme's answer.
     *
     * Kept as a distinct name from `border` so that "the outline of a frame"
     * and "a hairline that separates two things" can diverge later without
     * another sweep.
     */
    readonly property color frame:        c("border")
    readonly property color frameDim:     alpha(c("border"), 0.5)

    readonly property color border:       c("border")
    readonly property color borderStrong: c("borderStrong")
    readonly property color borderAccent: c("borderAccent")

    readonly property color accent:       c("accent")
    readonly property color accentDim:    c("accentDim")
    readonly property color accentGlow:   c("accentGlow")

    readonly property color danger:       c("danger")
    readonly property color dangerDim:    c("dangerDim")
    readonly property color warn:         c("warn")
    readonly property color gold:         c("gold")
    readonly property color magenta:      c("magenta")
    readonly property color success:      c("success")

    readonly property color text:         c("text")
    readonly property color textDim:      c("textDim")
    readonly property color textMuted:    c("textMuted")
    readonly property color textOnAccent: c("textOnAccent")
    readonly property color textDanger:   c("textDanger")

    function alpha(col, a) {
        return Qt.rgba(col.r, col.g, col.b, a);
    }

    // ------------------------------------------------------------- typography

    readonly property real scale: Settings.general.scale

    /*
     * Two families, three role names.
     *
     * The shell asks for fontDisplay, fontBody and fontMono in something like a
     * hundred places, and those names are still the right thing for a widget to
     * ask for - a readout wanting "the face the icons are in" is a different
     * question from a heading wanting "the face the text is in", even once both
     * resolve to fewer families than before. So the roles stay and the mapping
     * collapses here, which is the one place that is allowed to know how many
     * families there actually are.
     */
    readonly property string fontUI: Settings.general.fontUI
    readonly property string fontIcons: Settings.general.fontIcons

    readonly property string fontDisplay: fontUI
    readonly property string fontBody: fontUI
    readonly property string fontMono: fontIcons

    /*
     * The size ramp, derived from the base rather than fixed.
     *
     * Only `fontBase` used to read the setting; the other five were hard
     * numbers. So "base text size" changed the body role and nothing else -
     * which in practice meant tray menus and almost nowhere in the shell, since
     * most labels are `label` or `micro`. Turning it up made one size of text
     * grow while everything around it stayed put.
     *
     * The ratios are the old numbers over the old default of 13, so a base of
     * 13 reproduces the previous ramp exactly and anything else scales the
     * whole thing together.
     */
    readonly property real fontUnit: Settings.general.fontSizeBase * scale

    readonly property int fontMicro:  Math.round(fontUnit * 0.69)
    readonly property int fontSmall:  Math.round(fontUnit * 0.85)
    readonly property int fontBase:   Math.round(fontUnit)
    readonly property int fontLarge:  Math.round(fontUnit * 1.31)
    readonly property int fontTitle:  Math.round(fontUnit * 1.69)
    readonly property int fontHuge:   Math.round(fontUnit * 3.08)

    /*
     * Icons get their own size.
     *
     * A Nerd Font glyph drawn at the text size looks markedly smaller than the
     * text beside it: the glyphs are drawn inside the em box with their own
     * padding, so a 13px speaker sits at maybe nine visible pixels next to
     * 13px letters that fill their box. Tying icons to the text size was the
     * mistake - they need to be bigger than the text to look the same weight.
     */
    readonly property real iconScale: Settings.general.iconScale
    readonly property int fontIcon: Math.round(fontUnit * iconScale)

    // The game sets almost every label in caps with wide tracking. These are the
    // two tracking values used across the UI.
    readonly property real trackingWide: 1.6
    readonly property real trackingHeadline: 3.0

    // -------------------------------------------------------------- geometry

    // Corners are chamfered, never rounded. `notch` is the 45-degree cut length.
    readonly property int notch: Math.round(10 * scale)
    // The study's cut is deeper than the one the shell had been drawing, and
    // reads as deliberate rather than as a rounding artefact at small sizes.
    readonly property int notchLarge: Math.round(14 * scale)
    readonly property int notchSmall: Math.round(6 * scale)
    readonly property int borderWidth: 1
    readonly property int borderWidthStrong: 2

    readonly property int space1: Math.round(4  * scale)
    readonly property int space2: Math.round(8  * scale)
    readonly property int space3: Math.round(12 * scale)
    readonly property int space4: Math.round(16 * scale)
    readonly property int space5: Math.round(24 * scale)
    readonly property int space6: Math.round(32 * scale)

    readonly property int tickLength: Math.round(8 * scale)

    // ---------------------------------------------------------------- motion

    // Speed 0 is treated as reduce-motion, so there is one place that decides
    // whether the shell animates at all.
    readonly property real animSpeed: Settings.animations.speed
    readonly property bool reducedMotion: Settings.general.reducedMotion || animSpeed <= 0

    function dur(base) {
        return reducedMotion ? 0 : Math.round(base * animSpeed);
    }

    /*
     * durFast is the shell's hover-and-state speed.
     *
     * Every pointer-driven change - a fill lighting up under the cursor, a
     * label going from dim to bright, a selection moving down a list - runs on
     * this one number, so the whole interface answers the pointer at the same
     * rate. Long enough not to snap, short enough that the control still feels
     * attached to the hand moving over it: past about 150ms a hover begins to
     * lag the cursor and reads as the shell thinking rather than responding.
     *
     * There is deliberately no second token for hover. Two names within twenty
     * milliseconds of each other is how an interface ends up with half its
     * controls answering at one speed and half at another.
     */
    readonly property int durFast:    dur(130)
    readonly property int durNormal:  dur(220)
    readonly property int durSlow:    dur(380)

    // Cyberpunk UI motion is mechanical: it snaps in, it does not bounce.
    readonly property int easeOut: Easing.OutExpo
    readonly property int easeSnap: Easing.OutCubic

    /*
     * --- named curves
     *
     * The set the rest of the industry uses, so "ease-out" here means what it
     * means in CSS or After Effects rather than something shell-specific.
     * spring overshoots and settles; snap arrives almost immediately and
     * decelerates; sharp holds still and then leaves in a hurry.
     */
    readonly property var curveNames: [
        "linear", "ease", "ease-in", "ease-out", "ease-in-out", "spring", "snap", "sharp"
    ]

    function curveType(name) {
        switch (name) {
        case "linear":      return Easing.Linear;
        case "ease-in":     return Easing.InQuad;
        case "ease-out":    return Easing.OutQuad;
        case "ease-in-out": return Easing.InOutCubic;
        case "spring":      return Easing.OutBack;
        case "snap":        return Easing.OutExpo;
        case "sharp":       return Easing.InQuart;
        default:            return Easing.InOutQuad;   // "ease"
        }
    }

    /*
     * --- per-category motion
     *
     * Each surface family carries its own curve, duration and entry direction.
     * The defaults reproduce what the shell did before this existed, so an
     * untouched config looks unchanged.
     */
    /*
     * --- the menu family
     *
     * Everything that opens as a menu - the launcher, the Control Center, and
     * the assorted prompts under "menus" - shares one entry now: a short slide
     * up into place under a fade, on an ease-out, over 200ms.
     *
     * They used to each snap in with the glitch kick, which is the shell's
     * signature and still is - it is one direction among eight and the
     * Animations pane will put it back on any of these. But it is a hard,
     * mechanical arrival, and reaching for a menu twenty times an hour is the
     * one interaction where that costs more than it says. A surface that rises
     * a little as it fades reads as though it came from where you clicked.
     *
     * 200ms is the top of the range that still feels like a response rather
     * than a transition, and ease-out spends most of it decelerating, so the
     * surface is legible well before it has finished settling.
     */
    readonly property var motionDefaults: ({
        "dock":          ({ curve: "snap",    duration: 190, direction: "auto" }),
        "bar":           ({ curve: "ease-out", duration: 160, direction: "fade" }),
        "osd":           ({ curve: "snap",    duration: 200, direction: "scale" }),
        "notifications": ({ curve: "spring",  duration: 260, direction: "auto" }),
        // Not part of the menu family: it is a full-height drawer docked to an
        // edge, and "auto" resolves to that edge. Sliding it UP would move it by
        // its own width, which is what `travel` is set to in that panel.
        "quickSettings": ({ curve: "snap",    duration: 220, direction: "glitch" }),
        "controlCenter": ({ curve: "ease-out", duration: 200, direction: "up" }),
        "menus":         ({ curve: "ease-out", duration: 200, direction: "up" }),
        "launcher":      ({ curve: "ease-out", duration: 200, direction: "up" }),
        // Small, and it appears under the pointer rather than being asked for,
        // so it moves quicker than a menu and travels less far. "auto" is the
        // dock edge: a label on a bottom dock rises, one on a top dock drops.
        "tooltip":       ({ curve: "ease-out", duration: 150, direction: "auto" }),
        "wallpaper":     ({ curve: "ease-in-out", duration: 600, direction: "fade" }),
        "theme":         ({ curve: "ease",    duration: 240, direction: "fade" })
    })

    readonly property var motionCategories: [
        "dock", "bar", "osd", "notifications", "quickSettings",
        "controlCenter", "launcher", "menus", "tooltip", "wallpaper", "theme"
    ]

    readonly property var directionNames: [
        "auto", "fade", "scale", "up", "down", "left", "right", "glitch"
    ]

    function motionOf(category, key) {
        const def = motionDefaults[category];
        if (!def) return key === "duration" ? 220 : (key === "curve" ? "ease" : "fade");
        const set = Settings.animations.motion ? Settings.animations.motion[category] : undefined;
        if (set && set[key] !== undefined && set[key] !== null) return set[key];
        return def[key];
    }

    function curveFor(category)     { return curveType(motionOf(category, "curve")); }
    function directionFor(category) { return motionOf(category, "direction"); }
    function durationFor(category)  { return dur(motionOf(category, "duration")); }

    // ------------------------------------------------------- palette loading

    property string paletteDir: `${Settings.configDir}/palettes`

    FileView {
        id: paletteFile
        // User palettes take priority; built-ins ship in Config/Palettes.
        // Most people never add one, so a miss here is expected, not an error.
        path: `${root.paletteDir}/${Settings.theme.name}.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.palette = JSON.parse(text());
            } catch (e) {
                console.warn("bw77: bad palette JSON:", e);
                builtinFile.reload();
            }
        }
        onLoadFailed: builtinFile.reload()
    }

    FileView {
        id: builtinFile
        path: `${Quickshell.shellDir}/Config/Palettes/${Settings.theme.name}.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.palette = JSON.parse(text());
            } catch (e) {
                root.palette = root.fallback;
            }
        }
        onLoadFailed: root.palette = root.fallback
    }

    Connections {
        target: Settings.theme
        function onNameChanged() { paletteFile.reload(); }
    }
}
