import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Output and input level.
 *
 * No heading and no device name. The glyph inside each slider says what it is,
 * and the device name - "Starship/Matisse HD Audio Controller Analog Stereo" -
 * was the longest string in the panel and told nobody anything they could act
 * on. It is still on the Audio pane in the Control Center, where choosing a
 * device is the point.
 */
QsSection {
    id: root

    Column {
        width: parent.width
        spacing: Theme.space2

        CyberSlider {
            width: parent.width
            from: 0; to: 1; stepSize: 0.01
            decimals: 0
            displayScale: 100
            value: Audio.volume
            barColor: Audio.muted ? Theme.textMuted : root.accentColor

            iconText: Audio.muted ? "\uf026" : "\uf028"
            iconColor: Audio.muted ? Theme.danger : root.accentColor
            onIconClicked: Audio.toggleMute()

            onMoved: (v) => Audio.setVolume(v)
        }

        CyberSlider {
            width: parent.width
            visible: Settings.quickSettings.showMicSlider
            height: visible ? implicitHeight : 0

            from: 0; to: 1; stepSize: 0.01
            decimals: 0
            displayScale: 100
            value: Audio.micVolume
            barColor: Audio.micMuted ? Theme.textMuted : Theme.warn

            iconText: Audio.micMuted ? "\uf131" : "\uf130"
            iconColor: Audio.micMuted ? Theme.danger : Theme.warn
            onIconClicked: Audio.toggleMicMute()

            onMoved: (v) => Audio.setMicVolume(v)
        }
    }
}
