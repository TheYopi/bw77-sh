import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Now playing, on the bar: artwork, transport, and what the track is.
 *
 * The player it acts on is whatever the rest of the shell means by "now
 * playing" - Services.Media picks it, so this widget, the quick settings
 * section, the desktop panel and the media keys can never disagree about which
 * player they are driving.
 *
 * It deliberately does NOT mount MediaBody. That component is the same player
 * in two layouts, and both of them are built around artwork with a scrub row
 * and framed 44px transport buttons - a shape that needs a hundred pixels of
 * height and gets twenty-four here. What is shared is the thing worth sharing:
 * the player selection and the track label, which is where the two surfaces
 * would actually drift apart if they were written twice.
 */
BarItem {
    id: root

    readonly property bool showIcon: (config && config.showIcon !== undefined)
        ? config.showIcon : true
    readonly property bool showControls: (config && config.showControls !== undefined)
        ? config.showControls : true
    readonly property bool showText: (config && config.showText !== undefined)
        ? config.showText : true

    /*
     * How much track text to show, in characters rather than pixels.
     *
     * Characters because that is the unit the thing being measured is in: the
     * question is "how much of the title do I want to read", and the answer
     * should not change because the bar's font slider moved. The width is
     * measured from the font below, so twenty-four characters stays
     * twenty-four characters at any size.
     */
    readonly property int maxChars: (config && config.maxChars)
        ? Math.max(6, config.maxChars) : 28

    readonly property bool hideWhenIdle: (config && config.hideWhenIdle !== undefined)
        ? config.hideWhenIdle : true

    // Collapses to nothing rather than sitting on the bar as an empty frame.
    // BarItem's implicitWidth already folds on `visible`, so the widgets around
    // it close the gap.
    visible: Media.hasPlayer || !root.hideWhenIdle

    readonly property string trackText: Media.hasPlayer
        ? Media.trackLabel(" - ") : Settings.t("Nothing playing")

    /*
     * One colour, whatever the player is doing.
     *
     * This drives BarItem's frame, and it used to follow the playback state -
     * so pausing dimmed the outline and the widget looked like it had been
     * disabled rather than paused. Playback state belongs on the transport
     * glyphs, which is where you look to change it; the frame is chrome and
     * chrome that changes colour on its own reads as a fault.
     */
    accentColor: Theme.accent


    // The whole track, for when it is scrolling and you do not want to wait.
    tooltip: root.trackText

    /*
     * Clicks belong to the three transport glyphs; the rest of the widget is a
     * readout.
     *
     * captureClicks must stay false for that: BarItem's own pointer area is
     * declared after the content and would otherwise swallow every press
     * before it reached them. It still tracks hover, so the frame lights under
     * the cursor like any other widget.
     */
    interactive: true
    captureClicks: false

    Row {
        id: row
        spacing: Theme.space2
        height: parent.height

        /*
         * --- artwork
         *
         * Square, at the text's cap height rather than the bar's, so it sits on
         * the same line as everything else instead of towering over it.
         *
         * Cover art is the icon here. The player's own application icon was the
         * other candidate and is sharper at this size, but it answers a
         * question nobody is asking of a bar widget - you know which player you
         * opened - while the cover is the one part of a track you recognise
         * before reading anything.
         */
        Item {
            id: art

            visible: root.showIcon
            width: visible ? root.artSize : 0
            height: root.artSize
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.bgDeep, 0.85)
                visible: cover.status !== Image.Ready
            }

            Image {
                id: cover
                anchors.fill: parent
                source: Media.active && Media.active.trackArtUrl
                    ? Media.active.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // Decoded well above the drawn size: bar artwork is around
                // twenty pixels and a thumbnail decoded at twenty looks like
                // mud next to text rendered natively.
                sourceSize.width: 64
                sourceSize.height: 64
                visible: status === Image.Ready
            }

            // The same note MediaBody falls back to, so a player with no art
            // looks the same in both places rather than leaving a blank tile.
            CyberText {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: ""
                role: "icon"
                sizeOverride: Math.round(art.width * 0.7)
                color: Theme.alpha(root.accentColor, 0.7)
            }
        }

        // --- transport

        Repeater {
            model: [
                { glyph: "", act: "previous" },
                { glyph: "", act: "toggle" },
                { glyph: "", act: "next" }
            ]

            Item {
                id: button
                required property var modelData

                visible: root.showControls && !Media.liveStream
                width: visible ? Math.round(root.glyphSize * 1.5) : 0
                height: parent.height

                readonly property bool isToggle: modelData.act === "toggle"

                /*
                 * Whether the player will accept this. MPRIS reports the three
                 * separately and browsers in particular turn them on and off
                 * per tab, so this is the difference between a press doing
                 * something and a press being a no-op.
                 *
                 * It gates the pointer area, not the colour. A greyed-out
                 * glyph would be the usual way to show it, but these flags
                 * flicker per track on several players, so the row would go on
                 * quietly changing colour by itself - which is the thing this
                 * widget is not allowed to do. The tell is the cursor: a
                 * disabled MouseArea does not apply its cursorShape, so a
                 * button that will not respond does not offer the pointing
                 * hand either.
                 */
                readonly property bool usable: {
                    const p = Media.active;
                    if (!p) return false;
                    if (modelData.act === "previous") return p.canGoPrevious;
                    if (modelData.act === "next") return p.canGoNext;
                    return p.canTogglePlaying;
                }

                CyberText {
                    id: glyph
                    anchors.centerIn: parent
                    // Play and pause are the same button wearing the state it
                    // will put you in, which is the convention every player
                    // uses - the other two never change.
                    text: button.isToggle
                        ? (Media.playing ? "" : "")
                        : button.modelData.glyph
                    role: "icon"
                    sizeOverride: root.glyphSize
                    /*
                     * --- one colour, always
                     *
                     * No hover tint, no playback-state tint, no disabled tint.
                     *
                     * The hover one was wrong because it did not survive the
                     * widget relaying out underneath the pointer: pressing
                     * play changes the glyph, [LIVE] can appear or go, the
                     * track name changes width, and the buttons slide out from
                     * under the cursor without the pointer area ever seeing it
                     * leave. Whatever colour it was wearing at that moment
                     * stayed on, so a button that had been pressed once looked
                     * different from its neighbours for as long as the bar was
                     * up - the same fault the tray icons had.
                     *
                     * The other two went with it because a row of transport
                     * glyphs that changes colour on its own, for any reason,
                     * reads as that same fault whether or not it is one.
                     *
                     * What says "this is a button" is the pointing-hand cursor
                     * and BarItem's frame lighting under it, neither of which
                     * holds any state of its own.
                     */
                    color: root.cfgColor(root.accentColor)
                }

                SoundArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: button.usable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const p = Media.active;
                        if (!p) return;
                        if (button.modelData.act === "previous") p.previous();
                        else if (button.modelData.act === "next") p.next();
                        else p.togglePlaying();
                    }
                }
            }
        }

        /*
         * --- [LIVE], where the transport would be
         *
         * A stream has nothing to scrub and nothing to come next, so the three
         * glyphs would be two dead buttons around a pause. The badge says why
         * they are missing rather than leaving a gap, and it sits in the same
         * slot so the track text does not shift left when a radio station
         * follows an album.
         *
         * Detected by the same test the quick settings panel uses to decide
         * whether to draw its scrub row, kept in step by hand rather than
         * shared - see the note in Services.Media. Note that this takes the
         * pause button with it: pausing a stream is usually stopping it, and
         * the player's own controls are a click away in quick settings.
         */
        CyberText {
            visible: root.showControls && Media.liveStream
            anchors.verticalCenter: parent.verticalCenter
            text: "[LIVE]"
            role: "mono"
            sizeOverride: root.cfgFontSize
            weightOverride: root.cfgFontWeight
            color: root.cfgColor(Theme.danger)
        }

        // --- track

        MarqueeText {
            visible: root.showText
            anchors.verticalCenter: parent.verticalCenter
            width: root.textWidth

            /*
             * Height left to the component, which takes it from the label.
             * Stretching this to the bar's height would hand the CyberText
             * inside a tall box it aligns to the TOP of, so the track name
             * would sit a few pixels above everything beside it.
             */

            text: root.trackText
            role: "mono"
            sizeOverride: root.cfgFontSize
            weightOverride: root.cfgFontWeight
            color: root.cfgColor(Media.hasPlayer ? Theme.text : Theme.textMuted)

            /*
             * Five seconds parked on the first character of the artist, as
             * asked - long enough that the widget reads as a label most of the
             * time and only occasionally as something moving. The pause at the
             * far end is the component's shorter default: nothing is waiting
             * to be read there, the label just has to finish the last word
             * before it travels back.
             */
            startDwell: 5000
        }
    }

    // ------------------------------------------------------------- measuring

    // Artwork and glyphs both key off the text size, so the row scales as one
    // thing when the bar's font slider moves.
    readonly property real glyphSize:
        root.cfgIconSize > 0 ? root.cfgIconSize
                             : (root.cfgFontSize > 0 ? root.cfgFontSize : Theme.fontBase)

    readonly property int artSize: Math.round(root.glyphSize * 1.4)

    /*
     * The track column's width, measured from the font at `maxChars` of it.
     *
     * A measuring stick rather than the track itself: the width has to be a
     * property of the setting, not of what happens to be playing. Sizing to
     * the actual text would mean the bar reflowed on every track change and
     * every widget to the left of this one would slide, which is exactly what
     * the fixed columns elsewhere on the bar exist to avoid.
     *
     * The stick is "n" repeated, not "0". The interface face is proportional,
     * so "characters" only means anything against some reference character,
     * and a digit is one of the widest things in the font - twenty-eight of
     * them measured out closer to thirty-five characters of an actual title.
     * Lowercase "n" is the classic average-width proxy - it is where the "en"
     * unit comes from - so the setting now means roughly what it says for real
     * text, where capitals and spaces trade off against the narrow letters.
     */
    readonly property int textWidth: Math.ceil(sample.advanceWidth) + 2

    TextMetrics {
        id: sample
        font: probe.font
        text: "n".repeat(root.maxChars)
    }

    // Never drawn. It exists to carry exactly the font the label will use, so
    // the measurement cannot drift from the thing measured.
    CyberText {
        id: probe
        visible: false
        role: "mono"
        sizeOverride: root.cfgFontSize
    }
}
