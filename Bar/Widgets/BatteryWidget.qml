import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Battery level as one glyph, plus the number.
 *
 * This used to be a six-segment SegmentBar with a lightning bolt next to it
 * when charging. Two things were wrong with that. A six-segment meter cannot
 * show more than six states, so it sat still through sixteen percent of
 * discharge and then dropped a whole block - which reads as the battery falling
 * off a cliff rather than as it draining. And the bolt was a second item
 * carrying information the meter did not: the meter looked identical charging
 * and discharging, so the bolt was the only thing saying which, in a widget
 * where the direction matters more than the level.
 *
 * The Material battery set in the Nerd Fonts solves both at once. It has a step
 * every ten percent and a separate run for charging, so one glyph carries the
 * level and the direction together, in the width the bolt alone used to take.
 * The table lives in Services/Battery.
 *
 * --- why this file is BatteryWidget and not Battery
 *
 * Because Services/Battery.qml is a singleton called Battery, and this file
 * imports it. A component may not share a name with a type it imports: inside
 * Battery.qml the word `Battery` would name both the singleton and the file
 * itself, which is a type referring to itself. Nothing in the shell could then
 * resolve either of them, and the failure surfaces a long way from here - the
 * first thing that broke was the desktop widget, which had never heard of this
 * file and only wanted the singleton.
 *
 * SysMonWidget is named the way it is for exactly this reason, next to the
 * SysMon singleton. Every other bar widget keeps its plain name because no
 * service shares it. The widget id in settings.json is still "battery".
 */
BarItem {
    id: root

    readonly property bool showPercentage: (config && config.showPercentage !== undefined)
        ? config.showPercentage : true

    visible: Battery.present
    accentColor: Battery.critical ? Theme.danger : Theme.accent
    tooltip: Battery.statusLabel

    /*
     * --- the low-battery pulse
     *
     * Under ten percent and off the cable, the glyph breathes between the two
     * crimsons rather than sitting in one of them. A static colour is a state;
     * something moving in the corner of the eye is a summons, and this is the
     * one reading in the bar that has earned the right to interrupt.
     *
     * Driven by a timer flipping a boolean, with a Behavior doing the fade,
     * rather than by an infinite animation on the colour itself. Two reasons.
     * A `SequentialAnimation on color` is a value source: it replaces the
     * binding to Battery.tint for as long as it exists, and when it stops the
     * binding is gone rather than restored, so the glyph would keep whichever
     * crimson the last frame happened to leave it on after the battery was back
     * on the cable. And an infinite animation anywhere in the tree pins the
     * render loop at the display's refresh rate - which is the correct trade
     * here, because the alternative is missing the warning, but it should be
     * bounded by the condition rather than by the widget existing.
     */
    readonly property bool pulsing: Battery.critical && !Theme.reducedMotion
    property bool pulseHigh: false

    Timer {
        running: root.pulsing
        interval: 620
        repeat: true
        onTriggered: root.pulseHigh = !root.pulseHigh
    }

    // Parked on the bright end when the pulse stops, so the glyph never settles
    // on the dim crimson and reads as a colour choice rather than as a warning
    // that has ended.
    onPulsingChanged: if (!pulsing) pulseHigh = false

    Row {
        spacing: Theme.space2
        height: parent.height

        CyberText {
            anchors.verticalCenter: parent.verticalCenter
            text: Battery.glyph
            role: "icon"
            sizeOverride: root.cfgFontSize > 0 ? root.cfgFontSize + 2 : 0
            color: root.pulsing
                ? (root.pulseHigh ? Theme.danger : Theme.dangerDim)
                : root.cfgColor(Battery.tint)

            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: 600; easing.type: Easing.InOutSine }
            }
        }

        CyberText {
            visible: root.showPercentage
            height: parent.height
            // Reserved width for the widest reading, so the widgets to the left
            // do not shift as the battery crosses 100 or 10.
            width: 38
            horizontalAlignment: Text.AlignRight
            text: Battery.percent + "%"
            role: "mono"
            sizeOverride: root.cfgFontSize
            weightOverride: root.cfgFontWeight
            color: root.cfgColor(Theme.textDim)
        }
    }
}
