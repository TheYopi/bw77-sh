pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config

/*
 * Pushes the shell palette out to other applications.
 *
 * Colours are handed to the renderer as command arguments rather than written
 * to a state file first. That removes the jq dependency, removes a whole class
 * of quoting problems with heredocs, and means there is no intermediate file
 * that can disagree with the live palette.
 */
Singleton {
    id: root

    readonly property string templatesDir: `${Quickshell.shellDir}/Assets/Templates`

    property bool applying: false
    property string lastResult: ""
    property bool lastFailed: false

    // Terminal templates want a 16-colour ANSI ramp; derive one from the palette
    // so every terminal target gets a full set without the user defining them.
    // Resolves a role-or-literal pair to a colour.
    function pick(role, custom) {
        if (custom && custom !== "") return custom;
        return hexOf(Theme.c(role));
    }

    function borderValues() {
        const b = Settings.borders;
        const activeFrom = pick(b.activeFromRole, b.activeFromCustom);
        // With gradients off, both stops are the same colour, so one template
        // covers both cases without needing a conditional.
        const activeTo = b.gradient ? pick(b.activeToRole, b.activeToCustom) : activeFrom;

        return {
            "borderActiveFrom": activeFrom,
            "borderActiveTo":   activeTo,
            "borderInactive":   pick(b.inactiveRole, b.inactiveCustom),
            "borderUrgent":     pick(b.urgentRole, b.urgentCustom),
            "borderWidth":      String(b.width),
            "borderRadius":     String(b.radius),
            "borderAngle":      String(b.gradientAngle)
        };
    }

    /*
     * A terminal needs eight distinguishable hues. A shell palette has about
     * four, so the old ramp filled the gaps by repeating roles - green and
     * bright green were the same colour, so were magenta and bright magenta,
     * and blue was accentDim, which is deliberately muddy. The result looked
     * washed out no matter how vivid the palette was.
     *
     * These are built from canonical terminal hues instead, wearing the
     * palette's own saturation and lightness. Distinct where a terminal needs
     * distinction, still recognisably the theme, and `vibrance` decides how
     * loud it gets.
     */
    readonly property bool lightPalette: {
        const c = Theme.bgBase;
        // Rec. 709 luma; a light surface needs dark text colours, not bright.
        return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) > 0.5;
    }

    /*
     * Formats a colour as exactly #rrggbb.
     *
     * Qt may stringify a colour with an alpha channel as #aarrggbb, and the
     * template renderer only derives its .hex and .rgb forms from a six-digit
     * value - an eight-digit one would silently leave {{x.hex}} unsubstituted
     * in every terminal config. Building the string by hand removes the doubt.
     */
    function hexOf(c) {
        // Theme.c() hands back the raw string from the palette file, while
        // Qt.hsla() hands back a colour object. Both arrive here, and treating
        // a string as a colour produced "#NANNANNAN" in every generated config.
        if (typeof c === "string") {
            const t = c.trim();

            // #rrggbb - already what we want.
            const six = t.match(/^#([0-9a-fA-F]{6})$/);
            if (six) return "#" + six[1].toUpperCase();

            // #aarrggbb - drop the alpha, which no target template accepts.
            const eight = t.match(/^#([0-9a-fA-F]{2})([0-9a-fA-F]{6})$/);
            if (eight) return "#" + eight[2].toUpperCase();

            // #rgb shorthand.
            const three = t.match(/^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$/);
            if (three) {
                return "#" + (three[1] + three[1] + three[2] + three[2]
                            + three[3] + three[3]).toUpperCase();
            }

            // A named colour or anything else: let Qt resolve it.
            return hexOf(Qt.color(t));
        }

        function part(v) {
            const n = Math.max(0, Math.min(255, Math.round((v || 0) * 255)));
            return (n < 16 ? "0" : "") + n.toString(16).toUpperCase();
        }

        if (c === undefined || c === null || typeof c.r !== "number")
            return "#FF00FF";              // loud, so a miss is obvious

        return "#" + part(c.r) + part(c.g) + part(c.b);
    }

    function ansiHue(hue, bright) {
        const v = Settings.appTheming.vibrance;

        const accentHue = Theme.accent.hslHue * 360;
        const accentSat = Theme.accent.hslSaturation;

        /*
         * Each canonical hue is pulled part-way toward the palette's accent.
         *
         * Saturation alone is not enough to make a terminal feel like the
         * theme: once every palette's accent is fully saturated, they all
         * export the same rainbow and a Militech terminal is indistinguishable
         * from an Arasaka one. Tinting the hues keeps them recognisably the
         * theme's own.
         *
         * The pull is capped at 20 degrees, which is far enough to read as
         * tinted and short enough that red is still red. An achromatic palette
         * has no hue worth pulling toward, so it is left alone.
         */
        let h = hue;
        if (accentSat >= 0.15) {
            let delta = accentHue - hue;
            while (delta > 180) delta -= 360;
            while (delta < -180) delta += 360;

            const shift = Math.max(-20, Math.min(20, delta * 0.25));
            h = (hue + shift + 360) % 360;
        }

        // Saturation follows the palette's own accent, so a restrained theme
        // stays restrained and a loud one gets louder.
        const base = Math.max(accentSat, 0.45);
        const sat = Math.max(0, Math.min(1, base * v));

        let light;
        if (lightPalette) light = bright ? 0.34 : 0.42;
        else               light = bright ? 0.70 : 0.56;

        return hexOf(Qt.hsla(h / 360, sat, light, 1));
    }

    /*
     * Picks whichever text colour is actually legible on a given background.
     *
     * Templates cannot branch, so a fixed choice has to work for all eleven
     * palettes - and none does. textOnAccent is right on accentDim for most
     * themes but falls to 2.3:1 on Maelstrom, while text is right there and
     * wrong elsewhere. Deciding here, per palette, means a template can just
     * say {{onAccentDim}} and be correct everywhere.
     */
    function relativeLuminance(c) {
        function channel(v) {
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
    }

    function contrast(a, b) {
        const la = relativeLuminance(a);
        const lb = relativeLuminance(b);
        const hi = Math.max(la, lb);
        const lo = Math.min(la, lb);
        return (hi + 0.05) / (lo + 0.05);
    }

    function bestTextOn(backgroundRole) {
        const bg = Qt.color(String(Theme.c(backgroundRole)));
        const dark = Qt.color(String(Theme.c("textOnAccent")));
        const light = Qt.color(String(Theme.c("text")));
        return contrast(dark, bg) >= contrast(light, bg)
            ? hexOf(Theme.c("textOnAccent"))
            : hexOf(Theme.c("text"));
    }

    // Legible foreground for every role a template might use as a background.
    function contrastPairs() {
        return {
            "onAccent":     bestTextOn("accent"),
            "onAccentDim":  bestTextOn("accentDim"),
            "onAccentGlow": bestTextOn("accentGlow"),
            "onDanger":     bestTextOn("danger"),
            "onDangerDim":  bestTextOn("dangerDim"),
            "onWarn":       bestTextOn("warn"),
            "onGold":       bestTextOn("gold"),
            "onSuccess":    bestTextOn("success"),
            "onMagenta":    bestTextOn("magenta"),
            "onSurface":    bestTextOn("bgRaised")
        };
    }

    function ansiRamp() {
        const t = (r) => hexOf(Theme.c(r));

        return {
            // Black and white ends stay tied to the surface, so the terminal
            // still sits in the palette rather than floating above it.
            "ansi0":  t("bgDeep"),     "ansi8":  t("textMuted"),

            "ansi1":  ansiHue(0,   false), "ansi9":  ansiHue(0,   true),
            "ansi2":  ansiHue(120, false), "ansi10": ansiHue(120, true),
            "ansi3":  ansiHue(48,  false), "ansi11": ansiHue(48,  true),
            "ansi4":  ansiHue(215, false), "ansi12": ansiHue(215, true),
            "ansi5":  ansiHue(295, false), "ansi13": ansiHue(295, true),
            "ansi6":  ansiHue(180, false), "ansi14": ansiHue(180, true),

            "ansi7":  t("textDim"),    "ansi15": t("text"),

            "termBg": t("bgBase"),     "termFg": t("text"),
            "cursor": t("accent"),     "selection": t("bgActive")
        };
    }

    function enabledTargets() {
        const t = Settings.appTheming.targets;
        const out = [];
        for (const key in t) {
            if (t[key] === true) out.push(key);
        }
        return out;
    }

    function apply() {
        if (!Settings.appTheming.enabled) {
            lastResult = "App theming is switched off.";
            lastFailed = true;
            return;
        }

        const targets = enabledTargets();
        if (targets.length === 0) {
            lastResult = "No applications selected.";
            lastFailed = true;
            return;
        }

        const args = ["bash", `${Quickshell.shellDir}/Scripts/apply-theme.sh`,
                      root.templatesDir, targets.join(",")];

        // Every palette role, then the derived terminal colours.
        for (const key in Theme.fallback)
            args.push(`${key}=${hexOf(Theme.c(key))}`);

        const ramp = ansiRamp();
        for (const key in ramp)
            args.push(`${key}=${ramp[key]}`);

        // Foregrounds chosen for legibility against each role.
        const pairs = contrastPairs();
        for (const key in pairs)
            args.push(`${key}=${pairs[key]}`);

        // Border settings are compositor config rather than palette, but they
        // ride the same substitution pass.
        const b = borderValues();
        for (const key in b)
            args.push(`${key}=${b[key]}`);

        /*
         * The font names, so a template can set type as well as colour.
         *
         * The Discord template needs this to be self-contained: the theme it
         * was modelled on pulled a webfont from Google Fonts on every launch,
         * and the shell's own font is already installed locally by definition.
         * apply-theme.sh validates these separately from the colours, since a
         * font name has spaces in it and would fail the numeric check.
         */
        args.push(`fontUI=${Settings.general.fontUI}`);
        args.push(`fontIcons=${Settings.general.fontIcons}`);

        // Live reload travels as a plain argument, so the exact command can be
        // reproduced by hand when debugging.
        if (!Settings.appTheming.liveReload)
            args.push("BW77_NO_LIVE_RELOAD=1");

        applying = true;
        lastFailed = false;
        renderer.exec(args);
    }

    Process {
        id: renderer

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l !== "");
                if (lines.length) root.lastResult = lines[lines.length - 1];
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") {
                    root.lastResult = text.trim().split("\n")[0];
                    root.lastFailed = true;
                }
            }
        }

        onExited: (code) => {
            root.applying = false;
            if (code !== 0) {
                root.lastFailed = true;
                if (root.lastResult === "")
                    root.lastResult = `Renderer exited with code ${code}.`;
            }
        }
    }

    // Re-apply whenever the palette or the target list changes.
    Connections {
        target: Theme
        function onPaletteChanged() { debounce.restart(); }
    }

    Connections {
        target: Settings.theme
        function onOverridesChanged() { debounce.restart(); }
    }

    Connections {
        target: Settings.borders
        function onManageChanged() { debounce.restart(); }
        function onGradientChanged() { debounce.restart(); }
        function onWidthChanged() { debounce.restart(); }
        function onRadiusChanged() { debounce.restart(); }
        function onActiveFromRoleChanged() { debounce.restart(); }
        function onActiveToRoleChanged() { debounce.restart(); }
        function onInactiveRoleChanged() { debounce.restart(); }
        function onActiveFromCustomChanged() { debounce.restart(); }
        function onActiveToCustomChanged() { debounce.restart(); }
        function onInactiveCustomChanged() { debounce.restart(); }
        function onGradientAngleChanged() { debounce.restart(); }
    }

    Connections {
        target: Settings.appTheming
        function onTargetsChanged() { debounce.restart(); }
        function onVibranceChanged() { debounce.restart(); }
        function onEnabledChanged() { if (Settings.appTheming.enabled) debounce.restart(); }
    }

    Timer {
        id: debounce
        interval: 400
        onTriggered: if (Settings.appTheming.enabled) root.apply()
    }
}
