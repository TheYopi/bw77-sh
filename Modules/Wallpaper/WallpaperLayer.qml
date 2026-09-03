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
        PanelWindow {
            screen: screenScope.modelData
            visible: screenScope.enabled

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

        // --- backdrop surface: matched by the niri layer-rule so the overview
        //     has a wallpaper behind the workspaces instead of flat colour.
        PanelWindow {
            screen: screenScope.modelData
            visible: screenScope.enabled && Settings.wallpaper.niriBackdrop

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "bw77-backdrop"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.bgDeep

            WallpaperSurface {
                anchors.fill: parent
                src: screenScope.src
                // The backdrop sits behind everything in the overview, so it is
                // dimmed and optionally blurred to keep the workspace
                // thumbnails readable against it.
                opacity: Settings.wallpaper.backdropDim
                blurAmount: Settings.wallpaper.backdropBlur
            }
        }
    }
}
