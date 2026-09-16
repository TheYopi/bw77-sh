import QtQuick
import qs.Config

/*
 * A track in a surface's entrance or exit, taking its shape from the surface's
 * motion category.
 *
 * Category motion is configurable per family in Control Center -> Animations,
 * so every animation belonging to a surface has to read the curve and the
 * duration back out of Theme rather than carrying its own. Doing that by hand
 * is two lines of easing at every site and they drift apart; this is the two
 * lines, once.
 *
 * `exiting` is the asymmetry. An arrival gets the category's full duration on
 * its own curve; a departure gets two thirds of it and accelerates away
 * instead - it is answering an instruction that has already been given, and
 * playing that back at full length is what makes a shell feel slow. See the
 * motion notes in Theme.
 */
NumberAnimation {
    id: root

    property string category: "menus"
    property bool exiting: false

    duration: root.exiting
        ? Theme.exitDuration(Theme.durationFor(root.category))
        : Theme.durationFor(root.category)

    easing.type: Easing.Bezier
    easing.bezierCurve: root.exiting ? Theme.curveExit : Theme.bezierFor(root.category)
}
