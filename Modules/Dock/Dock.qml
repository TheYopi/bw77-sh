import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * Application dock.
 *
 * Pinned entries first, then anything running that is not pinned. Hovering
 * magnifies the icon under the cursor and its neighbours, falling off with
 * distance - the Dash-to-Dock behaviour, which needs the neighbours to move or
 * the row jitters as the cursor crosses each boundary.
 *
 * Autohide keeps the surface alive and slides the dock out of view instead of
 * destroying it, so the reveal is instant.
 *
 * Two styles, matching the bar:
 *
 *   floating - a detached block sized to its icons, inset from the edge by its
 *              own margins. Alignment moves the whole block along the edge.
 *   attached - runs the full length of its edge and sits flush against it.
 *              Alignment moves the icons inside it instead.
 *
 * Geometry is done with x/y bindings rather than anchors. Anchors were what
 * broke switching alignment: `left`, `right` and `horizontalCenter` are
 * mutually exclusive, and when three separate bindings re-evaluate to swap
 * between them there is a moment where two are set at once. QML rejects the
 * conflicting pair with a warning and leaves whichever anchors survived, which
 * is how going left -> centre stretched the dock across the whole monitor and
 * left it there. One binding per axis cannot get into that state.
 */
Variants {
    model: {
        const wanted = Settings.dock.monitors;
        if (!wanted || wanted.length === 0) return Quickshell.screens;
        return Quickshell.screens.filter(s => wanted.indexOf(s.name) !== -1);
    }

    PanelWindow {
        id: win
        required property var modelData

        readonly property bool vertical: Settings.dock.position === "left"
                                      || Settings.dock.position === "right"
        readonly property bool attached: Settings.dock.style === "attached"
        readonly property bool hides: Settings.dock.hideMode !== "none"
        readonly property int iconSize: Settings.dock.iconSize

        // Distance from the screen edge to the dock body. Attached is flush by
        // definition; floating uses its own margin.
        readonly property int edgeMargin:
            (win.attached ? 0 : Settings.dock.marginV) + win.barClearance

        // Inset from each end of the edge. Attached spans the whole thing.
        readonly property int alongMargin: win.attached ? 0 : Settings.dock.marginH

        /*
         * A dock sharing an edge with the bar.
         *
         * When the dock reserves space the compositor stacks the two exclusive
         * zones and they cannot overlap. A hiding dock reserves nothing, so
         * nothing keeps it off the bar and the two draw on top of each other -
         * it has to step around the bar itself.
         */
        readonly property int barClearance: {
            if (win.vertical) return 0;                 // the bar only takes top or bottom
            if (!win.hides) return 0;                   // layershell already stacks us
            if (!Settings.bar.exclusive) return 0;      // the bar is not claiming the strip
            if (Settings.bar.position !== Settings.dock.position) return 0;
            return Settings.bar.height
                 + (Settings.bar.style === "floating" ? Settings.bar.marginV * 2 : 0);
        }

        // Three different measurements, and conflating them is what made the
        // dock look oversized:
        //
        //   bodyThickness   - the visible panel. Sized to the icon at REST plus
        //                     padding and the indicator lane. This is what you
        //                     see and what the settings sliders should govern.
        //   thickness       - the space the dock occupies including room for a
        //                     magnified icon to grow into. Used for the
        //                     exclusive zone so a hovered icon is not clipped.
        //   windowThickness - the whole surface, with headroom for tooltips and
        //                     context menus, which are children of the items.
        readonly property int indicatorLane: Settings.dock.showIndicators ? 8 : 0

        readonly property int bodyThickness:
            iconSize + Settings.dock.padding * 2 + indicatorLane

        readonly property int magnifiedIcon:
            Math.round(iconSize * (Settings.dock.magnify ? Settings.dock.magnifyScale : 1))

        readonly property int thickness:
            Math.max(bodyThickness, magnifiedIcon + Settings.dock.padding * 2 + indicatorLane)

        /*
         * Room for tooltips. Only tooltips draw inside this window - the
         * context menu has its own surface - so the reserve just needs to clear
         * a single label.
         *
         * Beside a vertical dock that label extends across the reserve rather
         * than down it, so 60px of headroom cut every application name off
         * mid-word. The reserve and the width the label is allowed to use are
         * the same number, declared once.
         */
        readonly property int tooltipSpace: win.vertical ? 360 : 260
        readonly property int popupReserve:
            win.vertical ? tooltipSpace + Theme.space2 + 8 : 60
        readonly property int windowThickness: thickness + win.edgeMargin + popupReserve

        property bool revealed: !hides

        screen: modelData
        visible: Settings.dock.enabled
        color: "transparent"

        WlrLayershell.layer: win.hides ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.namespace: "bw77-dock"

        // The dock never takes keyboard focus; its menu surface does that while
        // it is open.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        /*
         * The surface is a thin strip normally and the whole screen while a
         * context menu is open.
         *
         * A strip along one edge, sized to the dock plus a little headroom for
         * tooltips. It does not expand for menus: those are drawn by
         * DockMenuSurface, which has the whole screen and so cannot clip a long
         * window list.
         */
        anchors {
            top: Settings.dock.position === "top" || win.vertical
            bottom: Settings.dock.position === "bottom" || win.vertical
            left: Settings.dock.position === "left" || !win.vertical
            right: Settings.dock.position === "right" || !win.vertical
        }

        implicitWidth: win.vertical ? win.windowThickness : 0
        implicitHeight: win.vertical ? 0 : win.windowThickness

        // Normal + explicit zone, so the reserved strip matches the dock rather
        // than the oversized window.
        // Pinned to the strip regardless of the surface size, or opening a menu
        // would briefly reserve the entire screen and shove every window aside.
        exclusionMode: win.hides ? ExclusionMode.Ignore : ExclusionMode.Normal
        exclusiveZone: win.hides ? 0 : win.thickness + win.edgeMargin

        // --- items
        readonly property var entries: {
            const out = [];
            const seen = {};

            if (Settings.dock.showLauncher && Settings.dock.launcherPosition === "start")
                out.push({ id: "", pinned: false, action: "launcher" });

            const pinned = Settings.dock.pinned;
            for (let i = 0; i < pinned.length; i++) {
                const key = Apps.normalise(pinned[i]);
                if (seen[key]) continue;
                seen[key] = true;
                out.push({ id: pinned[i], pinned: true });
            }

            if (Settings.dock.showRunning) {
                const ids = Apps.runningIds;
                for (let i = 0; i < ids.length; i++) {
                    const id = ids[i];
                    if (!id || seen[id]) continue;
                    if (Apps.isPinned(id)) continue;
                    seen[id] = true;
                    out.push({ id: id, pinned: false });
                }
            }

            if (Settings.dock.showLauncher && Settings.dock.launcherPosition === "end")
                out.push({ id: "", pinned: false, action: "launcher" });

            return out;
        }

        // Input lands on the dock and nowhere else. The context menu is drawn
        // by its own surface now, so there is no oversized catcher around the
        // dock swallowing clicks.
        mask: Region { item: dockBody }

        /*
         * Where a run of `len` sits inside `span` for the current alignment.
         *
         * "start" and "end" are deliberately side-neutral: on a bottom dock
         * they mean left and right, on a left dock they mean top and bottom.
         * One function serves both axes and both styles.
         */
        function alignOffset(span, len) {
            switch (Settings.dock.alignment) {
            case "start": return 0;
            case "end":   return Math.max(0, span - len);
            default:      return Math.max(0, Math.round((span - len) / 2));
            }
        }

        Item {
            id: dockBody

            property int hoveredIndex: -1

            // The edge this dock lives on, end to end.
            readonly property real edgeSpan: win.vertical ? win.height : win.width

            // What the icons themselves occupy along that edge.
            readonly property real contentLength: win.vertical ? layout.height : layout.width

            /*
             * Attached runs the full edge. Floating hugs its icons, so the dock
             * grows and shrinks as applications open and close - which is the
             * behaviour that was there before and worth keeping as the default.
             */
            readonly property real bodyLength: win.attached
                ? dockBody.edgeSpan
                : Math.max(1, dockBody.contentLength + Settings.dock.padding * 2)

            width: win.vertical ? win.bodyThickness : dockBody.bodyLength
            height: win.vertical ? dockBody.bodyLength : win.bodyThickness

            /*
             * Two independent axes.
             *
             * ALONG the edge: alignment. Attached is already the full length so
             * it starts at zero and aligns its icons internally instead.
             */
            readonly property real alongOffset: win.attached
                ? 0
                : win.alongMargin + win.alignOffset(
                      dockBody.edgeSpan - win.alongMargin * 2, dockBody.bodyLength)

            /*
             * ACROSS the edge: the margin when revealed, and far enough out to
             * leave only the hot edge showing when hidden.
             */
            readonly property real acrossOffset: win.revealed
                ? win.edgeMargin
                : -(win.bodyThickness - Settings.dock.revealSize)

            x: win.vertical
                ? (Settings.dock.position === "left"
                    ? dockBody.acrossOffset
                    : win.width - dockBody.width - dockBody.acrossOffset)
                : dockBody.alongOffset

            y: win.vertical
                ? dockBody.alongOffset
                : (Settings.dock.position === "top"
                    ? dockBody.acrossOffset
                    : win.height - dockBody.height - dockBody.acrossOffset)

            // The dock's own reveal slide belongs to the dock category, not to
            // the global durNormal - otherwise Motion by category > Dock moved
            // the dock's menu and its icons but left the dock itself alone.
            Behavior on x {
                NumberAnimation {
                    duration: Theme.durationFor("dock")
                    easing.type: Theme.curveFor("dock")
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: Theme.durationFor("dock")
                    easing.type: Theme.curveFor("dock")
                }
            }

            NotchRect {
                anchors.fill: parent
                fillColor: Theme.bgBase
                // The dock floats against the desktop rather than sitting in a
                // screen edge, so like a floating bar it wears the decoration
                // as its own outline.
                strokeColor: Settings.decoration.style === "none"
                    ? Theme.alpha(Theme.border, 0.9)
                    : (Settings.decoration.colorCustom !== ""
                        ? Settings.decoration.colorCustom
                        : Theme.c(Settings.decoration.colorRole))
                strokeWidth: Settings.decoration.style === "border"
                    ? Settings.decoration.thickness : 1
                // An attached dock is part of the screen frame, not a block
                // resting on it, so it squares off - same rule as the bar.
                notch: win.attached ? 0 : Settings.dock.notch
                notchTopLeft: false
                notchTopRight: false
                notchBottomRight: true
                notchBottomLeft: false
            }

            Scanlines { anchors.fill: parent; anchors.margins: 1 }

            // The rule sits on the edge facing the desktop: above a bottom dock,
            // below a top one, and so on.
            EdgeDecoration {
                edge: win.vertical
                    ? (Settings.dock.position === "left" ? "right" : "left")
                    : (Settings.dock.position === "bottom" ? "top" : "bottom")
                visible: Settings.decoration.style !== "border"
                         && Settings.decoration.style !== "none"
            }

            Grid {
                id: layout

                // Floating: the body is sized to this, so aligning inside it is
                // a no-op and centring is exact. Attached: the body is the full
                // edge and this is where alignment actually lands.
                readonly property real alignedOffset: win.attached
                    ? Settings.dock.padding + win.alignOffset(
                          dockBody.bodyLength - Settings.dock.padding * 2,
                          dockBody.contentLength)
                    : Math.round((dockBody.bodyLength - dockBody.contentLength) / 2)

                x: win.vertical
                    ? Math.round((dockBody.width - layout.width) / 2)
                    : layout.alignedOffset
                y: win.vertical
                    ? layout.alignedOffset
                    : Math.round((dockBody.height - layout.height) / 2)

                columns: win.vertical ? 1 : win.entries.length
                rows: win.vertical ? win.entries.length : 1
                spacing: Settings.dock.spacing

                Repeater {
                    model: win.entries

                    DockItem {
                        required property var modelData
                        required property int index

                        appId: modelData.id
                        pinned: modelData.pinned
                        action: modelData.action !== undefined ? modelData.action : ""
                        itemIndex: index
                        hoveredIndex: dockBody.hoveredIndex
                        vertical: win.vertical
                        baseSize: win.iconSize
                        indicatorLane: win.indicatorLane
                        tooltipSpace: win.tooltipSpace

                        onHoverChanged: (i, on) => {
                            dockBody.hoveredIndex = on ? i : -1;
                        }

                        menuOpenFor: DockMenuState.open
                            && DockMenuState.appId === modelData.id

                        onMenuRequested: DockMenuState.toggleFor(
                            modelData.id, modelData.pinned, this, win, win.modelData)

                        onMenuDismissed: DockMenuState.close()
                    }
                }
            }

        }
    }
}
