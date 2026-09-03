import QtQuick
import qs.Config
import qs.Common
import qs.Services

BarItem {
    id: root

    readonly property int pct: Math.round(Audio.volume * 100)
    readonly property bool showIcon: (config && config.showIcon !== undefined)
        ? config.showIcon : true
    readonly property bool showBar: (config && config.showBar !== undefined)
        ? config.showBar : true
    readonly property bool showValue: (config && config.showValue !== undefined)
        ? config.showValue : true

    accentColor: Audio.muted ? Theme.danger : Theme.accent
    tooltip: Audio.sinkName
    active: Popups.current === "audio"

    onClicked: (m) => {
        if (m.button === Qt.MiddleButton) Audio.toggleMute();
        else Popups.openAt("audio", root, screenRef);
    }
    onWheel: (d) => Audio.setVolume(Audio.volume + (d > 0 ? 0.02 : -0.02))

    Row {
        spacing: Theme.space2
        height: parent.height

        CyberText {
            visible: root.showIcon
            height: parent.height
            text: Audio.muted ? "\uf026" : (root.pct > 50 ? "\uf028" : "\uf027")
            role: "icon"
            sizeOverride: root.cfgFontSize
            color: root.cfgColor(root.accentColor)
        }

        SegmentBar {
            visible: root.showBar
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 9
            segments: 10
            value: Audio.muted ? 0 : Audio.volume
            fillColor: Theme.accent
            warnAtHigh: false
        }

        CyberText {
            visible: root.showValue
            height: parent.height
            // Fixed width: the value swings between two and four characters
            // and a reflow on every change made the whole bar twitch.
            width: 42
            horizontalAlignment: Text.AlignRight
            text: Audio.muted ? "MUTE" : root.pct + "%"
            role: "mono"
            sizeOverride: root.cfgFontSize
            weightOverride: root.cfgFontWeight
            color: root.cfgColor(Theme.textDim)
        }
    }
}
