import QtQuick
import qs.Config

/*
 * A complete framed surface: chamfered body, border, corner ticks, scanlines,
 * noise, and an optional serial in the bottom-left. Put content in `content`.
 *
 * Use `emphasis` to move between the three weights the game uses:
 *   "quiet"  - hairline border, for grouping only
 *   "normal" - default panel
 *   "alert"  - crimson double stroke, for anything destructive or focused
 */
Item {
    id: root

    default property alias content: contentItem.data

    property string emphasis: "normal"
    /*
     * Base, not raised.
     *
     * `bgRaised` is a step lighter than the shell's background and existed for
     * blocks sitting on top of a panel. Using it for the panels themselves put
     * the Control Center, the OSD and notifications a shade off every other
     * surface - noticeable the moment two of them are on screen together.
     * Inner blocks still use bgRaised over this, which is what it is for.
     */
    property color fillColor: Theme.bgBase
    /*
     * Opaque.
     *
     * Every surface used to sit at 92-97% and let the desktop through. It reads
     * as a rendering fault rather than as a material once there is a border and
     * a fill behind it - and on a busy wallpaper the few percent of bleed lands
     * right under small text, which is where it costs the most and helps the
     * least. Inner blocks still use alpha over their own panel, which composites
     * against a known colour rather than against whatever is behind the window.
     */
    property real fillOpacity: 1.0
    property bool ticks: true
    property bool scanlines: true
    property bool serial: true
    property string serialSeed: "panel"
    property real padding: Theme.space3
    property real notch: Theme.notch

    property bool notchTopLeft: true
    property bool notchTopRight: false
    property bool notchBottomRight: true
    property bool notchBottomLeft: false

    readonly property color _stroke: emphasis === "alert" ? Theme.borderStrong
                                   : emphasis === "quiet" ? Theme.alpha(Theme.border, 0.6)
                                   : Theme.border

    NotchRect {
        anchors.fill: parent
        fillColor: Theme.alpha(root.fillColor, root.fillOpacity)
        strokeColor: root._stroke
        strokeWidth: root.emphasis === "alert" ? Theme.borderWidthStrong : Theme.borderWidth
        notch: root.notch
        doubleStroke: root.emphasis === "alert"
        notchTopLeft: root.notchTopLeft
        notchTopRight: root.notchTopRight
        notchBottomRight: root.notchBottomRight
        notchBottomLeft: root.notchBottomLeft
    }

    Scanlines {
        // `active` rather than `visible`: it gates the Repeater, so a panel
        // with scanlines off builds no line items at all.
        active: root.scanlines
        drift: false
        anchors.fill: parent
        anchors.margins: 1
    }

    CornerTicks {
        visible: root.ticks
        // Inside the panel bounds. Sitting outside meant a neighbouring panel
        // in a tight Row could paint over them.
        anchors.margins: 2
        color: root.emphasis === "alert" ? Theme.danger : Theme.accentDim
        opacity: 0.7
    }

    Telemetry {
        id: serialText
        /*
         * Both conditions, not just the per-panel one.
         *
         * Telemetry sets its own `visible` from Settings.fx.telemetryText, and
         * assigning `visible` here replaced that binding outright - so the
         * Effects toggle had no effect on any Panel in the shell, which is
         * every serial the user can actually see. Removing the padding
         * reservation last round fixed half of it; this is the other half.
         */
        visible: root.serial && Settings.fx.telemetryText
        seed: root.serialSeed
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.space2
        anchors.bottomMargin: 3
    }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: root.padding
        // The serial prints along the bottom edge, so content has to stop short
        // of it or the two overlap - but only when one is actually being drawn.
        // Reserving the room regardless meant switching serials off removed the
        // text and left the gap behind it.
        anchors.bottomMargin: root.padding + (serialText.visible ? serialText.height + 2 : 0)
    }
}
