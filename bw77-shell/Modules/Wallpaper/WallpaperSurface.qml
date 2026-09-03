import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Config
import qs.Common
import qs.Services

/*
 * The wallpaper image, its transition, and the overlays.
 *
 * Separate from the window so it can be drawn twice: once as an ordinary
 * background surface, and once as a niri backdrop surface.
 *
 * The current image is ALWAYS fully opaque. An earlier version animated its
 * opacity up from zero on every change, which meant any interruption - a
 * settings reload, a second change mid-animation, the duration going to zero
 * because animation speed changed - left it stuck at zero and the wallpaper
 * simply vanished until the shell restarted.
 *
 * Instead the OUTGOING image is held on a layer above and faded out. If that
 * animation is ever interrupted, the worst case is a stale frame sitting there,
 * which a watchdog clears - never a blank desktop.
 */
Item {
    id: root

    property string src: ""
    property real blurAmount: 0

    // Colour mode resolves through the same roles as the rest of the shell, so
    // switching palette repaints the desktop with everything else.
    readonly property bool colorMode: Settings.wallpaper.mode === "color"

    readonly property color fillA: Settings.wallpaper.colorCustom !== ""
        ? Settings.wallpaper.colorCustom
        : Theme.c(Settings.wallpaper.colorRole)

    readonly property color fillB: Settings.wallpaper.colorCustom2 !== ""
        ? Settings.wallpaper.colorCustom2
        : Theme.c(Settings.wallpaper.colorRole2)

    // --- flat or gradient fill
    Rectangle {
        anchors.fill: parent
        visible: root.colorMode
        color: root.fillA

        // A gradient needs a direction; Gradient only runs vertically, so the
        // angle is applied by rotating an oversized child. The diagonal of the
        // surface is the smallest size that still covers it at any rotation.
        Item {
            // Clipped for the same reason as the Control Center preview. Here
            // the overflow falls off the edge of the screen so it was never
            // visible, but the compositor was still being handed a square with
            // roughly 2.4x the area of the surface.
            anchors.fill: parent
            clip: true
            visible: Settings.wallpaper.colorStyle === "gradient"

            Item {
                anchors.centerIn: parent
                width: Math.sqrt(parent.width * parent.width + parent.height * parent.height)
                height: width
                rotation: Settings.wallpaper.gradientAngle

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.fillA }
                    GradientStop { position: 1.0; color: root.fillB }
                }
            }
            }
        }

        Behavior on color { ColorAnimation { duration: Theme.durSlow } }
    }

    /*
     * --- current image, never animated
     *
     * `sourceSize` is the single most important line in this file. Without it
     * an Image decodes at the file's native resolution and holds the result as
     * ARGB32 - a 6000x4000 photo is 91 MB in memory, plus the same again once
     * it is uploaded as a texture, and it is scaled down to the surface for
     * display anyway. Bounding the decode to the surface makes that 14 MB on a
     * 1440p screen. Wallpapers whose aspect ratio differs from the screen are
     * scaled up slightly by PreserveAspectCrop afterwards, which at wallpaper
     * scale is not visible.
     *
     * `cache` was false, which meant the background surface and the niri
     * backdrop surface each decoded the same file independently, and every
     * additional monitor added another pair. Cached, they share one pixmap.
     */
    Image {
        id: current
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.width
        sourceSize.height: root.height
        cache: true
        source: root.colorMode ? "" : root.src
        opacity: 1
        visible: !root.colorMode && root.blurAmount <= 0
    }

    /*
     * Blur is a separate pass over the same image, used by the overview
     * backdrop so workspace thumbnails stay readable against it.
     *
     * Behind a Loader, because assigning an item as a MultiEffect source forces
     * `layer.enabled` on it - a full-screen offscreen buffer, allocated and
     * held for as long as the effect exists. Setting `visible: false` and
     * `blurEnabled: false` does not undo that. The ordinary background surface
     * has blurAmount 0 and never blurs, so it was paying for a buffer it could
     * not use; now it does not build the effect at all.
     */
    Loader {
        anchors.fill: parent
        active: !root.colorMode && root.blurAmount > 0

        sourceComponent: MultiEffect {
            source: current
            blurEnabled: true
            blur: root.blurAmount
            // blurMax sizes the downsample pyramid, so a fixed 64 pays for the
            // largest blur the effect can do no matter what is asked for.
            blurMax: Math.max(8, Math.ceil(root.blurAmount * 32))
            autoPaddingEnabled: false
        }
    }

    // --- outgoing image, sits above and fades away
    Image {
        id: outgoing
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.width
        sourceSize.height: root.height
        cache: true
        opacity: 0
        visible: opacity > 0

        // Driven by the category's Direction. Left at zero for every direction
        // that does not travel, so the default fade is unchanged.
        transform: Translate { id: outShift; x: 0; y: 0 }
    }

    property string _previous: ""

    /*
     * --- the "wallpaper" motion category
     *
     * This surface used to hardcode Theme.durSlow for the cross-fade, 260 for
     * the glitch swap and 180 for the tear bands, so all three controls under
     * Motion by category > Wallpaper were inert - the category had no consumer
     * anywhere in the shell.
     *
     * Duration and Curve now drive the swap. Direction moves the outgoing frame
     * as it leaves: up/down/left/right slide it off, and fade, scale, auto and
     * glitch leave it in place and let opacity do the work, which is what the
     * shipped defaults do.
     */
    readonly property int swapDuration: Math.max(1, Theme.durationFor("wallpaper"))
    readonly property int swapCurve: Theme.curveFor("wallpaper")

    readonly property string swapDirection: Theme.directionFor("wallpaper")

    // Travel is a fraction of the surface rather than a fixed pixel count: an
    // 18px slide that reads correctly on a panel is invisible on a 4K desktop.
    readonly property int swapTravel: Math.round(Math.max(root.width, root.height) * 0.06)

    readonly property int swapOffsetX: swapDirection === "left" ? -swapTravel
        : swapDirection === "right" ? swapTravel : 0
    readonly property int swapOffsetY: swapDirection === "up" ? -swapTravel
        : swapDirection === "down" ? swapTravel : 0

    onSrcChanged: {
        if (colorMode) return;
        const prev = _previous;
        _previous = src;

        if (!prev || prev === src) return;
        if (Settings.wallpaper.transition === "none" || Theme.reducedMotion
            || !Settings.animations.wallpaperTransition) return;

        outgoing.source = prev;
        outgoing.opacity = 1;
        outShift.x = 0;
        outShift.y = 0;

        if (Settings.wallpaper.transition === "glitch") glitchSwap.restart();
        else fadeSwap.restart();
    }

    SequentialAnimation {
        id: fadeSwap
        ParallelAnimation {
            NumberAnimation {
                target: outgoing; property: "opacity"
                to: 0
                duration: root.swapDuration
                easing.type: root.swapCurve
            }
            NumberAnimation {
                target: outShift; property: "x"
                to: root.swapOffsetX
                duration: root.swapDuration
                easing.type: root.swapCurve
            }
            NumberAnimation {
                target: outShift; property: "y"
                to: root.swapOffsetY
                duration: root.swapDuration
                easing.type: root.swapCurve
            }
        }
        ScriptAction {
            script: {
                outgoing.source = "";
                outShift.x = 0;
                outShift.y = 0;
            }
        }
    }

    /*
     * The glitch swap keeps its own shorter shape - the tear bands are the
     * point of it and they should not be left hanging - but it is scaled off
     * the category rather than off the old fixed 260ms, so Duration still moves
     * it. The bands are a fixed fraction of the same figure.
     */
    SequentialAnimation {
        id: glitchSwap
        ScriptAction { script: tearLayer.active = true }
        ParallelAnimation {
            NumberAnimation {
                target: outgoing; property: "opacity"
                to: 0
                duration: Math.max(1, root.swapDuration * 0.45)
                easing.type: root.swapCurve
            }
            NumberAnimation {
                target: outShift; property: "x"
                to: root.swapOffsetX
                duration: Math.max(1, root.swapDuration * 0.45)
                easing.type: root.swapCurve
            }
            NumberAnimation {
                target: outShift; property: "y"
                to: root.swapOffsetY
                duration: Math.max(1, root.swapDuration * 0.45)
                easing.type: root.swapCurve
            }
        }
        ScriptAction {
            script: {
                tearLayer.active = false;
                outgoing.source = "";
                outShift.x = 0;
                outShift.y = 0;
            }
        }
    }

    // Safety net: if a transition is interrupted the outgoing frame could be
    // left covering the wallpaper, so clear it unconditionally after a beat.
    Timer {
        running: outgoing.opacity > 0
        interval: 2000
        onTriggered: {
            outgoing.opacity = 0;
            outgoing.source = "";
        }
    }

    // Horizontal tear bands sweep across during the swap.
    Loader {
        id: tearLayer
        anchors.fill: parent
        active: false
        sourceComponent: Item {
            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    width: parent.width
                    height: 4 + Math.random() * 22
                    y: Math.random() * parent.height
                    color: index % 2 === 0
                        ? Theme.alpha(Theme.accent, 0.35)
                        : Theme.alpha(Theme.danger, 0.35)

                    NumberAnimation on x {
                        from: (Math.random() - 0.5) * 80
                        to: 0
                        duration: Math.max(1, root.swapDuration * 0.3)
                        easing.type: root.swapCurve
                    }
                }
            }
        }
    }

    Scanlines { drift: true; anchors.fill: parent; strength: Settings.fx.scanlineOpacity * 0.6 }
}
