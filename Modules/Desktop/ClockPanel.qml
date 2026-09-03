import QtQuick
import Quickshell
import qs.Config
import qs.Common
import qs.Modules.Desktop

WidgetFrame {
    id: root
    accentColor: Theme.accent
    property var config: ({})

    readonly property bool wide: WidgetMetrics.isWide("clock", width, height)

    readonly property string timeText:
        Qt.formatDateTime(clock.date, Settings.clock.timeFormat)

    /*
     * --- how big the time is
     *
     * It fills the frame. Drag the widget larger and the digits get larger,
     * with no ceiling other than the frame itself.
     *
     * There used to be one: Theme.fontHuge * 1.6, which works out at 64px, so
     * everything past about 128px of widget height rendered identically and
     * the resize handle appeared to stop working vertically. That cap existed
     * to stop a small widget blowing out, which is the floor's job.
     *
     * --- the safe zone
     *
     * Removing the cap exposed the next problem, which is that the height
     * budget was being spent in the wrong currency. It compared the font's
     * PIXEL SIZE against the space available, and a pixel size is not a
     * height: the box a line actually occupies is ascent plus descent, which
     * runs about 1.3 times the pixel size on a normal face and considerably
     * more on a patched Nerd Font, where the ascender is raised to clear the
     * icon glyphs. So a time asked to take 62% of the frame drew something
     * closer to 85% of it, the date went underneath that, and the pair ran
     * past the bottom edge and got clipped.
     *
     * Everything below is therefore solved in drawn height, taken from the
     * same TextMetrics that measures the width, and then an explicit inset is
     * held back on every side so the glyphs never touch the frame.
     */
    TextMetrics {
        id: probe
        // Mirrors what CyberText resolves for role "headline", so the measured
        // box is the box that will actually be drawn.
        font.family: Theme.fontUI
        font.pixelSize: 100
        font.weight: Font.DemiBold
        font.letterSpacing: Theme.trackingHeadline
        font.capitalization: Font.AllUppercase
        text: root.timeText
    }

    /*
     * The scramble is wider than the time it replaces.
     *
     * GlitchText swaps each character for a random one from its glyph set
     * while a new value resolves, and that set contains letters - W and M are
     * in it - which are far wider than digits and a colon. Sizing to the digits
     * alone means the widget fits for fifty-nine seconds and overflows on the
     * tick, which is both a cut-off and the hardest kind to catch, because it
     * is gone by the time you look.
     *
     * So the width budget is measured against a same-length run of the widest
     * glyph, but only when the decode is actually switched on - otherwise a
     * setting nobody has enabled would shrink the clock permanently.
     */
    readonly property bool decodes:
        Settings.fx.glitchOnOpen && Settings.animations.textDecode

    TextMetrics {
        id: worstProbe
        font: probe.font
        text: "W".repeat(Math.max(1, root.timeText.length))
    }

    // Per pixel of font size: how wide the string is, and how tall its line
    // box is. Guarded because TextMetrics reports zero before it has measured
    // anything, and dividing by that would make the first frame infinite.
    readonly property real widthPerPx: Math.max(0.1,
        Math.max(probe.advanceWidth,
                 root.decodes ? worstProbe.advanceWidth : 0) / 100)

    readonly property real heightPerPx: Math.max(0.5, probe.height / 100)

    /*
     * Held back on every side, so the text has room to breathe inside the
     * frame rather than sitting flush against the padding. Without it the
     * widest glyph lands exactly on the boundary and any rounding in the
     * layout puts it over.
     */
    readonly property real safe: Theme.space2

    readonly property real availW:
        Math.max(20, width - root.padding * 2 - root.safe * 2)
    readonly property real availH:
        Math.max(20, height - root.padding * 2 - root.safe * 2)

    /*
     * When the date sits beside the time rather than under it, it takes part
     * of the row. Its own size derives from the time's, so solving the two
     * exactly would be circular - this reserves a share instead, from the
     * usual proportions: the date is a fifth the height and around four times
     * the character count, so it occupies a little under half the row.
     */
    readonly property real timeShareW: root.wide ? 0.55 : 1.0

    // The date is drawn at a fifth of the time's size and stacked under it
    // when the widget is tall, so the column has to fit 1.2 line boxes rather
    // than one. rowSpacing is negative, which gives a little of that back.
    readonly property real stackFactor: root.wide ? 1.0 : 1.2

    readonly property real byHeight:
        (root.availH + (root.wide ? 0 : Theme.space2))
        / (root.heightPerPx * root.stackFactor)

    readonly property real byWidth:
        (root.availW * root.timeShareW) / root.widthPerPx

    readonly property real timeSize:
        Math.max(Theme.fontLarge, Math.min(root.byHeight, root.byWidth))

    /*
     * One layout expressed as a Grid rather than as a Column and a Row behind a
     * conditional. Wide puts the date beside the time on its baseline, tall
     * stacks them - and the two cases cannot drift apart because they are the
     * same items either way.
     */
    /*
     * Clipping has to happen here, not on the Grid.
     *
     * A Grid sizes itself to its children, so it has no spare bounds for
     * `clip` to trim against - it would grow with the text and clip nothing.
     * This fills the content area, which is the shape the text must not escape,
     * and the Grid centres inside it.
     *
     * Backstop only: the sizing above should always fit. But the wide-case
     * reservation for the date is an estimate, and an estimate must not be able
     * to paint over the widget's own frame.
     */
    Item {
        anchors.fill: parent
        clip: true

        Grid {
            anchors.centerIn: parent
            columns: root.wide ? 2 : 1
            rows: root.wide ? 1 : 2
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignBottom
            columnSpacing: Theme.space3
            rowSpacing: -Theme.space2

            GlitchText {
                text: root.timeText
                role: "headline"
                fontSize: root.timeSize
                color: Theme.accent

                /*
                 * A backstop for the one case the sizing cannot satisfy.
                 *
                 * timeSize has a floor - below Theme.fontLarge the time stops
                 * being readable and there is no point drawing it - so on a
                 * widget dragged smaller than any size that fits, the floor
                 * wins and the text is wider than the space. Bounded here, that
                 * ends in an ellipsis; unbounded it ended in digits painted
                 * across the frame.
                 */
                textWidth: Math.min(implicitWidth, root.availW * root.timeShareW)
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            CyberText {
                // Dropped rather than shrunk to nothing on a small widget: the
                // time is the reason the widget exists, the date is a courtesy.
                visible: root.height >= 70
                text: Qt.formatDateTime(clock.date,
                    root.width < 260 ? "ddd dd MMM" : "dddd dd MMMM yyyy")
                role: "micro"
                sizeOverride: Math.max(Theme.fontMicro, root.timeSize * 0.2)
                color: Theme.textDim

                /*
                 * Bounded and elided, because the date can be wider than the
                 * time it is sized from.
                 *
                 * The size is a fifth of the time's, which is safe on
                 * character count alone - until the long form is in use. A
                 * fully written date runs to twenty-six characters against the
                 * time's five, and a fifth of the size does not make up a
                 * five-fold difference in length, so on a narrow widget the
                 * date is the line that reaches the edge first. Given a width
                 * it elides; without one it just kept going and was cut.
                 */
                width: Math.min(implicitWidth, root.availW)
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }

    }

    SystemClock { id: clock; precision: SystemClock.Minutes }
}
