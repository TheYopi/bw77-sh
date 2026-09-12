import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Config
import qs.Common
import qs.Services

/*
 * Host for anchored bar popups. One full-screen transparent layer that dims
 * nothing, closes on outside click, and positions the content under whichever
 * widget opened it.
 */
PanelWindow {
    id: root

    screen: Popups.anchorScreen
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bw77-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore

    // Click anywhere outside the panel to dismiss.
    MouseArea {
        anchors.fill: parent
        onClicked: Popups.close()
    }

    GlitchBox {
        category: "bar"
        id: surfaceAnim
        anchors.fill: parent
        shown: Popups.open

        Panel {
            id: card

            // Matches the quick settings panel: these are surfaces in their own
            // right, not cards resting on one, so they take the base background
            // rather than the raised tone.
            fillColor: Theme.bgBase
            fillOpacity: 0.96

            // Keep the panel on screen when the anchor sits near an edge.
            // Centred under whatever opened it, clamped to the screen so a
            // widget near either end does not push the panel off the edge.
            readonly property real desiredX:
                Popups.anchorX + Popups.anchorWidth / 2 - width / 2
            x: Math.max(Theme.space2,
                 Math.min(root.width - width - Theme.space2, desiredX))

            // Clears the bar, including the gap a floating bar leaves. The
            // surface ignores exclusive zones so it spans the whole screen,
            // which means the bar's height has to be accounted for here.
            readonly property real barSpace: Settings.bar.height
                + (Settings.bar.style !== "attached" ? Settings.bar.marginV : 0)
                + Theme.space2

            y: Settings.bar.position === "top"
                ? Math.min(barSpace, root.height - height - Theme.space2)
                : Math.max(Theme.space2, root.height - barSpace - height)

            width: content.item ? content.item.implicitWidth + padding * 2 : 320
            height: content.item ? content.item.implicitHeight + padding * 2 : 200

            /*
             * --- the card follows its contents rather than jumping to them
             *
             * Most of these popups are a fixed size once they are open. The
             * notification history is not: clearing a message, or emptying the
             * last one and dropping to "Nothing here", changes how tall the
             * content wants to be while the reader is looking at it, and the
             * card resized to match on the next frame - so a message that had
             * just spent 200ms tearing itself out was followed by the whole
             * window snapping shut around the hole.
             *
             * Easing the frame instead lets the card close the gap over roughly
             * the span the row took to leave. Only while the popup is open: a
             * closing surface is being scaled and faded by GlitchBox, and a
             * resize easing underneath that would fight it. The first sizing is
             * not animated either - a Behavior does not run on the binding that
             * establishes a property - so a popup still arrives at its own size.
             */
            Behavior on height {
                enabled: Popups.open && !Theme.reducedMotion
                    && Settings.animations.surfaceOpen
                NumberAnimation {
                    duration: Theme.durationFor("bar")
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on width {
                enabled: Popups.open && !Theme.reducedMotion
                    && Settings.animations.surfaceOpen
                NumberAnimation {
                    duration: Theme.durationFor("bar")
                    easing.type: Easing.OutCubic
                }
            }
            padding: Theme.space4
            serialSeed: Popups.current

            Loader {
                id: content
                anchors.fill: parent
                sourceComponent: {
                    switch (Popups.current) {
                    case "audio":   return audioC;
                    case "clock":   return clockC;
                    case "network": return networkC;
                    case "sysmon":   return sysmonC;
                    case "notifications": return notificationsC;
                    case "trayMenu": return trayMenuC;
                        default:         return null;
                    }
                }
            }

            Component { id: audioC;   AudioPopup {} }
            Component { id: clockC;   CalendarPopup {} }
            Component { id: networkC; NetworkPopup {} }
            Component { id: sysmonC;   SysMonPopup {} }
            Component { id: notificationsC; NotificationsPopup {} }
            Component { id: trayMenuC; TrayMenu {} }
            }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Popups.close()
    }
}
