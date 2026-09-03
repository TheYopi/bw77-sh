import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Output, input, and whatever is currently making noise.
 *
 * Built on the same sliders as the quick settings volume section, which had
 * already solved this layout. What was here before put the mute toggle outside
 * the slider as a separate CyberButton, so every row was a loose label, then a
 * button in one frame, then a slider in another - three boxes of two different
 * heights with gaps between them, reading as three widgets that happened to be
 * on the same line. CyberSlider carries the glyph inside its own frame, which
 * makes the row one control and puts the toggle where the thing it toggles is.
 *
 * The "AUDIO" and "PLAYING" headings and the OUT/MIC labels are gone with it.
 * Between the speaker glyph and the microphone glyph there was nothing those
 * three words were telling anyone, and the device name under the heading -
 * "Starship/Matisse HD Audio Controller Analog Stereo" - was the longest string
 * in the popup and not something you can act on from here. Choosing a device is
 * still on the Audio pane in the Control Center, which is where it belongs.
 *
 * Stream names stay, because with several things playing the name is the only
 * way to tell the rows apart. They scroll rather than elide - see MarqueeText.
 */
Item {
    id: root

    implicitWidth: 400
    implicitHeight: col.implicitHeight

    // Stream nodes are only bound and polled while this popup is on screen.
    Component.onCompleted: Audio.streamsActive = true
    Component.onDestruction: Audio.streamsActive = false

    Column {
        id: col
        width: parent.width
        spacing: Theme.space2

        // --- output
        CyberSlider {
            width: parent.width
            from: 0; to: 1; stepSize: 0.01
            decimals: 0
            displayScale: 100
            value: Audio.volume
            barColor: Audio.muted ? Theme.textMuted : Theme.accent

            iconText: Audio.muted ? "\uf026" : "\uf028"
            iconColor: Audio.muted ? Theme.danger : Theme.accent
            onIconClicked: Audio.toggleMute()

            onMoved: (v) => Audio.setVolume(v)
        }

        // --- input
        CyberSlider {
            width: parent.width
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

        /*
         * Separates the two device sliders from the per-application ones, which
         * is the job the "PLAYING" heading was really doing. A rule does it
         * without printing a word, and it only appears when there is something
         * below it to separate.
         */
        Item {
            width: parent.width
            height: Theme.space2
            visible: Audio.streams.length > 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: Theme.alpha(Theme.border, 0.7)
            }
        }

        CyberText {
            visible: Audio.streams.length === 0
            width: parent.width
            topPadding: Theme.space2
            text: Settings.t("Nothing is playing right now")
            role: "micro"
            caps: false
            color: Theme.textMuted
        }

        Repeater {
            model: Audio.streams

            Column {
                id: streamRow
                required property var modelData

                width: col.width
                spacing: 2

                readonly property bool streamMuted:
                    streamRow.modelData.audio && streamRow.modelData.audio.muted

                /*
                 * The name sits above its slider rather than beside it. Beside
                 * it, the name had a fixed 110px column - a quarter of the
                 * popup permanently reserved for a word that is usually five
                 * characters, and still not enough for the ones that are not.
                 * Above it, the name gets the full width to scroll in and the
                 * slider gets the full width to be a slider.
                 */
                MarqueeText {
                    width: parent.width
                    height: implicitHeight
                    text: Audio.streamLabel(streamRow.modelData)
                    role: "micro"
                    caps: false
                    color: Theme.textMuted
                }

                CyberSlider {
                    width: parent.width
                    from: 0; to: 1; stepSize: 0.01
                    decimals: 0
                    displayScale: 100
                    value: streamRow.modelData.audio
                        ? streamRow.modelData.audio.volume : 0

                    barColor: streamRow.streamMuted ? Theme.textMuted : Theme.accent

                    iconText: streamRow.streamMuted ? "\uf026" : "\uf028"
                    iconColor: streamRow.streamMuted ? Theme.danger : Theme.accent
                    onIconClicked: Audio.toggleStreamMute(streamRow.modelData)

                    onMoved: (v) => Audio.setStreamVolume(streamRow.modelData, v)
                }
            }
        }
    }
}
