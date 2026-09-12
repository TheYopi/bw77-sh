import QtQuick
import qs.Config
import qs.Common

/*
 * One-of-N chooser, in the arrow-stepper shape the sliders already use.
 *
 * Replaces the rows of side-by-side buttons. Those showed every option at all
 * times, which meant a pane with eight such rows put forty-odd competing labels
 * on screen and the one that was actually selected had to be found by looking
 * for the highlighted fill. This shows the current choice and nothing else, and
 * puts the position in the set on the segment bar underneath - so "how many
 * options are there" and "which one is this" are answered without reading any
 * of the ones you did not pick.
 *
 * Options are [{ v: value, l: "Label" }] - the same array the button Repeaters
 * were already using, so call sites keep their model verbatim.
 */
Item {
    id: root

    property var options: []
    property var current
    property color accentColor: Theme.accent

    // Wrapping is worth it here in a way it is not for a pane list: these sets
    // are two to four long, and stopping at the end just means a dead arrow.
    property bool wrap: true

    signal picked(var value)

    // --- keyboard contract
    //
    // The Control Center steers whichever control the focused row hands it, and
    // this is the whole interface it needs. `navFocused` is a default binding
    // rather than a plain flag so a wrapper (CyberDropdown) can point it at
    // itself instead.
    readonly property string navKind: "selector"
    property bool navFocused: CcNav.focusedControl === root

    function navStep(delta) { root.step(delta); }
    function navActivate() { root.step(1); }

    /*
     * 240 to match CyberSlider, which is the control it sits next to in every
     * settings pane.
     *
     * It was 210, so a column of settings had its steppers ending 30px short
     * of its sliders - close enough to look like a mistake rather than a
     * choice, and it put the right-hand arrow of a stepper in a different place
     * from the right-hand end of the slider above it. The two are the same kind
     * of control in the same column and should line up on both edges.
     *
     * Call sites that set an explicit width - the wallpaper picker's switches,
     * the widget option editor - still override this.
     */
    implicitWidth: 240
    implicitHeight: 34

    readonly property int count: options ? options.length : 0

    readonly property int index: {
        for (let i = 0; i < root.count; i++)
            if (root.options[i].v === root.current) return i;
        return -1;
    }

    readonly property string label: {
        const i = root.index;
        return i >= 0 ? root.options[i].l : "\u2014";
    }

    function step(delta) {
        if (root.count === 0) return;
        let i = root.index;
        // An unrecognised current value should land somewhere sensible rather
        // than refusing to move.
        if (i < 0) i = delta > 0 ? -1 : 0;
        let next = i + delta;
        if (next < 0) next = root.wrap ? root.count - 1 : 0;
        if (next >= root.count) next = root.wrap ? 0 : root.count - 1;
        if (next !== root.index) root.picked(root.options[next].v);
    }

    NotchRect {
        anchors.fill: parent
        fillColor: Theme.alpha(Theme.bgDeep, 0.85)
        strokeColor: root.navFocused ? root.accentColor
            : (hover.containsMouse ? Theme.alpha(root.accentColor, 0.8) : Theme.frame)
        strokeWidth: root.navFocused ? Theme.borderWidthStrong : Theme.borderWidth
        notch: Theme.notch

        Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
    }

    // Wheel and a click on the label both advance, so the arrows are a hint
    // rather than the only way in.
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.step(1)
        onWheel: (w) => root.step(w.angleDelta.y > 0 ? -1 : 1)
    }

    StepArrow {
        id: leftArrow
        direction: "left"
        color: root.accentColor
        anchors.left: parent.left
        anchors.leftMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
        enabled: root.wrap || root.index > 0
        onTriggered: root.step(-1)
    }

    StepArrow {
        id: rightArrow
        direction: "right"
        color: root.accentColor
        anchors.right: parent.right
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
        enabled: root.wrap || root.index < root.count - 1
        onTriggered: root.step(1)
    }

    /*
     * --- the label
     *
     * There used to be a pair of key chips here, fading in on either side of
     * the label when the row took focus, to say that left and right move the
     * stepper. They are gone, and the width they reserved is the label's now.
     *
     * The chips restated what the two solid triangles either side of them were
     * already saying, in the same control, six pixels apart - and they charged
     * the label for it permanently. The space had to be held whether or not
     * they were showing, or a row would reflow the moment focus landed on it,
     * so every stepper in the shell gave up roughly forty pixels of its label
     * for a hint that only appeared on one row at a time. On the narrower ones
     * that was the difference between a word fitting and being elided.
     *
     * Long labels still shrink the text rather than widening the control, so a
     * column of these stays aligned down the pane.
     */
    CyberText {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        width: root.width - (leftArrow.width + Theme.space2 + Theme.space1) * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.label
        role: "label"
        color: root.accentColor
    }

    /*
     * --- position in the set
     *
     * A sliding window, not one segment per option.
     *
     * Fixed-width marks were the right call for making adjacent rows line up,
     * but one per option meant the strip's width grew with the number of
     * choices - and several of these lists are long (every colour role, every
     * font weight, every monitor), so the marks ran straight out through the
     * sides of the control. Sizing the control to fit them would make the
     * longest list dictate the width of every stepper on the pane.
     *
     * So the strip shows a fixed number of marks and scrolls the set through
     * them, keeping the current one in the middle. The marks at each end shrink
     * when there is more set beyond them, which is what says the strip is a
     * window rather than the whole thing.
     */
    Item {
        id: segments

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Theme.space5 * 2
        height: 3

        // Clipped as a backstop. The arithmetic below should never produce a
        // strip wider than the control, but this is the one part of the
        // stepper that is driven by an option count the control does not
        // choose, so a wrong answer must not be able to paint over the frame.
        clip: true

        readonly property int markWidth: 18
        readonly property int gap: 3

        /*
         * How many marks fit, and how many are actually drawn.
         *
         * These were one expression with a `Math.max(3, ...)` wrapped round it,
         * on the reasoning that three is the fewest that can show "more to the
         * left" and "more to the right" at once. That floor was the bug: on a
         * control too narrow for three marks it returned three anyway, and on a
         * two-option stepper it drew a third mark for an option that does not
         * exist. Both cases painted straight through the frame.
         *
         * What fits wins. If only two marks fit then two are drawn, and the
         * shrunken end mark still says the set continues.
         */
        readonly property int fits:
            Math.max(1, Math.floor((width + gap) / (markWidth + gap)))

        readonly property int visibleCount: Math.min(root.count, fits)

        readonly property bool windowed: root.count > visibleCount

        // Start of the window, clamped so it never scrolls past either end.
        readonly property int start: {
            if (!windowed) return 0;
            const half = Math.floor(visibleCount / 2);
            return Math.max(0, Math.min(root.count - visibleCount,
                                        Math.max(0, root.index) - half));
        }

        Row {
            anchors.centerIn: parent
            spacing: segments.gap

            Repeater {
                model: segments.visibleCount

                Rectangle {
                    required property int index

                    readonly property int option: segments.start + index
                    readonly property bool current: option === root.index

                    // The end marks shrink when the set continues past them.
                    readonly property bool truncated: segments.windowed
                        && ((index === 0 && segments.start > 0)
                            || (index === segments.visibleCount - 1
                                && segments.start + segments.visibleCount < root.count))

                    width: truncated ? 8 : segments.markWidth
                    height: 3
                    color: current ? root.accentColor : Theme.alpha(Theme.textMuted, 0.55)

                    Behavior on width { NumberAnimation { duration: Theme.durFast } }
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }
            }
        }
    }
}
