import QtQuick
import qs.Config

/*
 * Horizontal CRT scanlines.
 *
 * Three things about this component used to cost far more than it looked like
 * it should, and all three are worth keeping in mind before changing it:
 *
 * 1. It was `layer.enabled: true`, unconditionally. On the wallpaper that is a
 *    full-screen offscreen buffer per surface - 14 MB at 1440p, 32 MB at 4K -
 *    allocated whether or not scanlines were switched on, and re-rendered in
 *    its entirety on every frame of the drift animation. The lines are opaque
 *    rectangles with no blending between them, so there is nothing a layer buys
 *    here; without it they are one batched draw and the drift is a translation.
 *
 * 2. Each line was an Item wrapping a Rectangle. The wrapper existed only to
 *    create the gap, which Column.spacing does for free.
 *
 * 3. The Repeater built its lines regardless of whether the overlay was
 *    visible, so turning scanlines off in settings hid them without giving
 *    anything back. The model is now gated, so off means gone.
 */
Item {
    id: root

    property real lineSpacing: 3
    property color lineColor: "#000000"
    property real strength: Settings.fx.scanlineOpacity

    // Per-instance opt-out, independent of the global setting.
    property bool active: true

    /*
     * The slow vertical sweep.
     *
     * It reads as "live signal" across a whole screen and is imperceptible
     * inside a 74px panel - but an infinite animation anywhere in the tree
     * pins the render loop at the display's refresh rate for as long as it
     * runs, so 24 panels each running their own copy means the shell never
     * goes idle. Opt in on the big surfaces only.
     */
    property bool drift: false

    readonly property bool _on: active && Settings.fx.scanlines && strength > 0

    // The sweep needs all four: the surface opting in, the setting allowing it,
    // the lines being drawn at all, and motion not being reduced.
    readonly property bool _drifting:
        drift && Settings.fx.scanlineDrift && _on && !Theme.reducedMotion

    visible: _on
    anchors.fill: parent
    clip: true

    Column {
        id: lines

        width: parent.width
        // Overshoot so the drift never exposes a gap at the bottom.
        height: parent.height + root.lineSpacing * 2
        spacing: Math.max(0, root.lineSpacing - 1)

        Repeater {
            model: root._on && root.height > 0
                ? Math.ceil((root.height + root.lineSpacing * 2) / root.lineSpacing)
                : 0

            Rectangle {
                width: lines.width
                height: 1
                color: root.lineColor
                opacity: root.strength
            }
        }

        NumberAnimation on y {
            running: root._drifting
            loops: Animation.Infinite
            from: -root.lineSpacing * 2
            to: 0
            duration: Settings.fx.scanlineDriftDuration
        }
    }
}
