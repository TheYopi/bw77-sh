import QtQuick
import qs.Config

/*
 * The segmented meter used for health and armour in-game. Reused here for CPU,
 * RAM, battery and volume, which is what makes those readouts feel native to
 * the theme rather than like generic progress bars.
 */
Item {
    id: root

    property real value: 0            // 0..1
    property int segments: 24
    property real segmentGap: 2
    property color fillColor: Theme.accent
    property color emptyColor: Theme.alpha(Theme.border, 0.55)
    property bool vertical: false
    property bool warnAtHigh: true    // turn red past 85%

    /*
     * Per-segment colour animation.
     *
     * Worth it for a meter that changes a few times a second; ruinous for one
     * driven at 60fps, where every segment becomes an independently animating
     * item. Anything fast should turn this off.
     */
    property bool animated: true
    property color warnColor: Theme.danger

    readonly property color _active: (warnAtHigh && value > 0.85) ? warnColor : fillColor
    readonly property int _lit: Math.round(value * segments)

    implicitHeight: vertical ? 100 : 10
    implicitWidth: vertical ? 10 : 100

    Grid {
        anchors.fill: parent
        columns: root.vertical ? 1 : root.segments
        rows: root.vertical ? root.segments : 1
        spacing: root.segmentGap
        flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight

        Repeater {
            model: root.segments
            Rectangle {
                required property int index
                width: root.vertical
                    ? root.width
                    : (root.width - root.segmentGap * (root.segments - 1)) / root.segments
                height: root.vertical
                    ? (root.height - root.segmentGap * (root.segments - 1)) / root.segments
                    : root.height
                color: {
                    // Vertical bars fill bottom-up, like the game's health column.
                    const i = root.vertical ? (root.segments - 1 - index) : index;
                    return i < root._lit ? root._active : root.emptyColor;
                }
                Behavior on color {
                    enabled: root.animated
                    ColorAnimation { duration: Theme.durFast }
                }
            }
        }
    }
}
