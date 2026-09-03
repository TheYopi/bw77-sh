import QtQuick
import Quickshell
import qs.Config
import qs.Bar.Widgets

/*
 * Resolves a settings entry like { "id": "clock", "format": "HH:mm" } to a
 * component and hands it its config. Adding a widget means adding one file and
 * one line to the map below.
 *
 * `modelData` must be the required property rather than something derived from
 * it: once a delegate declares any required property, Qt stops exposing
 * modelData as a context property, and a bare `modelData` in the delegate would
 * silently resolve to the enclosing PanelWindow's screen instead.
 */
Loader {
    id: host

    required property var modelData
    property var screenRef: null
    property string section: "left"

    readonly property var config: modelData
    readonly property string widgetId:
        (config && config.id !== undefined) ? config.id : ""

    // Keep this simple. Two previous attempts to make the Loader react to the
    // loaded widget - an explicit width, then a visibility binding reading
    // item.visible - both collapsed every widget to nothing. A Loader's own
    // size is derived from its item, so conditions here feed back into
    // themselves. Widgets that want to disappear collapse their own
    // implicitWidth instead; see BarItem.
    visible: status === Loader.Ready
    height: Settings.bar.height

    sourceComponent: {
        switch (widgetId) {
        case "launcher":       return launcherC;
        case "controlCenter":  return controlCenterC;
        case "quickSettings":  return quickSettingsC;
        case "workspaces":     return workspacesC;
        case "activeWindow":   return activeWindowC;
        case "clock":          return clockC;
        case "sysmon":         return sysmonC;
        case "tray":           return trayC;
        case "volume":         return volumeC;
        case "network":        return networkC;
        case "battery":        return batteryC;
        case "keyboardLayout": return keyboardC;
        case "session":        return sessionC;
        case "spacer":         return spacerC;
        default:
            console.warn(`bw77: unknown bar widget "${widgetId}"`);
            return null;
        }
    }

    onLoaded: {
        if (item.config !== undefined) item.config = host.config;
        if (item.screenRef !== undefined) item.screenRef = host.screenRef;

        // Set BW77_DEBUG_BAR=1 to print what each widget actually measured.
        // A widget reporting width 0 is a sizing problem; a widget that never
        // prints at all never resolved to a component.
        if (Quickshell.env("BW77_DEBUG_BAR"))
            Qt.callLater(() => console.log(
                `bw77 bar: id=${host.widgetId}`
                + ` visible=${item.visible}`
                + ` w=${Math.round(item.implicitWidth)}`
                + ` h=${Math.round(item.implicitHeight)}`
                + ` loaderW=${Math.round(host.width)}`));
    }

    Component { id: launcherC;     LauncherButton {} }
    Component { id: controlCenterC; ControlCenterButton {} }
    Component { id: quickSettingsC; QuickSettingsButton {} }
    Component { id: workspacesC;   Workspaces {} }
    Component { id: activeWindowC; ActiveWindow {} }
    Component { id: clockC;        Clock {} }
    Component { id: sysmonC;       SysMonWidget {} }
    Component { id: trayC;         Tray {} }
    Component { id: volumeC;       Volume {} }
    Component { id: networkC;      Network {} }
    Component { id: batteryC;      Battery {} }
    Component { id: keyboardC;     KeyboardLayout {} }
    Component { id: sessionC;      SessionButton {} }
    Component { id: spacerC;       Item { property var config; width: config && config.width ? config.width : 16 } }
}
