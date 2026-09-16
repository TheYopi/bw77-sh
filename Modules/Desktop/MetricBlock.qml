import QtQuick
import qs.Config
import qs.Common

/*
 * One reading, drawn as a gauge over its detail.
 *
 * Three parts, top to bottom: a ticked arc with the name and the figure set
 * inside its opening, a rule, and then whatever that reading has to say about
 * itself - the processes responsible for it, or its own recent history.
 *
 * --- why some readings have no arc
 *
 * An arc is a proportion of something, and it needs a maximum to be a
 * proportion OF. Processor load, memory and temperature all have one. A
 * transfer rate does not: a gauge would have to invent a ceiling, and then the
 * needle would be measuring against a number nobody chose. Those blocks put the
 * figure where the arc would have been and give the whole of the rest to the
 * history, which is the honest shape for a reading that only makes sense
 * relative to itself.
 *
 * --- two arrangements
 *
 * Stacked, or gauge to the left with the detail beside it. A block twice as
 * wide as it is tall has no room above and below for a gauge and five rows,
 * but plenty of room beside it, so it turns. The rule goes with the stack: it
 * separates the gauge from what is under it, and when the detail is alongside
 * rather than underneath there is nothing for it to separate.
 */
Item {
    id: root

    property string label: ""
    property string valueText: ""
    property real ratio: 0
    property bool hasGauge: true
    property color accentColor: Theme.accent

    // "procs" | "graph" | "none"
    property string detail: "graph"
    property var procModel: []
    property var procFormatter: (v) => String(v)
    property string procEmptyText: ""
    property var history: []
    property real historyMax: 100

    /*
     * Turns once the block is wide enough that the gauge and the detail are
     * better side by side than one over the other.
     *
     * Only a block that HAS a gauge can turn. With nothing to put beside the
     * detail, turning would give the readout a column of its own width zero -
     * the figure and its name would simply not be drawn - and the wide network
     * blocks are exactly the ones with no gauge. Keyed off `hasGauge` rather
     * than off whether the gauge ended up visible, because the gauge's size is
     * decided by this and the two cannot both depend on each other.
     */
    readonly property bool sideBySide: root.hasGauge && root.height > 0
        && (root.width / root.height) >= 2.1

    // --- the gauge, and how much of the block it takes
    //
    // Square-ish but not square: the arc is a little over half a circle, so the
    // box it needs is wider than it is tall. 0.70 is the ratio at which the
    // tick ends at the very bottom edge with nothing left over - see centreY.
    readonly property real gaugeWidth: {
        if (!root.hasGauge) return 0;
        if (root.sideBySide)
            return Math.min(root.width * 0.44, root.height / 0.70);
        return Math.min(root.width, root.height * 0.62 / 0.70);
    }
    readonly property real gaugeHeight: gaugeWidth * 0.70

    readonly property bool gaugeVisible: root.hasGauge && gaugeWidth >= 54

    Item {
        id: head

        // Centred in the space it is given, so a gauge narrower than the block
        // sits in the middle of it rather than against the left edge.
        x: root.sideBySide ? 0 : Math.round((root.width - width) / 2)
        y: 0
        width: root.gaugeVisible ? root.gaugeWidth : (root.sideBySide ? 0 : root.width)
        height: root.gaugeVisible ? root.gaugeHeight
                                  : (labelItem.height + valueItem.height)

        ArcMeter {
            anchors.fill: parent
            visible: root.gaugeVisible
            value: Math.max(0, Math.min(1, root.ratio))
            fillColor: root.accentColor
            emptyColor: Theme.alpha(root.accentColor, 0.22)

            /*
             * Opening downwards, and a little past the horizontal at each end.
             * A clean half circle reads as a progress bar that has been bent;
             * carrying the ticks below the diameter is what makes it a dial.
             *
             * 166 degrees to 374 puts the ends 14 degrees below horizontal,
             * which with centreY at 0.82 lands the lowest tick on the bottom
             * edge of the box exactly.
             */
            startAngle: 166
            sweepAngle: 208
            centreY: 0.82
            radius: Math.max(0, parent.width / 2 - 2)

            // Enough ticks to read as a scale, few enough to stay distinct at
            // the size the block actually got.
            segments: Math.max(14, Math.min(36, Math.round(parent.width / 7)))
            thickness: Math.max(4, Math.round(parent.width * 0.11))
            tickWidth: Math.max(1, Math.round(parent.width / 70))
        }

        /*
         * The name and the figure, inside the arc's opening.
         *
         * Positioned from the bottom rather than centred: the opening is the
         * lower half of the box and its height changes with the block, so
         * anything centred in the box drifts up into the ticks as the block
         * grows. Sitting on the bottom edge keeps the pair in the mouth of the
         * arc at every size.
         */
        Column {
            id: readout
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.gaugeVisible
                ? Math.round(parent.height * 0.06) : 0
            spacing: 0

            CyberText {
                id: labelItem
                // Sized to the head rather than to its own text: without a
                // width there is nothing for elide to act on, and a long
                // reading - "1.4 GB/S" at the size these are set in - drew
                // straight out past the edge of the widget.
                width: head.width
                horizontalAlignment: Text.AlignHCenter
                text: root.label
                role: "micro"
                color: Theme.textMuted
                sizeOverride: root.gaugeVisible
                    ? Math.max(Theme.fontMicro,
                        Math.min(Theme.fontSmall, Math.round(head.width * 0.10)))
                    : 0
            }

            CyberText {
                id: valueItem
                width: head.width
                horizontalAlignment: Text.AlignHCenter
                text: root.valueText
                role: "mono"
                color: root.accentColor
                // Scales with the gauge, so a large widget is readable across
                // a room and a small one does not blow its number out past the
                // arc that is supposed to contain it.
                sizeOverride: Math.max(Theme.fontSmall,
                    Math.min(Theme.fontHuge,
                        Math.round((root.gaugeVisible ? head.width : root.width) * 0.22)))
            }
        }
    }

    // --- the rule
    //
    // Only in the stacked arrangement, and only when there is something under
    // it. See the note at the top.
    Rectangle {
        id: rule
        visible: !root.sideBySide && root.detail !== "none"
                 && root.height - head.height > 18
        anchors.left: parent.left
        anchors.right: parent.right
        y: head.height + Theme.space1
        height: 1
        color: Theme.alpha(root.accentColor, 0.5)
    }

    Item {
        id: detailArea

        anchors.left: root.sideBySide ? head.right : parent.left
        anchors.leftMargin: root.sideBySide ? Theme.space3 : 0
        anchors.right: parent.right
        anchors.top: root.sideBySide ? parent.top : rule.bottom
        anchors.topMargin: root.sideBySide ? 0 : Theme.space1
        anchors.bottom: parent.bottom
        clip: true

        ProcList {
            anchors.fill: parent
            visible: root.detail === "procs"
            model: root.procModel
            formatter: root.procFormatter
            emptyText: root.procEmptyText
            accentColor: root.accentColor
        }

        Graph {
            anchors.fill: parent
            visible: root.detail === "graph" && detailArea.height >= 14
            values: root.history
            maxValue: root.historyMax
            lineColor: root.accentColor
            // Denser than the backdrop it used to be: this is the block's
            // content now rather than texture behind a number, so it is drawn
            // at a weight meant to be looked at.
            fillOpacity: 0.30
            showGrid: detailArea.height >= 34
        }
    }
}
