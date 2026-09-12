import QtQuick
import qs.Config

/* Just the widget. Positioning and editing live outside it. */
Loader {
    id: root

    property var config: null

    sourceComponent: {
        if (!config) return null;
        switch (config.type) {
        case "sysmon":     return sysmonC;
        // The per-device monitors are the same panel scoped to one device; see
        // SysMonPanel.kind. One component each rather than one parameterised
        // component, because a Loader picks its sourceComponent before the
        // config is attached and `kind` has to be set at construction.
        case "cpu":        return cpuC;
        case "memory":     return memoryC;
        case "network":    return networkC;
        case "gpu":        return gpuC;
        case "visualizer": return visualizerC;
        case "media":      return mediaC;
        case "clock":      return clockC;
        case "battery":    return batteryC;
        default:           return null;
        }
    }

    onLoaded: if (item.config !== undefined) item.config = root.config

    Component { id: sysmonC;     SysMonPanel { kind: "sysmon" } }
    Component { id: cpuC;        SysMonPanel { kind: "cpu" } }
    Component { id: memoryC;     SysMonPanel { kind: "memory" } }
    Component { id: networkC;    SysMonPanel { kind: "network" } }
    Component { id: gpuC;        SysMonPanel { kind: "gpu" } }
    Component { id: visualizerC; VisualizerPanel {} }
    Component { id: mediaC;      MediaPanel {} }
    Component { id: clockC;      ClockPanel {} }
    Component { id: batteryC;    BatteryPanel {} }
}
