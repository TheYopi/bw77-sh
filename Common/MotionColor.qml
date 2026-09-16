import QtQuick
import qs.Config

/*
 * A colour transition, with the shell's timing already on it.
 *
 * This exists because of what the default is. `ColorAnimation { duration: X }`
 * sets no easing, and an unspecified Qt animation runs Easing.Linear - so 83
 * of the shell's 89 colour transitions were linear, which is to say they
 * started at full rate and stopped dead. Nothing in the physical world changes
 * like that, and a whole interface doing it is the flat, unweighted quality
 * that made the hovers feel wrong no matter how well each colour was chosen.
 *
 * Colour has no mass, so it takes the effects curve rather than an arrival
 * curve - see the motion notes in Theme. It also takes the state duration,
 * which is the one speed everything answers the pointer at.
 *
 * Both are defaults, not fixtures: a site that genuinely needs longer sets
 * `duration`, and one that is colouring something in motion can point `curve`
 * at Theme.curveEnter.
 */
ColorAnimation {
    property var curve: Theme.curveEffects
    duration: Theme.durState
    easing.type: Easing.Bezier
    easing.bezierCurve: curve
}
