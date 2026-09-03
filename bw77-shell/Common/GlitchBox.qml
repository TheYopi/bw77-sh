import QtQuick
import qs.Config

/*
 * Transition wrapper for every surface that opens and closes.
 *
 * Bind `shown` to whatever controls the surface. Closing emits closeFinished,
 * which is the cue for whatever owns the surface to actually destroy it.
 *
 * The close half is the reason this exists: a surface bound directly to a
 * LazyLoader is destroyed the moment its flag flips, so there is nothing left
 * on screen to animate. SurfaceHolder keeps it alive for exactly as long as
 * this takes.
 *
 * The shape of the motion comes from `category`, which indexes the per-category
 * curve, duration and direction in Theme. "glitch" keeps the original
 * scale-snap-and-kick as one direction among several, so the shell's own look
 * is a choice rather than the only option.
 *
 * `autoDirection` is what "auto" resolves to. A surface that knows which edge
 * it lives on sets it - the dock passes the opposite of its position, so a
 * bottom dock's menu rises and a top dock's menu drops.
 */
Item {
    id: root

    default property alias content: body.data

    property bool shown: true
    property string category: "quickSettings"
    property string autoDirection: "up"

    property int openDuration: Theme.durationFor(root.category)
    property int closeDuration: Math.round(Theme.durationFor(root.category) * 0.85)
    property bool enabled: Settings.animations.surfaceOpen

    readonly property int curve: Theme.curveFor(root.category)

    readonly property string direction: {
        const d = Theme.directionFor(root.category);
        return d === "auto" ? root.autoDirection : d;
    }

    // Overrides the pivot when the content bounds are not the right centre.
    property Item originItem: null

    // Travel for a directional entry, in pixels. Small on purpose: a surface
    // that flies in from off-screen reads as sluggish however fast it is.
    property int travel: 18

    readonly property int offsetX: direction === "left" ? -travel
        : direction === "right" ? travel : 0
    readonly property int offsetY: direction === "up" ? travel
        : direction === "down" ? -travel : 0

    readonly property bool glitchy: direction === "glitch"
    readonly property bool flat: direction === "fade"

    /*
     * How long the opacity ramp runs.
     *
     * It used to be half the category duration in every case, which was fine
     * while opacity was a supporting part of a scale-and-slide. For direction
     * "fade" it is the only thing that moves - both scales are pinned to 1 and
     * both offsets are 0 - so halving it meant a category set to 600ms faded in
     * 300ms and the Duration control looked like it was being ignored. A fade
     * takes the whole duration; everything else still leads with opacity and
     * lets the transform finish behind it.
     */
    readonly property int fadeInDuration:
        Math.max(1, root.flat ? root.openDuration : root.openDuration * 0.5)

    signal closeFinished()

    Item {
        id: body
        anchors.fill: parent

        /*
         * The scale pivots on the CONTENT, not on the wrapper.
         *
         * These wrappers fill the whole screen while the thing they animate is
         * a panel down one edge or a toast in a corner. Pivoting on the wrapper
         * meant a right-hand quick settings panel grew from the middle of the
         * display, so it appeared to slide diagonally in from nowhere rather
         * than expand in place - and the further from centre a surface sat, the
         * more wrong it looked.
         *
         * childrenRect is the union of what was actually put inside, which for
         * every one of these is the panel itself. `originItem` overrides it for
         * anything where that union is not the right pivot.
         */
        readonly property rect pivot: body.childrenRect

        transform: [
            Scale {
                id: scaleT
                origin.x: root.originItem
                    ? root.originItem.x + root.originItem.width / 2
                    : (body.pivot.width > 0 ? body.pivot.x + body.pivot.width / 2
                                            : body.width / 2)
                origin.y: root.originItem
                    ? root.originItem.y + root.originItem.height / 2
                    : (body.pivot.height > 0 ? body.pivot.y + body.pivot.height / 2
                                             : body.height / 2)
                xScale: 1
                yScale: 1
            },
            Translate { id: shiftT; x: 0; y: 0 }
        ]
    }

    onShownChanged: {
        if (!enabled || Theme.reducedMotion) {
            opacity = shown ? 1 : 0;
            if (!shown) root.closeFinished();
            return;
        }
        if (shown) openSeq.restart();
        else closeSeq.restart();
    }

    Component.onCompleted: {
        if (shown && enabled && !Theme.reducedMotion) openSeq.restart();
        else opacity = shown ? 1 : 0;
    }

    /*
     * --- open
     *
     * Every path that animates opacity up from zero ends with an explicit
     * reset. An interrupted animation would otherwise leave the surface stuck
     * at zero opacity - present, taking input, and completely invisible.
     */
    SequentialAnimation {
        id: openSeq

        ParallelAnimation {
            // Carries the curve like every other track here. Without it the
            // Curve control did nothing at all on a "fade" category, because
            // opacity was the only property that moved and it was the only one
            // still running on the implicit linear default.
            NumberAnimation {
                target: root; property: "opacity"
                from: 0; to: 1
                duration: root.fadeInDuration
                easing.type: root.curve
            }

            NumberAnimation {
                target: scaleT; property: "yScale"
                from: root.flat ? 1 : (root.glitchy ? 0.86 : 0.96)
                to: 1
                duration: root.openDuration
                easing.type: root.curve
            }
            NumberAnimation {
                target: scaleT; property: "xScale"
                from: root.glitchy ? 1.04 : (root.flat ? 1 : 0.98)
                to: 1
                duration: root.openDuration
                easing.type: root.curve
            }

            NumberAnimation {
                target: shiftT; property: "y"
                from: root.offsetY; to: 0
                duration: root.openDuration
                easing.type: root.curve
            }

            // The sideways kick is the glitch signature; every other direction
            // just travels in a straight line.
            SequentialAnimation {
                NumberAnimation {
                    target: shiftT; property: "x"
                    from: root.glitchy ? -7 : root.offsetX
                    to: root.glitchy ? 5 : 0
                    duration: Math.max(1, root.openDuration * (root.glitchy ? 0.25 : 1))
                    easing.type: root.curve
                }
                NumberAnimation {
                    target: shiftT; property: "x"
                    to: 0
                    duration: root.glitchy ? Math.max(1, root.openDuration * 0.35) : 1
                    easing.type: Easing.OutCubic
                }
            }
        }

        ScriptAction {
            script: {
                root.opacity = 1;
                scaleT.xScale = 1;
                scaleT.yScale = 1;
                shiftT.x = 0;
                shiftT.y = 0;
            }
        }
    }

    // --- close: back out the way it came in
    SequentialAnimation {
        id: closeSeq

        ParallelAnimation {
            NumberAnimation {
                target: root; property: "opacity"
                to: 0
                duration: root.closeDuration
                easing.type: root.curve
            }
            NumberAnimation {
                target: scaleT; property: "yScale"
                to: root.flat ? 1 : (root.glitchy ? 0.82 : 0.97)
                duration: root.closeDuration
                easing.type: root.curve
            }
            NumberAnimation {
                target: scaleT; property: "xScale"
                to: root.glitchy ? 1.05 : (root.flat ? 1 : 0.99)
                duration: root.closeDuration
                easing.type: root.curve
            }
            NumberAnimation {
                target: shiftT; property: "y"
                to: root.offsetY
                duration: root.closeDuration
                easing.type: root.curve
            }
            SequentialAnimation {
                NumberAnimation {
                    target: shiftT; property: "x"
                    to: root.glitchy ? 6 : root.offsetX
                    duration: Math.max(1, root.closeDuration * (root.glitchy ? 0.3 : 1))
                    easing.type: root.curve
                }
                NumberAnimation {
                    target: shiftT; property: "x"
                    to: root.glitchy ? -10 : root.offsetX
                    duration: root.glitchy ? Math.max(1, root.closeDuration * 0.4) : 1
                }
            }
        }

        ScriptAction { script: root.closeFinished() }
    }
}
