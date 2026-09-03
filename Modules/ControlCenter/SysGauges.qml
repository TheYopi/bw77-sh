import QtQuick
import qs.Config
import qs.Common

/*
 * One system reading, drawn as a wide semicircular gauge with the value in the
 * opening.
 *
 * These were four square cards on the Overview pane, and they had two problems
 * at once: they were only visible on the one tab that needed them least, and
 * they were squeezed into a quarter of the settings column, which is narrow
 * enough that the memory reading - "10.5G / 31.2G" - was the widest thing in
 * the card by some margin.
 *
 * Across the head of the surface there is room to make them instruments rather
 * than badges. The arc is a half circle with its pivot near the bottom of the
 * cell, so the reading sits inside the sweep where a speedometer would put it
 * and none of the cell is spent on an empty lower half.
 */
Item {
    id: root

    property string label: ""
    property string value: ""
    property real fraction: 0
    property color tint: Theme.accent

    implicitHeight: 96

    CyberText {
        id: title
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.label
        role: "micro"
        bold: true
        // Danger for all four, so the row of headings reads as one label rather
        // than as four things each announcing themselves in their own colour -
        // the arcs already carry the per-metric colour.
        color: Theme.danger
    }

    ArcMeter {
        id: arc
        anchors.fill: parent
        anchors.topMargin: title.height + Theme.space1

        // A wide flat sweep, closer to a dial than to the OSD's near-full ring.
        startAngle: 180
        sweepAngle: 180

        // Pivot low in the cell and radius taken from whichever axis runs out
        // first, so the gauge fills a short wide cell without clipping.
        centreY: 0.92
        radius: Math.max(20, Math.min(width / 2 - Theme.space3, height * 0.92))

        // More ticks than the OSD's twenty. These read as a continuous sweep
        // rather than as a stepped level, which is the point of easing them.
        segments: 32
        thickness: 9
        tickWidth: 4

        value: root.fraction
        fillColor: root.tint
        emptyColor: Theme.alpha(Theme.border, 0.65)
    }

    // Inside the sweep. Given the full cell width to wrap into, which is what
    // the square cards could not offer.
    CyberText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        width: parent.width - Theme.space4 * 2
        horizontalAlignment: Text.AlignHCenter
        text: root.value
        role: "label"
        color: root.tint
        elide: Text.ElideRight
    }
}
