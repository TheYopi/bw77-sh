import QtQuick
import qs.Config
import qs.Common

/*
 * Value slider, per the study: a solid triangle at each end, a heavy rail
 * between them, and the number in a chamfered chip that rides the rail at the
 * current position.
 *
 * The chip used to sit in a fixed box at the right-hand end, which meant the
 * value and the position were two separate readings of the same fact printed in
 * two different places - and the segmented fill that carried the position was
 * a row of forty ticks that read as texture rather than as a quantity. The chip
 * on the rail is one mark answering both questions, and it is also the thing
 * you grab, so what you drag and what you read are the same object.
 */
Item {
    id: root

    property real value: 0.5
    property real from: 0
    property real to: 1
    property real stepSize: 0.01
    property bool showSteppers: true
    property bool showValue: true
    property string suffix: ""
    property int decimals: 0

    // The readout can use a different scale to the value. A volume runs 0..1
    // internally but should read 0..100, and rounding 0..1 to zero decimals
    // showed nothing but 0 and 1.
    property real displayScale: 1
    property color barColor: Theme.accent

    /*
     * Optional glyph inside the frame, at the left.
     *
     * The audio rows used to put the speaker and microphone icons outside the
     * slider as loose CyberTexts in a Row, which left them floating next to a
     * framed control looking like separate widgets that happened to be
     * adjacent. Inside the frame they read as the slider's own label - this is
     * the thing being adjusted - and the click target comes along with them.
     */
    property string iconText: ""
    property color iconColor: Theme.accent

    signal iconClicked()

    signal moved(real value)

    // --- keyboard contract
    //
    // No key chips here. A slider is driven by the same left/right arrows as
    // everything else, and the triangles on each end already say so; printing
    // the keys as well would put a chip on the majority of rows in the shell to
    // teach something the shape has already taught.
    readonly property string navKind: "slider"
    property bool navFocused: CcNav.focusedControl === root

    function navStep(delta) { root.setValue(root.value + delta * root.keyStep); }

    // A hundredth of the range is too fine to be useful on a long slider and
    // too coarse on a short one, so the declared step wins wherever it is
    // larger - which is what the triangles do too.
    readonly property real keyStep: Math.max(root.stepSize, (root.to - root.from) / 100)

    readonly property real ratio:
        (root.value - root.from) / Math.max(0.0001, root.to - root.from)

    implicitHeight: 30
    implicitWidth: 240

    function setValue(v) {
        const clamped = Math.max(from, Math.min(to, v));
        let snapped = clamped;

        if (stepSize > 0) {
            snapped = Math.round(clamped / stepSize) * stepSize;

            // Snapping to a fractional step accumulates binary float error, so
            // 0.35 lands in settings.json as 0.35000000000000003. Round to the
            // precision the step itself implies.
            const places = Math.max(0, Math.ceil(-Math.log10(stepSize)) + 1);
            snapped = parseFloat(snapped.toFixed(Math.min(10, places)));
        }

        if (snapped !== value) {
            value = snapped;
            root.moved(snapped);
        }
    }

    NotchRect {
        anchors.fill: parent
        fillColor: Theme.alpha(Theme.bgDeep, 0.85)
        strokeColor: root.navFocused ? Theme.accent : Theme.frame
        strokeWidth: root.navFocused ? Theme.borderWidthStrong : Theme.borderWidth
        notch: Theme.notch

        Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
    }

    Item {
        id: iconSlot
        visible: root.iconText !== ""
        // Sized off the icon, not fixed at 26: turning the icon scale up used
        // to push the glyph into the divider and then past it.
        width: visible ? Math.max(26, Theme.fontIcon + Theme.space3) : 0
        height: parent.height
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        CyberText {
            anchors.centerIn: parent
            text: root.iconText
            role: "icon"
            color: root.iconColor
        }

        // Divider, so the glyph reads as a fixed label on the control rather
        // than as something sitting on the rail.
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: parent.height - 8
            color: Theme.alpha(Theme.border, 0.9)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }

    StepArrow {
        id: leftArrow
        direction: "left"
        visible: root.showSteppers
        anchors.left: iconSlot.right
        anchors.leftMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        enabled: root.value > root.from
        onTriggered: root.setValue(root.value - root.keyStep)
    }

    StepArrow {
        id: rightArrow
        direction: "right"
        visible: root.showSteppers
        anchors.right: parent.right
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        enabled: root.value < root.to
        onTriggered: root.setValue(root.value + root.keyStep)
    }

    Item {
        id: track
        anchors.left: root.showSteppers ? leftArrow.right : parent.left
        anchors.right: root.showSteppers ? rightArrow.left : parent.right
        anchors.leftMargin: Theme.space2
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        // Where the chip's left edge goes. The chip has width, so the travel is
        // the track minus the chip - otherwise the last few percent push it off
        // the end and the value stops tracking the pointer.
        readonly property real travel: Math.max(0, width - chip.width)
        readonly property real chipX: travel * root.ratio

        // The rail. Drawn full width behind the chip in the dim red, with the
        // portion up to the chip in the bar colour, so position reads from the
        // fill as well as from where the chip sits.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 3
            color: Theme.alpha(Theme.border, 0.9)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: track.chipX + chip.width / 2
            height: 3
            color: root.barColor
            opacity: 0.85
        }

        NotchRect {
            id: chip
            x: track.chipX
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(46, valueText.implicitWidth + Theme.space4)
            height: 24
            visible: root.showValue
            /*
             * Opaque, deliberately.
             *
             * This was a translucent tint, which was fine when the readout sat
             * in its own box at the end of the row - there was nothing behind
             * it. Now that the chip rides the rail, a see-through fill means
             * the rail draws straight through the number, and at a glance the
             * digits look struck out.
             */
            fillColor: drag.pressed ? Theme.dangerDim : Theme.bgDeep
            strokeColor: root.navFocused || drag.containsMouse ? Theme.accent : Theme.frame
            strokeWidth: Theme.borderWidthStrong
            notch: 8

            Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
            Behavior on fillColor { ColorAnimation { duration: Theme.durFast } }

            // Not animated on x. The chip follows the pointer during a drag and
            // an easing curve there feels like lag rather than polish; keyboard
            // steps are small enough that the jump reads as a step.

            CyberText {
                id: valueText
                anchors.centerIn: parent
                text: (root.value * root.displayScale).toFixed(root.decimals) + root.suffix
                role: "label"
                color: Theme.text
            }
        }

        /*
         * One area for the whole rail, rather than one on the chip and another
         * behind it. A click anywhere jumps the value there and continues as a
         * drag, which is what a rail this short needs - the chip is 46px of a
         * 200px track, so requiring the grab to land on it would mean most
         * presses did nothing.
         *
         * The pointer is centred on the chip, hence the half-width offset.
         */
        MouseArea {
            id: drag
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function valueAt(mx) {
                if (track.travel <= 0) return root.from;
                const t = Math.max(0, Math.min(1, (mx - chip.width / 2) / track.travel));
                return root.from + t * (root.to - root.from);
            }

            onPressed: (m) => root.setValue(valueAt(m.x))
            onPositionChanged: (m) => { if (pressed) root.setValue(valueAt(m.x)); }
            onWheel: (w) => root.setValue(root.value
                + (w.angleDelta.y > 0 ? root.keyStep : -root.keyStep))
        }
    }
}
