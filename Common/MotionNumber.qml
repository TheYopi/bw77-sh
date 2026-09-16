import QtQuick
import qs.Config

/*
 * A numeric transition, with the shell's timing already on it. The companion
 * to MotionColor - see the note there for why an unspecified animation is the
 * wrong default, and the motion notes in Theme for the curve set.
 *
 * The default is the effects curve at state speed, which is what a control
 * lighting up or a value sliding under the cursor wants. Anything that is
 * genuinely ARRIVING - a row opening out, a panel taking its place - should
 * say so by pointing `curve` at Theme.curveEnter and giving itself one of the
 * longer durations, because the distance is bigger.
 */
NumberAnimation {
    property var curve: Theme.curveEffects
    duration: Theme.durState
    easing.type: Easing.Bezier
    easing.bezierCurve: curve
}
