import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Audio spectrum.
 *
 * Drawn on a single Canvas rather than as a grid of Rectangles.
 *
 * The previous version built one SegmentBar per band, each of which built one
 * Rectangle per segment with its own colour Behavior - 32 x 14 = 448 animated
 * scene-graph items, every one re-evaluating at the spectrum's frame rate. That
 * is what made this widget dominate the shell's memory and CPU. One Canvas
 * paints the same picture with a single item and no per-segment bindings.
 */
WidgetFrame {
    id: root
    accentColor: Theme.accent
    property var config: ({})

    readonly property int bandCount: (config && config.bands) ? config.bands : 32
    readonly property int segments: (config && config.segments) ? config.segments : 14
    readonly property int framerate: (config && config.framerate) ? config.framerate : 60
    padding: Theme.space3

    Component.onCompleted: {
        Audio.bands = bandCount;
        Audio.framerate = framerate;
        Audio.acquireVisualizer();
    }
    Component.onDestruction: Audio.releaseVisualizer()

    /*
     * No heading and no device name.
     *
     * The sink name was kept on the argument that speakers and headphones both
     * connected give no other clue which output the bars belong to. That is
     * true and still not worth a permanent line of text on the desktop - the
     * bars are the widget, and the question comes up rarely enough that Quick
     * Settings is the right place to answer it.
     */
    Canvas {
        id: canvas

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // Cooperative keeps the paint off the render thread's critical path.
        renderStrategy: Canvas.Cooperative
        renderTarget: Canvas.FramebufferObject

        // Colours are resolved once per paint rather than per segment.
        readonly property color litColor: Theme.accent
        readonly property color hotColor: Theme.danger
        readonly property color idleColor: Theme.alpha(Theme.border, 0.55)

        Connections {
            target: Audio
            function onSpectrumChanged() { canvas.requestPaint(); }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const spectrum = Audio.spectrum;
            const bands = spectrum.length;
            if (bands === 0 || width <= 0 || height <= 0) return;

            const gap = 3;
            const segGap = 2;
            const barWidth = Math.max(1, (width - gap * (bands - 1)) / bands);
            const segHeight = Math.max(1, (height - segGap * (root.segments - 1)) / root.segments);

            for (let b = 0; b < bands; b++) {
                const level = Math.max(0, Math.min(1, spectrum[b] || 0));
                const lit = Math.round(level * root.segments);
                const x = b * (barWidth + gap);

                // Cyan through the range, crimson at the top - the same colour
                // logic the game uses for a reading running hot.
                ctx.fillStyle = level > 0.8 ? canvas.hotColor : canvas.litColor;

                for (let s = 0; s < root.segments; s++) {
                    // Segments fill from the bottom up.
                    if (s === lit) ctx.fillStyle = canvas.idleColor;
                    const y = height - (s + 1) * segHeight - s * segGap;
                    ctx.fillRect(x, y, barWidth, segHeight);
                }
            }
        }
    }

    CyberText {
        anchors.centerIn: parent
        visible: Audio.silent
        text: Settings.t("No signal")
        role: "label"
        color: Theme.textMuted
    }
}
