import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * One bar per screen, in one of three styles.
 *
 * "attached" spans the screen edge to edge and sits flush against it.
 * "detached" is a chamfered block with its own margins, so it reads as a piece
 * of hardware laid on the desktop rather than part of the frame.
 * "floating" is that same block with the frame taken away: no surface, no
 * outline, just the widgets on the desktop, each carrying its own.
 *
 * Layout is three independent sections; a widget's home is decided entirely by
 * which array in settings.json it appears in.
 */
Variants {
    id: variants

    model: {
        const wanted = Settings.bar.monitors;
        if (!wanted || wanted.length === 0) return Quickshell.screens;
        return Quickshell.screens.filter(s => wanted.indexOf(s.name) !== -1);
    }

    PanelWindow {
        id: bar
        required property var modelData

        /*
         * Three styles, but only two questions to ask about them.
         *
         * The margins, the block width and the corner cut belong to both of
         * the detached styles, so those follow `detached`. The surface behind
         * the widgets and its outline are what "floating" gives up, so those
         * follow `framed`.
         */
        readonly property bool detached: Settings.bar.style !== "attached"
        readonly property bool framed: Settings.bar.style !== "floating"
        readonly property bool atTop: Settings.bar.position === "top"

        // Only one bar should answer a global keybind.
        readonly property bool isPrimary:
            Quickshell.screens.length === 0 || Quickshell.screens[0] === modelData

        readonly property color decorationColor:
            Settings.decoration.colorCustom !== ""
                ? Settings.decoration.colorCustom
                : Theme.c(Settings.decoration.colorRole)

        screen: modelData
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "bw77-bar"

        anchors {
            top: bar.atTop
            bottom: !bar.atTop
            left: true
            right: true
        }

        margins {
            top: bar.detached && bar.atTop ? Settings.bar.marginV : 0
            bottom: bar.detached && !bar.atTop ? Settings.bar.marginV : 0
            left: bar.detached ? Settings.bar.marginH : 0
            right: bar.detached ? Settings.bar.marginH : 0
        }

        implicitHeight: Settings.bar.height
        exclusionMode: Settings.bar.exclusive ? ExclusionMode.Auto : ExclusionMode.Ignore

        /*
         * With no surface, only the widgets take input.
         *
         * The window still spans the whole strip - it has to, for the sections
         * to lay out against and for the exclusion zone to reserve the space -
         * so without a mask a frameless bar would swallow every click in the
         * empty space between its widgets, over a strip that draws nothing.
         */
        mask: bar.framed ? null : widgetMask

        Region {
            id: widgetMask
            Region { item: leftSection }
            Region { item: centerSection }
            Region { item: rightSection }
        }

        // The floating block can be narrower than the screen; the window still
        // spans it so the layout can centre the block inside.
        Item {
            id: body

            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height
            width: (bar.detached && Settings.bar.floatingWidth > 0)
                ? Math.min(parent.width, Settings.bar.floatingWidth)
                : parent.width

            // --- surface
            Loader {
                anchors.fill: parent
                active: bar.detached && bar.framed
                sourceComponent: NotchRect {
                    fillColor: Theme.bgBase
                    // A floating bar carries the decoration in its own outline,
                    // since it has no screen edge to sit against.
                    strokeColor: Settings.decoration.style === "none"
                        ? Theme.alpha(Theme.border, 0.8) : bar.decorationColor
                    strokeWidth: Settings.decoration.style === "border"
                        ? Settings.decoration.thickness : 1
                    notch: Settings.bar.notch
                    // Both cuts on the bar itself - it is the one surface that
                    // spans the whole screen edge, and a single cut on a shape
                    // that wide is invisible.
                    notchTopLeft: true
                    notchTopRight: false
                    notchBottomRight: true
                    notchBottomLeft: false
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: !bar.detached
                color: Theme.bgBase
            }

            /*
             * Lines, but no sweep.
             *
             * Scanlines' own note is that the drift reads as live signal across
             * a whole screen and is imperceptible inside a 74px panel, and that
             * an infinite animation anywhere in the tree pins the render loop
             * at the display's refresh rate for as long as it runs. The bar is
             * the 74px panel in that sentence, and it is on screen permanently
             * on every monitor - so it was holding its own window at full
             * refresh, forever, for a movement nobody can see at that height.
             * The wallpaper still drifts, which is where the effect was always
             * doing the work.
             */
            // Part of the surface, so there are none without one: drawn over
            // the desktop they would be lines across the screen rather than
            // texture on the bar.
            Scanlines { drift: false; anchors.fill: parent; active: bar.framed }

            // --- decoration
            //
            // Shared with the quick settings panel and the dock. The rule goes
            // on the edge facing the desktop, so a bottom-anchored bar draws
            // along its top and vice versa.
            //
            // A floating bar is already fully outlined by its own chamfered
            // frame, so it only takes the decoration when the style is an
            // explicit border - a rule floating in the middle of the screen
            // reads as a stray line rather than an edge.
            EdgeDecoration {
                edge: bar.atTop ? "bottom" : "top"
                visible: !bar.detached && Settings.decoration.style !== "none"
            }

            // Right-click anywhere empty opens quick settings. Declared before
            // the widget rows so widgets keep their own clicks.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: Shell.toggleQuickSettings()
            }

            // --- sections
            Row {
                id: leftSection
                anchors.left: parent.left
                anchors.leftMargin: Settings.bar.sectionPadding
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                spacing: Settings.bar.widgetSpacing

                Repeater {
                    model: Settings.bar.left
                    WidgetHost { screenRef: bar.modelData; section: "left" }
                }
            }

            Row {
                id: centerSection
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                spacing: Settings.bar.widgetSpacing

                Repeater {
                    model: Settings.bar.center
                    WidgetHost { screenRef: bar.modelData; section: "center" }
                }
            }

            Row {
                id: rightSection
                anchors.right: parent.right
                anchors.rightMargin: Settings.bar.sectionPadding
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                spacing: Settings.bar.widgetSpacing

                Repeater {
                    model: Settings.bar.right
                    WidgetHost { screenRef: bar.modelData; section: "right" }
                }
            }
        }
    }
}
