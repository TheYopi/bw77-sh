import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * Background wallpaper, drawn on up to two surfaces per screen.
 *
 * niri's `place-within-backdrop` moves a background layer surface INTO the
 * overview backdrop - which also takes it out of the workspace thumbnails. One
 * surface therefore cannot serve both: matching it gives a wallpaper behind the
 * overview but bare workspaces, and not matching it gives the reverse.
 *
 * So the shell draws two. The plain one keeps its wallpaper inside workspaces;
 * the backdrop one is the only surface the layer-rule matches. Other
 * compositors ignore the second entirely.
 *
 * --- built only when drawn
 *
 * Both used to be created unconditionally and switched off with `visible`. A
 * hidden window keeps everything it was built with - its renderer, the decoded
 * wallpaper, the blur buffers - so turning the backdrop off, or handing the
 * wallpaper to an external tool, hid the surfaces and freed none of it. Each
 * is now created when it has something to draw and destroyed when it does not.
 */
Variants {
    id: layer
    model: Quickshell.screens

    Scope {
        id: screenScope
        required property var modelData

        readonly property string src: Wallpapers.forScreen(modelData.name)
        // An external wallpaper tool only owns the image. Colour mode is drawn
        // by the shell either way, since no such tool is involved.
        readonly property bool enabled: Settings.wallpaper.mode === "color"
                                     || Settings.wallpaper.setCommand === ""

        // --- ordinary background surface: what you see on the desktop and
        //     inside niri's workspace thumbnails.
        LazyLoader {
            active: screenScope.enabled

            PanelWindow {
                screen: screenScope.modelData

                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.namespace: "bw77-wallpaper"

                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: Theme.bgDeep

                WallpaperSurface {
                    anchors.fill: parent
                    src: screenScope.src
                }
            }
        }

        /*
         * --- backdrop surface: matched by the niri layer-rule so the overview
         *     has a wallpaper behind the workspaces instead of flat colour.
         *
         * Built while it is on screen, and not otherwise. This is a full-screen
         * surface per monitor - several screen-sized buffers - and with blur on
         * it also holds a full-screen offscreen copy and the blur's downscaled
         * ones. The overview is the only place any of that is ever seen, and on
         * a compositor without an overview it is seen nowhere, so niri is the
         * only one that gets the surface at all.
         *
         * It outlives the overview by a few seconds so that toggling the
         * overview repeatedly does not rebuild it each time.
         */
        readonly property bool backdropWanted: screenScope.enabled
            && Settings.wallpaper.niriBackdrop
            && Compositor.kind === "niri"

        readonly property bool backdropNow: !Settings.wallpaper.backdropOnDemand
            || Compositor.overviewOpen
            || backdropHold.running

        Timer {
            id: backdropHold
            interval: 5000
        }

        Connections {
            target: Compositor
            function onOverviewOpenChanged() {
                if (Compositor.overviewOpen) backdropHold.stop();
                else backdropHold.restart();
            }
        }

        LazyLoader {
            active: screenScope.backdropWanted && screenScope.backdropNow

            PanelWindow {
                screen: screenScope.modelData

                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.namespace: "bw77-backdrop"

                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: Theme.bgDeep

                WallpaperSurface {
                    anchors.fill: parent
                    src: screenScope.src
                    // The backdrop sits behind everything in the overview, so it
                    // is dimmed and optionally blurred to keep the workspace
                    // thumbnails readable against it.
                    opacity: Settings.wallpaper.backdropDim
                    blurAmount: Settings.wallpaper.backdropBlur
                }
            }
        }
    }
}
