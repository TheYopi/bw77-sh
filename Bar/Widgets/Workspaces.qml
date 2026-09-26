import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Workspace pips. Focused reads as a wide cyan slab, occupied as a dim outline,
 * empty as a hairline - the same three-state language the game uses for slots.
 */
BarItem {
    id: root

    // none | numbers | roman
    readonly property string labelMode: {
        if (config && config.labelMode) return String(config.labelMode);
        // Migrate the old boolean without losing anyone's setting.
        if (config && config.showNumbers === true) return "numbers";
        return "none";
    }
    /*
     * The compact style always labels its pip.
     *
     * With labels off, the whole widget would be one slab in the accent colour
     * - which tells you a workspace is focused, something that is true by
     * definition and was never in question. The number is the entire content
     * of that style, so "none" falls back to numbers there rather than drawing
     * an indicator with nothing in it.
     */
    readonly property bool showLabels: root.singleMode || labelMode !== "none"

    readonly property string effectiveLabelMode:
        (root.singleMode && labelMode === "none") ? "numbers" : labelMode

    // Font size drives the pip geometry too, otherwise a larger number simply
    // overflows the slab it sits in. The size itself is the bar's now; only
    // the fallback is local, because a pip label is a notch smaller than the
    // running text around it.
    readonly property real labelSize: cfgFontSize > 0 ? cfgFontSize : Theme.fontMicro

    property bool boldLabels: (config && config.boldLabels !== undefined)
        ? config.boldLabels : false

    /*
     * Heavier than the rest of the bar, by a step rather than to a fixed Bold.
     *
     * A pip label is one or two characters inside a slab and needs the extra
     * weight to hold its own against a wide fill behind it - that is why this
     * switch exists and why it stays. Pinning it to Font.Bold, as it was,
     * meant that once the bar had its own weight slider the two would fight:
     * set the bar to Bold and the workspace labels would stop looking
     * emphasised, set it to Light and they would jump three steps. Adding to
     * whatever the bar is set to keeps the relationship intact across the
     * whole range, and Qt clamps to 900 at the top.
     */
    readonly property int labelWeight: root.boldLabels
        ? Math.min(900, root.cfgFontWeight + 200)
        : root.cfgFontWeight

    function roman(n) {
        const num = parseInt(n);
        if (isNaN(num) || num <= 0 || num > 3999) return String(n);
        const map = [[1000,"M"],[900,"CM"],[500,"D"],[400,"CD"],[100,"C"],[90,"XC"],
                     [50,"L"],[40,"XL"],[10,"X"],[9,"IX"],[5,"V"],[4,"IV"],[1,"I"]];
        let v = num, out = "";
        for (let i = 0; i < map.length; i++) {
            while (v >= map[i][0]) { out += map[i][1]; v -= map[i][0]; }
        }
        return out;
    }

    function labelFor(ws) {
        if (root.effectiveLabelMode === "roman") return roman(ws.index);
        return String(ws.name);
    }
    readonly property bool scrollToSwitch: (config && config.scrollToSwitch !== undefined)
        ? config.scrollToSwitch : true
    readonly property bool activeScreenOnly: (config && config.activeScreenOnly !== undefined)
        ? config.activeScreenOnly : true

    /*
     * all     - a pip per workspace, the three-state row this widget has
     *           always drawn
     * current - one pip, showing only the workspace you are on
     *
     * The wheel works the same in both. That is the point of the compact
     * style: the row of pips is a map, and if you navigate by scrolling rather
     * than by clicking then the map is costing bar width to tell you something
     * the single pip already says.
     */
    readonly property string style: (config && config.style)
        ? String(config.style) : "all"
    readonly property bool singleMode: root.style === "current"

    readonly property var list: {
        if (!activeScreenOnly || !screenRef) return Compositor.workspaces;
        const filtered = Compositor.workspaces.filter(
            w => w.output === "" || w.output === screenRef.name);
        return filtered.length ? filtered : Compositor.workspaces;
    }

    /*
     * The one workspace the compact style draws.
     *
     * `focused` is global - exactly one workspace holds the keyboard - while
     * `active` is per output, so on a second monitor's bar only `active` has
     * an answer. Preferring focused means the bar on the monitor you are
     * actually using agrees with the one you are looking at; falling back to
     * active means the other monitor's bar still shows where you left it
     * rather than going blank.
     *
     * The final fallback to the first entry is for a compositor that reports
     * neither, where an empty widget would look like a bug rather than like a
     * missing flag.
     */
    readonly property var currentWs: {
        const l = root.list;
        if (l.length === 0) return null;
        return l.find(w => w.focused) || l.find(w => w.active) || l[0];
    }

    readonly property var drawn: {
        if (!root.singleMode) return root.list;
        return root.currentWs ? [root.currentWs] : [];
    }

    // Interactive so the wheel is caught, but clicks belong to the pips - each
    // one focuses its own workspace.
    interactive: true
    captureClicks: false

    /*
     * No padding either, now that there is no frame.
     *
     * Every other widget's padding sits INSIDE its outline, so the edge the
     * eye measures the gap from is the outline itself. With the frame gone,
     * the same padding became bare space outside the pips - so the widget
     * ended up further from its neighbours than they are from each other,
     * which is the gap that was left over after the border came off.
     *
     * The pips' own edges are the widget's edges. The bar's widgetSpacing
     * still separates it from what is beside it, same as everything else.
     */
    hPadding: 0

    /*
     * No frame around the pips.
     *
     * Every other widget is text inside an outline; this one is already a row
     * of outlined slabs, so the bar's frame wrapped a border around borders
     * and added padding the neighbouring widgets do not have - the row sat in
     * a box while the clock beside it sat on the bar. The pips are their own
     * chrome.
     */
    frame: false

    onWheel: (delta) => {
        if (!scrollToSwitch || list.length === 0) return;
        let current = -1;
        for (let i = 0; i < list.length; i++) {
            if (list[i].focused) { current = i; break; }
        }
        if (current === -1) return;
        // Wheel up goes to the previous workspace, matching every tabbed UI.
        const next = delta > 0 ? current - 1 : current + 1;
        if (next < 0 || next >= list.length) return;
        Compositor.focusWorkspace(list[next]);
    }

    Row {
        id: pipRow

        spacing: 5
        height: parent.height

        /*
         * The travel IS the reflow.
         *
         * Three attempts at a separate highlight that slid between pips all
         * failed for layout reasons - a Row owns the x of everything inside it,
         * so anything trying to position itself in there is fighting the
         * positioner. Row has a built-in answer: `move` animates children to
         * their new places whenever the layout shifts. So the focused pip
         * widens, its neighbours are pushed along, and every one of them slides
         * rather than jumping. No extra item, nothing to keep in sync, and it
         * works however the list changes.
         */
        move: Transition {
            enabled: Settings.animations.workspaceMorph && !Theme.reducedMotion
            NumberAnimation {
                properties: "x,y"
                duration: Theme.durationFor("bar")
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.bezierFor("bar")
            }
        }

        // A workspace appearing or disappearing gets the same treatment rather
        // than popping into the middle of the row.
        add: Transition {
            enabled: Settings.animations.workspaceMorph && !Theme.reducedMotion
            NumberAnimation {
                properties: "opacity"
                from: 0; to: 1
                duration: Theme.durationFor("bar")
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.bezierFor("bar")
            }
        }

        Repeater {
            model: root.drawn

            Item {
                id: pip
                required property var modelData

                /*
                 * In the compact style the single pip is the current
                 * workspace by construction, so it reads as focused even when
                 * the flag it was chosen by was `active` - on a second
                 * monitor's bar, a lone pip drawn in the dim "occupied" tone
                 * would be saying it is not the one you are on, which is not
                 * what the style is for.
                 */
                readonly property bool focused: root.singleMode || modelData.focused
                readonly property bool occupied: modelData.occupied
                readonly property string label: root.labelFor(modelData)

                width: root.showLabels
                    ? Math.max(focused ? 26 : 18, numberText.implicitWidth + 10)
                    : (focused ? 26 : 12)
                // Height follows the label so a larger font is not clipped.
                height: root.showLabels
                    ? Math.max(16, Math.round(root.labelSize * 1.6))
                    : 12
                anchors.verticalCenter: parent.verticalCenter

                Behavior on width {
                    enabled: Settings.animations.workspaceMorph
                    MotionNumber { duration: Theme.durationFor("bar")
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.bezierFor("bar") }
                }

                NotchRect {
                    anchors.fill: parent
                    fillColor: pip.focused
                        ? Theme.accent
                        : (pip.occupied ? Theme.alpha(Theme.accent, 0.22) : "transparent")
                    strokeColor: pip.focused
                        ? Theme.accent
                        : (pip.occupied ? Theme.alpha(Theme.accent, 0.7) : Theme.alpha(Theme.border, 0.9))
                    notch: 4
                    notchTopLeft: true
                    notchTopRight: false
                    notchBottomRight: true
                    notchBottomLeft: false

                    /*
                     * Colour crosses over the same length as the movement.
                     * At durFast it finished well before the pips had stopped
                     * moving, so the colour change read as a separate event
                     * from the slide instead of one gesture.
                     */
                    Behavior on fillColor {
                        MotionColor { duration: Theme.durationFor("bar")
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.bezierFor("bar") }
                    }
                    Behavior on strokeColor {
                        MotionColor { duration: Theme.durationFor("bar")
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.bezierFor("bar") }
                    }
                }

                CyberText {
                    id: numberText
                    anchors.centerIn: parent
                    visible: root.showLabels
                    text: pip.label
                    role: "micro"
                    sizeOverride: root.labelSize
                    weightOverride: root.labelWeight
                    color: pip.focused ? Theme.textOnAccent
                        : (pip.occupied ? root.cfgColor(Theme.accent) : Theme.textMuted)
                }

                SoundArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Compositor.focusWorkspace(pip.modelData)
                }
            }
        }
}
}
