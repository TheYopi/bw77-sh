pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Config

/*
 * Default sink/source state plus a spectrum feed for the visualiser widget.
 *
 * The spectrum comes from cava, which is far cheaper and better-behaved than
 * doing an FFT in QML. Quickshell 0.3 also added pipewire peak detection, which
 * is a good fit if you only want a single level meter rather than bands.
 */
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : true
    readonly property string sinkName: sink ? (sink.description || sink.name) : "NO OUTPUT"

    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : true

    // --- per-application playback streams
    //
    // This list is deliberately NOT a reactive binding.
    //
    // Feeding a derived list into PwObjectTracker creates a cycle: tracking a
    // node binds it, binding changes the node's properties, and re-reading
    // those properties rebuilds the list, which re-tracks. That loop churned
    // bind/unbind every frame and segfaulted pipewire.
    //
    // Instead the set is refreshed on a timer and only reassigned when the set
    // of node IDs actually changes, so the tracker sees a stable list.
    property var streams: []

    // Only worth tracking while something is looking at it.
    property bool streamsActive: false

    // Anything actually feeding the default output is, by definition, playing.
    // Guessing from media.class was wrong twice: too loose let screen-recorder
    // capture streams in, too strict dropped Spotify, browsers and games whose
    // nodes do not advertise the class the way I assumed.
    //
    // Quickshell 0.3's link tracker already ignores level-monitoring programs,
    // so this needs no ignore-list of its own.
    PwNodeLinkTracker {
        id: sinkLinks
        node: root.sink
    }

    function _linkedStreams() {
        const out = [];
        const groups = (sinkLinks.linkGroups && sinkLinks.linkGroups.values)
            ? sinkLinks.linkGroups.values : [];
        for (let i = 0; i < groups.length; i++) {
            const g = groups[i];
            if (!g) continue;
            // The sending side of a link into our sink is the application.
            const n = g.source;
            if (!n || !n.audio || !n.isStream) continue;
            if (out.indexOf(n) === -1) out.push(n);
        }
        return out;
    }

    // Used only if link data is unavailable, so the popup degrades to something
    // rather than to nothing.
    function _fallbackStreams() {
        const out = [];
        const all = (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : [];
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (!n || !n.isStream || !n.audio) continue;
            const cls = n.properties ? String(n.properties["media.class"] || "") : "";
            if (cls.indexOf("Input") !== -1) continue;   // capture, not playback
            out.push(n);
        }
        return out;
    }

    function _blacklisted(n) {
        const list = Settings.audio.streamBlacklist;
        if (!list || list.length === 0) return false;
        const p = n.properties || ({});
        const haystack = [
            String(p["application.name"] || ""),
            String(p["node.name"] || ""),
            String(n.name || ""),
            String(n.description || "")
        ].join(" ").toLowerCase();

        for (let i = 0; i < list.length; i++) {
            const needle = String(list[i]).trim().toLowerCase();
            if (needle !== "" && haystack.indexOf(needle) !== -1) return true;
        }
        return false;
    }

    function refreshStreams() {
        let next = _linkedStreams();
        if (next.length === 0) next = _fallbackStreams();
        next = next.filter(n => !_blacklisted(n));

        // Stable order. Without this the list can come back in a different
        // sequence each refresh, rebuilding every delegate and resetting any
        // slider mid-drag.
        next.sort((a, b) => {
            const an = streamLabel(a).toLowerCase();
            const bn = streamLabel(b).toLowerCase();
            return an < bn ? -1 : (an > bn ? 1 : 0);
        });

        // Compare identity, not contents: reassigning an equivalent list would
        // retrigger the object tracker for no reason.
        if (next.length === streams.length) {
            let same = true;
            for (let i = 0; i < next.length; i++) {
                if (next[i] !== streams[i]) { same = false; break; }
            }
            if (same) return;
        }
        streams = next;
    }


    Timer {
        running: root.streamsActive
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStreams()
    }

    onStreamsActiveChanged: if (!streamsActive) streams = []

    function streamLabel(node) {
        if (!node) return "";
        const p = node.properties || ({});
        return p["application.name"] || node.description || node.name || "Unknown";
    }

    function setStreamVolume(node, v) {
        if (node && node.audio)
            node.audio.volume = Math.max(0, Math.min(1.5, v));
    }

    function toggleStreamMute(node) {
        if (node && node.audio)
            node.audio.muted = !node.audio.muted;
    }

    function toggleMicMute() {
        if (source && source.audio)
            source.audio.muted = !source.audio.muted;
    }

    function setMicVolume(v) {
        if (source && source.audio)
            source.audio.volume = Math.max(0, Math.min(1.5, v));
    }

    // --- output and input devices
    function _devices(wantSink) {
        const out = [];
        const all = (Pipewire.nodes && Pipewire.nodes.values) ? Pipewire.nodes.values : [];
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (!n || n.isStream || !n.audio) continue;
            if (n.isSink !== wantSink) continue;
            out.push(n);
        }
        out.sort((a, b) => {
            const an = String(a.description || a.name || "").toLowerCase();
            const bn = String(b.description || b.name || "").toLowerCase();
            return an < bn ? -1 : (an > bn ? 1 : 0);
        });
        return out;
    }

    property var sinks: []
    property var sources: []

    // Same treatment as streams: refreshed on a timer, never a binding, so the
    // tracker below cannot feed back into the list it is tracking.
    property bool devicesActive: false

    function refreshDevices() {
        const nextSinks = _devices(true);
        const nextSources = _devices(false);

        function differs(a, b) {
            if (a.length !== b.length) return true;
            for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return true;
            return false;
        }

        if (differs(nextSinks, sinks)) sinks = nextSinks;
        if (differs(nextSources, sources)) sources = nextSources;
    }

    function deviceLabel(node) {
        if (!node) return "";
        return node.description || node.nickname || node.name || "Unknown device";
    }

    function setDefaultSink(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }

    Timer {
        running: root.devicesActive
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshDevices()
    }

    onDevicesActiveChanged: if (!devicesActive) { sinks = []; sources = []; }

    // --- spectrum
    property int bands: 32

    // Frames per second requested from cava. 60 is smooth without being
    // wasteful; the visualiser repaints once per frame received, so this is
    // the single knob that decides how hard the widget works.
    property int framerate: 60
    property var spectrum: new Array(32).fill(0)

    // Reference counted rather than a boolean. With a boolean, two visualiser
    // panels alive at once (the edit-mode preview and the real widget) meant
    // whichever was destroyed first switched cava off for both, and the
    // survivor sat dead until the shell restarted.
    property int visualizerUsers: 0
    readonly property bool visualizerEnabled: visualizerUsers > 0

    function acquireVisualizer() { visualizerUsers = visualizerUsers + 1; }
    function releaseVisualizer() { visualizerUsers = Math.max(0, visualizerUsers - 1); }

    function setVolume(v) {
        if (sink && sink.audio)
            sink.audio.volume = Math.max(0, Math.min(1.5, v));
    }

    function toggleMute() {
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function setMicMuted(m) {
        if (source && source.audio)
            source.audio.muted = m;
    }

    // Volumes only update for tracked objects. `streams` is timer-driven rather
    // than a binding, which is what keeps this from feeding back into itself.
    PwObjectTracker {
        objects: [root.sink, root.source]
            .concat(root.streams)
            .concat(root.sinks)
            .concat(root.sources)
    }

    // cava writes a raw ASCII frame per line: "12;40;33;...;"
    Process {
        id: cava
        running: root.visualizerEnabled
        command: ["cava", "-p", `${Settings.configDir}/state/cava.conf`]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line) return;
                const parts = line.split(";");
                const out = [];
                for (let i = 0; i < parts.length; i++) {
                    if (parts[i] === "") continue;
                    out.push(parseInt(parts[i]) / 1000.0);
                }
                if (!out.length) return;

                root.spectrum = out;

                // Cheap enough to compute once here, and it saves every
                // consumer walking the array to answer the same question.
                let peak = 0;
                for (let i = 0; i < out.length; i++) {
                    if (out[i] > peak) peak = out[i];
                }
                root.silent = peak < 0.01;
            }
        }
    }

    // Regenerate the cava config whenever the band count changes so the widget
    // and the source agree on resolution.
    Process {
        id: writeCavaConfig
        command: ["sh", "-c",
            `mkdir -p "${Settings.configDir}/state" && cat > "${Settings.configDir}/state/cava.conf" <<'CFG'
[general]
mode = normal
framerate = ${root.framerate}
autosens = 1
bars = ${root.bands}

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
channels = mono

[smoothing]
noise_reduction = 40
CFG`]
    }

    // True when nothing is coming through, so the widget can say "no signal"
    // without every consumer scanning the array itself.
    property bool silent: true

    onFramerateChanged: {
        writeCavaConfig.running = true;
        if (root.visualizerEnabled) {
            cava.running = false;
            restartCava.start();
        }
    }

    onBandsChanged: {
        writeCavaConfig.running = true;
        if (root.visualizerEnabled) {
            cava.running = false;
            restartCava.start();
        }
    }

    Component.onCompleted: writeCavaConfig.running = true

    Timer {
        id: restartCava
        interval: 200
        onTriggered: cava.running = root.visualizerEnabled
    }
}
