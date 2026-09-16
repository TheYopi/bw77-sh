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
     * ======================================================================
     * MOTION
     * ======================================================================
     *
     * The shape of every animation in the shell comes from here. Two ideas run
     * through it, both borrowed from Material 3 and both bent to fit.
     *
     * --- 1. motion has a direction in time
     *
     * Material's central motion idea is that easing is ASYMMETRIC: a thing
     * arriving decelerates into place over a long tail, and a thing leaving
     * accelerates away and is gone. Both are how physical objects behave and
     * neither is what a symmetric ease does.
     *
     * The shell had none of this. Opening and closing ran the same curve at
     * almost the same length, so surfaces left as ceremoniously as they
     * arrived - which on something dismissed twenty times an hour reads as the
     * interface being slow, no matter what the number says.
     *
     * --- 2. easing belongs to what is changing, not to the widget
     *
     * Material splits motion in two. Things that MOVE - a panel sliding, a
     * dock revealing - take the emphasized curves. Things that only change
     * APPEARANCE - a colour, an opacity, a border lighting up - take a gentler
     * standard curve, because there is no mass to accelerate.
     *
     * The shell had neither, and the default is what hurt: 83 of its 89 colour
     * transitions and 31 of its 44 number transitions set no easing at all,
     * and Qt's default for an unspecified animation is Easing.Linear. A linear
     * colour fade has no attack - it starts at full rate and stops dead - and
     * that flat, unweighted quality across every hover in the interface is the
     * thing that reads as wrong however carefully each widget was tuned.
     *
     * --- what is NOT taken from Material
     *
     * The ripple, which is a touch idiom and says nothing on a pointer. The
     * springy overshoot - Material's expressive spring settles like sprung
     * plastic, and this shell is meant to read as something machined. And the
     * durations, which are sized for a phone app; a desktop shell answering a
     * pointer has to be quicker than a screen transition.
     *
     * So: Material's TIMING discipline, with a mechanical arrival instead of a
     * bouncy one.
     */

    /*
     * --- curves, as cubic beziers
     *
     * Spelled as control points rather than picked out of Qt's Easing enum,
     * because the enum has no entry for any of these. The four values are the
     * two control points of a unit cubic, exactly as CSS cubic-bezier() takes
     * them; the trailing 1,1 is the end point, which Qt requires spelled out.
     *
     * The first three are Material's published tokens. The fourth is ours.
     */

    // md.sys.motion.easing.standard - cubic-bezier(0.2, 0, 0, 1).
    // Anything that changes without moving: colour, opacity, a border coming
    // up under the cursor. Eases in gently, arrives flat.
    readonly property var curveEffects: [0.2, 0.0, 0.0, 1.0, 1, 1]

    // md.sys.motion.easing.emphasized-decelerate - cubic-bezier(0.05, 0.7, 0.1, 1).
    // Arrivals. Most of the distance is covered early and the last few pixels
    // take the rest of the time, so a surface is readable well before it has
    // finished settling.
    readonly property var curveEnter: [0.05, 0.7, 0.1, 1.0, 1, 1]

    // md.sys.motion.easing.emphasized-accelerate - cubic-bezier(0.3, 0, 0.8, 0.15).
    // Departures. Hesitates for a frame and then leaves in a hurry, which is
    // what makes a dismissal feel obeyed rather than waited out.
    readonly property var curveExit: [0.3, 0.0, 0.8, 0.15, 1, 1]

    /*
     * Ours, and the one that carries the house style.
     *
     * A zero horizontal lead-in means it is already at speed on the first
     * frame - no ramp, no wind-up - and the second control point pins it hard
     * against the end so it stops rather than drifts. Material's emphasized
     * curve rolls into place; this one travels and then locks, which is the
     * difference between something sprung and something driven.
     *
     * Used for the shell's own signature arrivals. Everything else takes one
     * of the three above.
     */
    readonly property var curveMechanical: [0.0, 0.85, 0.12, 1.0, 1, 1]

    /*
     * --- durations, by how much is changing
     *
     * Material's insight here is that the scale is indexed by the SIZE of the
     * change, not by which widget is making it: a colour swap and a full-panel
     * entrance are different lengths because they are different distances, not
     * because one is a button and the other is a drawer.
     *
     * The numbers are tightened from Material's - its short4 is 200ms and its
     * medium4 is 400ms, which are right for a phone screen transition and slow
     * for a shell that has to keep up with a pointer.
     */
    readonly property int durState:  dur(120)   // colour, opacity, a state layer
    readonly property int durSmall:  dur(180)   // a control resizing, a row moving
    readonly property int durMedium: dur(260)   // a popup, a tooltip, a toast
    readonly property int durLarge:  dur(380)   // a full panel crossing the screen

    /*
     * durFast is the shell's hover-and-state speed, and is the state token
     * under its old name - 124 call sites use it and they all mean "answer the
     * pointer".
     *
     * Every pointer-driven change - a fill lighting up under the cursor, a
     * label going from dim to bright, a selection moving down a list - runs on
     * this one number, so the whole interface answers at the same rate. Long
     * enough not to snap, short enough that the control still feels attached to
     * the hand moving over it: past about 150ms a hover begins to lag the
     * cursor and reads as the shell thinking rather than responding.
     *
     * There is deliberately no second token for hover. Two names within twenty
     * milliseconds of each other is how an interface ends up with half its
     * controls answering at one speed and half at another.
     */
    readonly property int durFast:    durState
    readonly property int durNormal:  dur(220)
    readonly property int durSlow:    durLarge

    /*
     * --- leaving is quicker than arriving
     *
     * The other half of the asymmetry. An entrance is allowed its full
     * duration because it is showing you something new; an exit is answering
     * an instruction you have already given, and every millisecond of it is
     * spent between deciding and being finished.
     *
     * Two thirds is the point where a dismissal stops feeling like it is being
     * played back at you and still reads as motion rather than a cut.
     */
    readonly property real exitScale: 0.65

    function exitDuration(enterMs) {
        return Math.max(reducedMotion ? 0 : 1, Math.round(enterMs * exitScale));
    }

    /*
     * --- the press state layer
     *
     * Material draws interaction state as a translucent wash of the accent
     * over the surface at a fixed opacity, rather than each control inventing
     * its own pressed colour. That is what makes a Material interface react
     * consistently, and it is taken here for the press - see Common/NotchRect,
     * which composites it into the painted shape so every control in the shell
     * acknowledges a click without any of them being edited.
     *
     * Material's value for pressed is 0.10 and it separates press from hover
     * with a ripple. With no ripple the press has to carry itself, so it steps
     * up.
     *
     * Only the press is a token. Material's ladder also covers hover, focus,
     * selected and dragged, and those are NOT here on purpose: this shell
     * already expresses hover and selection per control, tuned per surface -
     * a quick settings tile lights to 0.12 and a button to 0.18 - and
     * flattening all of that onto one number is a visible change to every
     * control in the interface rather than a refactor. A token nothing uses is
     * just a comment that looks like code, so until that is worth doing, the
     * ladder is one rung.
     */
    readonly property real statePressed: 0.16

    // Kept for the handful of sites that still name an Easing enum directly.
    readonly property int easeOut: Easing.OutExpo
    readonly property int easeSnap: Easing.OutCubic

    /*
     * --- named curves, for the Animations pane
     *
     * What a person picks in Control Center -> Animations. The set is
     * deliberately small and named for what the motion DOES rather than for
     * its mathematics: "decelerate" says which end of the movement the time is
     * spent at, where "ease-out" only says so to someone who already knows.
     *
     * Every name resolves to one of the beziers above, so a category set by
     * hand gets the same quality of curve as the defaults do.
     */
    readonly property var curveNames: [
        "mechanical", "emphasized", "decelerate", "accelerate", "linear"
    ]

    /*
     * The older names are still accepted, because they are sitting in people's
     * settings files and a config that silently stopped matching its own
     * labels would be worse than a slightly long switch.
     *
     * "spring" is the one that changed meaning rather than just being renamed.
     * It was Easing.OutBack - a real overshoot, the surface travelling past its
     * mark and settling back - and it was the default for notifications, so
     * every toast in the shell arrived with a bounce. That is Material's
     * expressive spring, and it is the single thing in this whole system that
     * most obviously did not belong: it reads as sprung plastic, and nothing
     * else in the interface behaves that way. It now resolves to the arrival
     * curve, which is quick and firm and has no rebound in it.
     */
    function curveBezier(name) {
        switch (name) {
        case "mechanical":  return curveMechanical;
        case "linear":      return [0.0, 0.0, 1.0, 1.0, 1, 1];

        case "decelerate":
        case "snap":
        case "spring":
        case "ease-out":    return curveEnter;

        case "accelerate":
        case "sharp":
        case "ease-in":     return curveExit;

        // "emphasized", "standard", "ease", "ease-in-out" and anything
        // unrecognised.
        default:            return curveEffects;
        }
    }

    // Every curve in the shell is a bezier now; the type is the same for all
    // of them and the shape lives entirely in the control points.
    function curveType(name) { return Easing.Bezier; }

    /*
     * Which of the offered names a stored value corresponds to.
     *
     * A config written before the rename holds "snap" or "ease-out", which
     * still RESOLVE correctly above but are not in the list the picker offers -
     * so the Curve control would come up with nothing selected on a category
     * the person had customised, and look broken. This maps the old name onto
     * the option that now means the same thing.
     */
    function curveCanonical(name) {
        if (curveNames.indexOf(name) !== -1) return name;
        switch (name) {
        case "snap": case "spring": case "ease-out":  return "decelerate";
        case "sharp": case "ease-in":                 return "accelerate";
        default:                                      return "emphasized";
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
    /*
     * --- the defaults, re-cut
     *
     * Two things changed here beyond the renaming.
     *
     * Notifications no longer spring. "spring" was Easing.OutBack - the toast
     * overshooting its mark and rebounding - and it was the one piece of
     * motion in the shell that belonged to a different design language
     * entirely. Nothing else in the interface rebounds, so every toast read as
     * though it had been imported from somewhere softer.
     *
     * And duration now tracks how far a thing travels, which is Material's
     * rule and was not being applied: the tooltip and the Control Center used
     * to open over almost the same span, despite one being a label appearing
     * under the pointer and the other a full-height panel crossing the screen.
     * The small, frequent surfaces got quicker; the large ones got longer.
     *
     * "mechanical" is kept for the three surfaces that carry the house style -
     * the dock, the OSD and the quick settings drawer. Those are the ones
     * meant to read as hardware.
     */
    /*
     * --- the defaults
     *
     * Direction is "auto" everywhere it means anything, because where a
     * surface comes from is now read off where it sits - see the placement
     * notes above. The only two that are not "auto" have no placement to read:
     * a wallpaper swap and a palette change are crossfades that happen
     * everywhere at once.
     *
     * Notifications no longer spring. "spring" was Easing.OutBack - the toast
     * overshooting its mark and rebounding - and it was the one piece of
     * motion in the shell that belonged to a different design language
     * entirely. Nothing else in the interface rebounds.
     *
     * Duration tracks how far a thing travels, which is Material's rule and
     * was not being applied: the tooltip and the Control Center used to open
     * over almost the same span, despite one being a label appearing under the
     * pointer and the other a full-height panel crossing the screen.
     *
     * "mechanical" is kept for the three surfaces that carry the house style -
     * the dock, the OSD and the quick settings drawer. Those are the ones
     * meant to read as hardware.
     */
    readonly property var motionDefaults: ({
        "dock":          ({ curve: "mechanical", duration: 200, direction: "auto", origin: "auto" }),
        "bar":           ({ curve: "decelerate", duration: 160, direction: "auto", origin: "auto" }),
        "osd":           ({ curve: "mechanical", duration: 200, direction: "auto", origin: "auto" }),
        "notifications": ({ curve: "decelerate", duration: 260, direction: "auto", origin: "auto" }),
        "quickSettings": ({ curve: "mechanical", duration: 240, direction: "auto", origin: "auto" }),
        // The largest surface in the shell, so the longest of these.
        "controlCenter": ({ curve: "emphasized", duration: 280, direction: "auto", origin: "auto" }),
        "menus":         ({ curve: "decelerate", duration: 200, direction: "auto", origin: "auto" }),
        "launcher":      ({ curve: "emphasized", duration: 240, direction: "auto", origin: "auto" }),
        // Small, and it appears under the pointer rather than being asked for,
        // so it moves quicker than a menu and travels less far.
        "tooltip":       ({ curve: "decelerate", duration: 140, direction: "auto", origin: "auto" }),
        // No placement and no edge: a wallpaper swap happens across the whole
        // screen at once, so it is the one entry here that is genuinely a
        // crossfade rather than a movement.
        "wallpaper":     ({ curve: "emphasized", duration: 600, direction: "fade", origin: "auto" }),
        // The palette menu, not the palette change - a surface like any other,
        // and it was set to fade only because direction used to be a taste
        // rather than a placement. It comes out of its host now.
        "theme":         ({ curve: "emphasized", duration: 240, direction: "auto", origin: "auto" })
    })

    readonly property var motionCategories: [
        "dock", "bar", "osd", "notifications", "quickSettings",
        "controlCenter", "launcher", "menus", "tooltip", "wallpaper", "theme"
    ]

    /*
     * ======================================================================
     * PLACEMENT -> MOTION
     * ======================================================================
     *
     * Where a surface sits decides where it comes from. A panel against the
     * left edge enters from the left; one hanging from the top drops down; one
     * floating dead centre has no edge to belong to and falls back to the top.
     *
     * This replaces asking. Direction used to be a per-category setting, which
     * meant the OSD could be placed bottom-right and told to enter from the
     * left - a surface travelling away from the edge it lives on, which reads
     * as a mistake because it is one. The position already contains the
     * answer, so the answer is derived rather than configured.
     *
     * --- the rule, and why this order
     *
     * A horizontal edge wins over a vertical one. A notification in the top
     * right is against two edges, and coming in from the side is what every
     * other desktop does with that corner - sliding down would be
     * indistinguishable from the top-centre case and would lose the corner's
     * own character. Only when a surface is horizontally centred does the
     * vertical edge get to speak, and only when it is centred on both does the
     * fallback apply.
     *
     * --- naming
     *
     * An edge here is WHERE THE SURFACE COMES FROM, always, on both axes. That
     * needs saying because the old vocabulary was inconsistent about it:
     * "left" and "right" named the side a surface started on, while "up" and
     * "down" named the direction it travelled - so "down" and "top" meant the
     * same thing and nothing in the names said so. Every edge is a source now.
     */
    readonly property var edgeNames: ["top", "bottom", "left", "right"]

    function originFor(horizontal, vertical) {
        if (horizontal === "left")  return "left";
        if (horizontal === "right") return "right";
        if (vertical === "top")     return "top";
        if (vertical === "bottom")  return "bottom";
        // Centred on both axes: nothing to emerge from, so it drops in.
        return "top";
    }

    /*
     * The same thing for the surfaces that store their placement as one string
     * - "bottom-center", "top-right". Anything the string does not say is
     * treated as centred, so a bare "top" or "center" reads correctly too.
     */
    function originForPlacement(placement) {
        const p = String(placement || "");
        const h = p.indexOf("left") !== -1 ? "left"
                : p.indexOf("right") !== -1 ? "right" : "center";
        const v = p.indexOf("top") !== -1 ? "top"
                : p.indexOf("bottom") !== -1 ? "bottom" : "middle";
        return originFor(h, v);
    }

    /*
     * ----------------------------------------------------------------------
     * WHERE A SURFACE INHERITS ITS EDGE FROM
     * ----------------------------------------------------------------------
     *
     * Some surfaces have a placement of their own - the OSD and the toasts sit
     * somewhere on the screen and that is the whole answer. The rest do not:
     * the launcher, the Control Center, the theme and session menus all appear
     * in the middle of the display, so "where they sit" says nothing about
     * where they should come from.
     *
     * What those have instead is the thing you pressed to get them. A launcher
     * opened from a dock at the bottom of the screen should come up out of that
     * dock, and the same launcher on a left-hand dock should come out of the
     * left. So they inherit the edge of whatever hosts them, and moving the
     * dock moves all of them at once without any of it being configured twice.
     *
     * A dock that is switched off still hosts nothing, so anything that names
     * it falls back to the bar - which is where those buttons live when there
     * is no dock to put them on.
     */
    function inheritedEdge(host) {
        switch (host) {
        case "dock":
            return Settings.dock.enabled ? Settings.dock.position
                                         : Settings.bar.position;
        case "bar":
            return Settings.bar.position;
        }
        return "top";
    }

    /*
     * --- Position, and what Auto means
     *
     * Every motion category carries a Position, and on Auto it takes the
     * answer from wherever the surface belongs: its own placement for the ones
     * that have one, its host's edge for the ones that do not. Anything else
     * is a deliberate override and wins outright.
     *
     * `originOr` is the general form - a category plus whatever Auto should
     * resolve to for that particular surface. `originOf` is the common case,
     * where Auto means "inherit from the thing that opened me".
     */
    function originOr(category, fallbackEdge) {
        const o = motionOf(category, "origin");
        return (o && o !== "auto") ? edgeOf(o) : fallbackEdge;
    }

    function originOf(category, host) {
        return originOr(category, originFromEdge(inheritedEdge(host)));
    }

    // What the Position control offers. "auto" first, because it is the answer
    // for almost every surface almost all of the time.
    readonly property var originNames: ["auto", "top", "bottom", "left", "right"]

    /*
     * The edge OPPOSITE a bar or dock, which is the one a surface anchored to
     * that bar emerges from. A widget popup under a top bar comes down out of
     * it; the same popup under a bottom bar rises out of it.
     */
    /*
     * An old direction name as the edge it always meant.
     *
     * "up" described a surface travelling upward, which is one that started
     * BELOW its resting place - so it came from the bottom. "down" likewise
     * came from the top. Anything already named for an edge, and the effect
     * names, pass straight through.
     */
    function edgeOf(direction) {
        switch (direction) {
        case "up":   return "bottom";
        case "down": return "top";
        default:     return direction;
        }
    }

    function originFromEdge(edge) {
        switch (edge) {
        case "top":    return "top";
        case "bottom": return "bottom";
        case "left":   return "left";
        case "right":  return "right";
        }
        return "top";
    }

    /*
     * --- what is left to choose
     *
     * Direction is not a setting any more. Where a surface comes from is read
     * off where it sits, so the old list - auto, fade, scale, up, down, left,
     * right, glitch - was four edges nobody should be picking mixed in with
     * three effects and an "auto" that only sometimes applied. Choosing "left"
     * for a panel docked on the right was a thing the interface let you do,
     * and it looked like what it was.
     *
     * What remains is genuinely a choice, because it is not about direction at
     * all - it is HOW a surface arrives once it knows where from:
     *
     *   auto    slide in from its own edge. The default, and positional.
     *   fade    no movement, opacity only.
     *   scale   grow into place, for a surface with no edge to speak of.
     *   glitch  the house kick: a hard scale and a sideways snap.
     *
     * The edge names are still accepted from a settings file that predates
     * this, and still work - they just are not offered.
     */
    readonly property var entryStyles: ["auto", "fade", "scale", "glitch"]

    // A stored value as one of the offered styles, so a config written before
    // direction became positional does not show a blank control. Any edge
    // means "it was picking a direction", and picking a direction is now the
    // job of the placement.
    function entryCanonical(style) {
        if (entryStyles.indexOf(style) !== -1) return style;
        return "auto";
    }

    function motionOf(category, key) {
        const def = motionDefaults[category];
        if (!def) return key === "duration" ? 220 : (key === "curve" ? "ease" : "fade");
        const set = Settings.animations.motion ? Settings.animations.motion[category] : undefined;
        if (set && set[key] !== undefined && set[key] !== null) return set[key];
        return def[key];
    }

    function curveFor(category)     { return Easing.Bezier; }
    function bezierFor(category)    { return curveBezier(motionOf(category, "curve")); }
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
