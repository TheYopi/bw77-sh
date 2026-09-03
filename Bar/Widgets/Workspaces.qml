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
    readonly property bool showLabels: labelMode !== "none"

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
        if (labelMode === "roman") return roman(ws.index);
        return String(ws.name);
    }
    readonly property bool scrollToSwitch: (config && config.scrollToSwitch !== undefined)
        ? config.scrollToSwitch : true
    readonly property bool activeScreenOnly: (config && config.activeScreenOnly !== undefined)
        ? config.activeScreenOnly : true

    readonly property var list: {
        if (!activeScreenOnly || !screenRef) return Compositor.workspaces;
        const filtered = Compositor.workspaces.filter(
            w => w.output === "" || w.output === screenRef.name);
        return filtered.length ? filtered : Compositor.workspaces;
    }

    // Interactive so the wheel is caught, but clicks belong to the pips - each
    // one focuses its own workspace.
    interactive: true
    captureClicks: false
    hPadding: Theme.space2

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
                easing.type: Theme.curveFor("bar")
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
                easing.type: Theme.curveFor("bar")
            }
        }

        Repeater {
            model: root.list

            Item {
                id: pip
                required property var modelData

                readonly property bool focused: modelData.focused
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
                    NumberAnimation {
                        duration: Theme.durationFor("bar")
                        easing.type: Theme.curveFor("bar")
                    }
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
                        ColorAnimation {
                            duration: Theme.durationFor("bar")
                            easing.type: Theme.curveFor("bar")
                        }
                    }
                    Behavior on strokeColor {
                        ColorAnimation {
                            duration: Theme.durationFor("bar")
                            easing.type: Theme.curveFor("bar")
                        }
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

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Compositor.focusWorkspace(pip.modelData)
                }
            }
        }
}
}
