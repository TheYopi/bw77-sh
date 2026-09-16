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
    /*
     * Where "auto" lands for a surface that does not say.
     *
     * "top", because a caller that names no placement is a dialog in the
     * middle of the screen - the session menu, the polkit prompt, the wallpaper
     * picker, the emoji grid - and a surface belonging to no edge drops in.
     * That is the same fallback Theme.originFor applies to a dead-centre
     * position, so the two agree.
     *
     * It used to be "up", which under the old vocabulary meant "travelling
     * upward" - entering from the BOTTOM. Every centred dialog in the shell
     * rose off the bottom edge of the screen while the Quick Settings drawer
     * beside it came in from the side, for no reason either could state.
     */
    property string autoDirection: "top"

    property int openDuration: Theme.durationFor(root.category)
    property int closeDuration: Theme.exitDuration(Theme.durationFor(root.category))
    property bool enabled: Settings.animations.surfaceOpen

    /*
     * --- arriving and leaving are separately deniable
     *
     * A surface that is rebuilt while it is already on screen must not replay
     * its arrival: a notification toast is destroyed and recreated every time
     * one of its neighbours is added or removed, and replaying the entry each
     * time made a stack of toasts flicker as a whole whenever any one of them
     * changed. So the toast turns its entry off after the first appearance.
     *
     * That is an argument about the ENTRY, and it used to be made by switching
     * `enabled` - which also turned off the exit, on a surface that has one for
     * a reason. Every toast past its first frame therefore vanished instantly
     * instead of tearing out, which is most of them.
     *
     * Two gates, both defaulting to the one flag, so a caller that only wants
     * to deny one of them can say so.
     */
    property bool openEnabled: root.enabled
    property bool closeEnabled: root.enabled

    /*
     * --- arriving and leaving do not share a curve
     *
     * They used to: one `curve` drove both sequences, and the close ran at 85%
     * of the open, so a surface left almost exactly as ceremoniously as it
     * arrived. That is the thing a dismissal must not do. Closing is answering
     * an instruction that has already been given - every millisecond of it is
     * spent between the decision and being finished - so it accelerates away on
     * the exit curve at two thirds the length, while the entrance keeps the
     * category's own curve and its full duration.
     *
     * This is Material's asymmetry, and it is the single change here that is
     * felt most: the shell stops feeling like it is playing its animations back
     * at you.
     */
    readonly property var enterCurve: Theme.bezierFor(root.category)
    readonly property var exitCurve: Theme.curveExit

    readonly property string direction: {
        const d = Theme.directionFor(root.category);
        return d === "auto" ? root.autoDirection : d;
    }

    /*
     * --- which edge the surface comes from
     *
     * One vocabulary for both axes: an edge is always the side the surface
     * STARTS on. That was not true before. "left" and "right" named the
     * starting side, but "up" and "down" named the direction of travel - so
     * "down" and "top" described the same movement and no reader could tell,
     * and a caller deriving a direction from a screen position had to know
     * which convention applied to which axis.
     *
     * The old names still resolve, because they are sitting in settings files
     * and in callers that have not been converted. They map onto the edge they
     * always meant.
     *
     * Anything that is not an edge - fade, scale, glitch - passes through
     * untouched: those describe HOW a surface arrives, not where from.
     */
    readonly property string originEdge: Theme.edgeOf(root.direction)

    // Overrides the pivot when the content bounds are not the right centre.
    property Item originItem: null

    /*
     * --- how far a directional entry travels
     *
     * Off the screen edge, to its resting place. Not a fixed nudge.
     *
     * This was 18px for every surface, on the reasoning that a surface flying
     * in from off-screen reads as sluggish. What it actually produced was a
     * surface that appeared already sitting in its padded position and then
     * shifted by a finger's width - which does not read as arriving from
     * anywhere, because it did not: 18px from a panel resting 60px off the
     * edge still starts 42px inside the screen, fully visible from the first
     * frame.
     *
     * The distance is worked out instead, so a surface begins exactly off the
     * edge it belongs to and slides in. Three parts:
     *
     *   edgeInset  how far this WINDOW sits from the screen edge, for the
     *              surfaces whose window is smaller than the display. Zero for
     *              one that spans it, which is most of them.
     *   pivot      where the drawn content sits inside the window, and how big
     *              it is - childrenRect, the same measurement the scale pivots
     *              on, so the two cannot disagree about what "the surface" is.
     *   direction  which of the four distances to measure.
     *
     * A caller can still pin it: `travel` at anything but -1 wins, for a
     * surface that knows better than this arithmetic does.
     */
    property real edgeInset: 0

    readonly property int edgeTravel: {
        const p = body.pivot;
        if (p.width <= 0 || p.height <= 0) return 0;
        switch (root.originEdge) {
        case "top":    return Math.ceil(root.edgeInset + p.y + p.height);
        case "bottom": return Math.ceil(root.edgeInset + (root.height - p.y));
        case "left":   return Math.ceil(root.edgeInset + p.x + p.width);
        case "right":  return Math.ceil(root.edgeInset + (root.width - p.x));
        }
        return 0;
    }

    // -1 asks for the distance above to be worked out.
    property int travel: -1

    /*
     * --- travel is a distance, so it cannot be negative
     *
     * `direction` says which side the surface comes from and `travel` says how
     * far; the sign of the offset belongs to the direction alone. A caller that
     * derives travel from a size - the quick settings panel hands over its own
     * sheet width - can hand over a negative one before that size exists, and
     * the entry then plays INSIDE OUT: a drawer set to come from the right
     * started on the left and slid right, which is the exit, backwards.
     *
     * Clamping here rather than only at the call site because every caller that
     * measures something can hit this, and a direction control that sometimes
     * does the opposite of what it says is the worst kind of bug to chase.
     */
    readonly property int travelPx:
        Math.max(0, root.travel >= 0 ? root.travel : root.edgeTravel)

    /*
     * Negative is left and up, because that is where the surface starts.
     * Entry animates these to zero; the exit animates back to them, so the
     * way out is the way in reversed without anything having to say so twice.
     */
    readonly property int offsetX: originEdge === "left" ? -travelPx
        : originEdge === "right" ? travelPx : 0
    readonly property int offsetY: originEdge === "top" ? -travelPx
        : originEdge === "bottom" ? travelPx : 0

    readonly property bool glitchy: originEdge === "glitch"
    readonly property bool flat: originEdge === "fade"

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

    /*
     * --- only one of these may be running
     *
     * The two sequences write the SAME five properties on the same three
     * targets - root.opacity, both scales and both translations - and starting
     * one did not stop the other. Whenever a surface was re-shown while it was
     * still closing, or dismissed while it was still opening, both ran at once
     * and fought frame by frame for every property. That is the shell "playing
     * two animations instead of the one that is set": it genuinely was.
     *
     * Quick Settings hits it more than anything else because it is a toggle.
     * The surface is held alive for a moment after closing so the exit can
     * play, and toggling it back on inside that window lands squarely in the
     * overlap - which is why it happened sometimes rather than always.
     *
     * Worse than the visual: each sequence ends with a ScriptAction. openSeq's
     * pins everything to fully-open, so an open finishing during a close
     * snapped the panel back to visible; closeSeq's emits closeFinished, which
     * is the signal for tearing the surface down.
     */
    function play(showing) {
        const animate = showing ? root.openEnabled : root.closeEnabled;

        // Whatever happens next supersedes a pending entry.
        root.openPending = false;
        geometryWait.stop();

        if (!animate || Theme.reducedMotion) {
            openSeq.stop();
            closeSeq.stop();
            opacity = showing ? 1 : 0;
            // Still emitted, and still the only thing that ends the hold on the
            // surface. A caller that has turned the exit off wants it gone at
            // once, not left on screen for want of a signal.
            if (!showing) root.closeFinished();
            return;
        }

        if (showing) {
            /*
             * --- not until there is a geometry to measure
             *
             * The distance is read off the window and the content, and neither
             * exists on the frame the surface is built: a Wayland layer surface
             * has no size until the compositor configures it, and childrenRect
             * is empty until the first layout pass. Starting here would capture
             * a travel of zero and play a fade - which is exactly the bug the
             * quick settings panel had when it measured its own sheet width,
             * and papering over that one surface at a time is how it comes
             * back on the next one.
             *
             * So the entry waits for a size. The backstop is there because a
             * surface with genuinely no content would otherwise wait forever
             * and never be shown at all; after it fires the entry plays with
             * whatever distance it has, which for an empty one is a fade.
             */
            if (!root.geometryReady) {
                root.openPending = true;
                // Held invisible meanwhile, or it would appear un-animated for
                // a frame and then jump back to the start of its entry.
                root.opacity = 0;
                geometryWait.restart();
                return;
            }
            root.startOpen();
            return;
        }
        // The exit needs no equivalent: its tracks are all `to` and have
        // always started from wherever the surface had reached.
        openSeq.stop();
        closeSeq.restart();
    }

    // True while an entry is taking over from an exit that had not finished.
    property bool interrupted: false

    // Both the window and the drawn content have to have been laid out before
    // the distance to the edge means anything.
    readonly property bool geometryReady: root.width > 0 && root.height > 0
        && body.pivot.width > 0 && body.pivot.height > 0

    property bool openPending: false

    function startOpen() {
        root.openPending = false;
        geometryWait.stop();
        root.interrupted = closeSeq.running;
        closeSeq.stop();
        openSeq.restart();
    }

    onGeometryReadyChanged: if (root.geometryReady && root.openPending) root.startOpen()

    Timer {
        id: geometryWait
        interval: 250
        onTriggered: if (root.openPending) root.startOpen()
    }

    onShownChanged: root.play(root.shown)

    /*
     * Through play(), not straight into the sequence.
     *
     * This called openSeq.restart() directly, which walked around the geometry
     * gate in play() - and this is the path a COLD open takes, because the
     * surface is built at the moment it is asked for. So the common case
     * captured a travel of zero and faded, while the one case that did go
     * through play() - reopening inside the close window, where the surface
     * already exists - measured properly and slid. Same surface, two entrances,
     * depending on how recently it had been closed.
     *
     * Every entrance goes through one door now.
     */
    Component.onCompleted: {
        root.interrupted = false;
        if (shown) root.play(true);
        else opacity = 0;
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

        /*
         * --- taking over from an exit that had not finished
         *
         * These tracks carry explicit `from` values because they have to: a
         * freshly built surface sits at opacity 1 and full scale, so without
         * them the first appearance would animate from its final state to its
         * final state and nothing would move. But applying them to a surface
         * that is already half on screen throws it back to invisible and
         * replays - a flinch, right at the moment somebody has asked for it
         * back.
         *
         * So they are used on a cold start and ignored on an interruption,
         * which is what makes reopening mid-close continuous.
         */

        ParallelAnimation {
            // Carries the curve like every other track here. Without it the
            // Curve control did nothing at all on a "fade" category, because
            // opacity was the only property that moved and it was the only one
            // still running on the implicit linear default.
            NumberAnimation {
                target: root; property: "opacity"
                from: root.interrupted ? root.opacity : 0
                to: 1
                duration: root.fadeInDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: root.enterCurve
            }

            NumberAnimation {
                target: scaleT; property: "yScale"
                from: root.interrupted ? scaleT.yScale
                    : (root.flat ? 1 : (root.glitchy ? 0.86 : 0.96))
                to: 1
                duration: root.openDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: root.enterCurve
            }
            NumberAnimation {
                target: scaleT; property: "xScale"
                from: root.interrupted ? scaleT.xScale
                    : (root.glitchy ? 1.04 : (root.flat ? 1 : 0.98))
                to: 1
                duration: root.openDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: root.enterCurve
            }

            NumberAnimation {
                target: shiftT; property: "y"
                from: root.interrupted ? shiftT.y : root.offsetY
                to: 0
                duration: root.openDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: root.enterCurve
            }

            // The sideways kick is the glitch signature; every other direction
            // just travels in a straight line.
            SequentialAnimation {
                NumberAnimation {
                    target: shiftT; property: "x"
                    from: root.interrupted ? shiftT.x
                        : (root.glitchy ? -7 : root.offsetX)
                    to: root.glitchy ? 5 : 0
                    duration: Math.max(1, root.openDuration * (root.glitchy ? 0.25 : 1))
                    easing.type: Easing.Bezier
                easing.bezierCurve: root.enterCurve
                }
                NumberAnimation {
                    target: shiftT; property: "x"
                    to: 0
                    duration: root.glitchy ? Math.max(1, root.openDuration * 0.35) : 1
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.enterCurve
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
                easing.type: Easing.Bezier
                easing.bezierCurve: root.exitCurve
            }
            NumberAnimation {
                target: scaleT; property: "yScale"
                to: root.flat ? 1 : (root.glitchy ? 0.82 : 0.97)
                duration: root.closeDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: root.exitCurve
            }
            NumberAnimation {
                target: scaleT; property: "xScale"
                to: root.glitchy ? 1.05 : (root.flat ? 1 : 0.99)
                duration: root.closeDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: root.exitCurve
            }
            NumberAnimation {
                target: shiftT; property: "y"
                to: root.offsetY
                duration: root.closeDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: root.exitCurve
            }
            SequentialAnimation {
                NumberAnimation {
                    target: shiftT; property: "x"
                    to: root.glitchy ? 6 : root.offsetX
                    duration: Math.max(1, root.closeDuration * (root.glitchy ? 0.3 : 1))
                    easing.type: Easing.Bezier
                easing.bezierCurve: root.exitCurve
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
