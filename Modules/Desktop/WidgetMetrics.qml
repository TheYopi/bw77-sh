pragma Singleton

import QtQuick
import Quickshell

/*
 * How small each desktop widget is allowed to get, and when it changes shape.
 *
 * These lived as a table inside DesktopWidgetProxy, which meant they only
 * applied while the resize handle was being dragged. Anything else that set a
 * size - a hand-edited settings.json, a config written by an older build, the
 * defaults for a widget whose contents have since grown - bypassed them
 * entirely, and the result was the overlapping text people actually saw. The
 * proxy is not the authority on how small a widget can be; the widget is.
 *
 * So the floors live here and both ends read them: the proxy clamps the drag,
 * and the layer clamps whatever it was handed.
 *
 * `aspect` is the width-to-height ratio past which a widget rearranges itself
 * across rather than down. It is not one global number because the point at
 * which reflowing helps depends on what is in the widget: the system monitor
 * has four stackable rows and wants to break early, the clock is two lines of
 * text and only benefits once it is genuinely letterboxed.
 */
Singleton {
    id: root

    readonly property var table: ({
        // Four metric rows, each needing a label, a number and a sparkline
        // tall enough to read. Below this the graphs collapse into a line.
        "sysmon":     ({ w: 260, h: 240, aspect: 1.5 }),

        /*
         * The per-device monitors, which are the same panel scoped to one
         * device. Their floors are much lower than the combined widget's for
         * the obvious reason: one or two readouts need a fraction of the
         * height four do, and holding them to the same 240px would defeat the
         * point of splitting them out.
         *
         * They break across early - one or two blocks side by side is a strip,
         * which is the shape these are usually wanted in.
         */
        "cpu":        ({ w: 150, h: 96,  aspect: 1.6 }),
        "memory":     ({ w: 150, h: 60,  aspect: 2.0 }),

        // Taller than the other single-metric widgets because it is not one
        // reading: the cell has to clear the 58px at which the secondary line
        // is dropped, or the upload rate never appears. A 60px floor here was
        // a widget that could only ever show half of what it measures.
        "network":    ({ w: 170, h: 96,  aspect: 2.0 }),

        // Up to three blocks - usage, VRAM, temperature - so a little more
        // room than the single-reading ones.
        "gpu":        ({ w: 170, h: 130, aspect: 1.4 }),

        // Bars need vertical room to be a visualiser rather than a texture.
        "visualizer": ({ w: 220, h: 110, aspect: 3.0 }),

        // Artwork, two lines of metadata, the scrub row and the transport row.
        // `aspect` is also the point at which the media body swaps between its
        // landscape and portrait layouts - the widget reads it from here so the
        // "WIDE"/"TALL" readout on the resize handle and the layout that
        // actually appears cannot disagree.
        "media":      ({ w: 280, h: 150, aspect: 1.8 }),

        // The time at headline size, plus the date under it.
        "clock":      ({ w: 200, h: 100, aspect: 2.2 }),

        /*
         * The reading, then up to three detail lines under it, then the meter.
         * The floor is the height at which the first detail line still fits -
         * below that this is a percentage with a bar under it, which the bar
         * widget already does in a fraction of the space.
         *
         * Wide enough for "2h 14m remaining" without eliding, and it breaks
         * across late: the rows are stacked text, so laying them out sideways
         * gains nothing until the widget is genuinely letterboxed.
         */
        "battery":    ({ w: 180, h: 96,  aspect: 2.4 })
    })

    readonly property var fallback: ({ w: 140, h: 90, aspect: 2.0 })

    function of(type) {
        const t = table[type];
        return t !== undefined ? t : fallback;
    }

    function minWidth(type)  { return of(type).w; }
    function minHeight(type) { return of(type).h; }

    // Clamp a stored size up to the floor. Applied on the way out of settings
    // rather than on the way in, so an existing config is corrected on screen
    // without silently rewriting the user's file behind their back.
    function clampWidth(type, w)  { return Math.max(minWidth(type), w || 0); }
    function clampHeight(type, h) { return Math.max(minHeight(type), h || 0); }

    // True once the widget is wide enough that laying it out across beats
    // laying it out down.
    function isWide(type, w, h) {
        if (!h || h <= 0) return false;
        return (w / h) >= of(type).aspect;
    }
}
