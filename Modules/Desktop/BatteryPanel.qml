import QtQuick
import qs.Config
import qs.Common
import qs.Services
import qs.Modules.Desktop

/*
 * The battery, at desktop size.
 *
 * The bar widget answers "how full" in one glyph because that is all a bar has
 * room for. This is the other half of the question - how fast it is going, how
 * long that leaves, and how much of the pack is still there after however many
 * hundred cycles - and none of that fits in a 38px column.
 *
 * Laid out like the system monitors it sits next to: the history as a backdrop
 * rather than as a chart beside the numbers, the reading set large over it, and
 * a segmented meter along the bottom. That is deliberate - a battery is a
 * system reading and should look like one, not like a widget from somewhere
 * else that happens to be on the same wallpaper.
 *
 * --- what is shown, and what is admitted to
 *
 * Every line here can be absent on real hardware. UPower reports no time
 * estimate for the first minute after the cable moves, no power draw on some
 * packs, and no health at all unless the battery publishes a design capacity.
 * A widget that prints "0h 0m" or "0%" for those is stating something false
 * with total confidence. Each row is therefore hidden when its reading is
 * unknown, and the one row that is always meaningful - the percentage - is the
 * one that never hides.
 */
WidgetFrame {
    id: root
    accentColor: Theme.warn

    property var config: ({})

    // Sampling runs only while something is displaying it, on the same pattern
    // as the system monitors.
    Component.onCompleted: Battery.acquire()
    Component.onDestruction: Battery.release()

    padding: Theme.space3

    function cfg(key, fallback) {
        return (config && config[key] !== undefined) ? config[key] : fallback;
    }

    readonly property bool wide: WidgetMetrics.isWide("battery", width, height)

    Item {
        id: body
        anchors.fill: parent
        clip: true

        /*
         * Nothing to report.
         *
         * A desktop has no battery, and a widget placed on one would otherwise
         * be an empty frame - indistinguishable from the widget being broken.
         * It says which of the two it is, exactly as the GPU panel does.
         */
        CyberText {
            anchors.centerIn: parent
            width: parent.width - Theme.space2 * 2
            visible: !Battery.present
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            role: "micro"
            caps: false
            color: Theme.textMuted
            text: Settings.t("No battery on this machine")
        }

        // History as texture behind the reading, not as a second thing to look
        // at. Half an hour of context at the sampling rate in Services/Battery.
        Graph {
            anchors.fill: parent
            anchors.topMargin: body.height * 0.35
            visible: Battery.present && root.cfg("showGraph", true)
                     && body.height >= 84 && Battery.history.length > 1
            values: Battery.history
            maxValue: 100
            lineColor: Battery.tint
            opacity: 0.28
        }

        // --- the reading
        Row {
            id: readout
            anchors.left: parent.left
            anchors.top: parent.top
            spacing: Theme.space2
            visible: Battery.present

            CyberText {
                anchors.baseline: bigValue.baseline
                text: Battery.glyph
                role: "icon"
                // Tracks the number it stands next to rather than the theme's
                // icon size, so the pair scales together as the widget is
                // dragged instead of the glyph shrinking away from it.
                sizeOverride: Math.max(Theme.fontSmall,
                    Math.min(Theme.fontTitle, body.height * 0.30))
                color: Battery.tint
            }

            CyberText {
                id: bigValue
                text: Battery.percent + "%"
                role: "mono"
                sizeOverride: Math.max(Theme.fontSmall,
                    Math.min(Theme.fontTitle, body.height * 0.34))
                color: Battery.tint
            }
        }

        /*
         * --- the detail rows
         *
         * Dropped from the bottom up as the widget shrinks, in reverse order of
         * how often they are wanted: the time remaining is why someone puts a
         * battery on the desktop, the draw is context for it, and the pack's
         * health is a number you check twice a year. A short widget keeps the
         * first and loses the last, which is the opposite of what dividing the
         * height evenly would have done.
         */
        Column {
            id: detail
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: readout.bottom
            anchors.topMargin: 2
            spacing: 1
            visible: Battery.present

            // Charging, or the time left. Always worth the line it takes.
            CyberText {
                width: parent.width
                visible: Battery.statusLabel !== "" && body.height >= 58
                text: Battery.statusLabel
                role: "micro"
                caps: false
                color: Theme.alpha(Theme.textMuted, 0.85)
                elide: Text.ElideRight
            }

            // Draw, in watts. Hidden rather than zeroed on a pack that does not
            // report it - see the note at the top.
            CyberText {
                width: parent.width
                visible: Battery.wattsKnown && root.cfg("showPower", true)
                         && body.height >= 76
                // A label then the figure, rather than the figure then a bare
                // preposition. "in" and "draw" on their own are not translatable
                // units - they only mean anything next to the number they were
                // written beside, which is exactly what a translation table
                // cannot see.
                text: (Battery.charging ? Settings.t("Charge") : Settings.t("Draw"))
                    + " " + Battery.watts.toFixed(1) + " W"
                role: "micro"
                caps: false
                color: Theme.alpha(Theme.textMuted, 0.85)
                elide: Text.ElideRight
            }

            /*
             * Condition, as a percentage of the capacity the pack shipped with.
             *
             * Printed only when UPower says the battery publishes a design
             * capacity to compare against. Without that flag a missing figure
             * and a worn-out pack both arrive as zero, and "Condition 0%" is
             * the single most alarming thing this widget could say - so it says
             * nothing instead.
             */
            CyberText {
                width: parent.width
                visible: Battery.healthKnown && root.cfg("showHealth", true)
                         && body.height >= 94
                text: `${Settings.t("Condition")} ${Battery.health}%`
                role: "micro"
                caps: false
                color: Battery.health < 70
                    ? Theme.danger : Theme.alpha(Theme.textMuted, 0.85)
                elide: Text.ElideRight
            }
        }

        // Segmented meter along the bottom, matching the system monitors.
        SegmentBar {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: Battery.present && root.cfg("showBar", true) && body.height >= 50
            height: 6
            segments: Math.max(6, Math.floor(body.width / 9))
            value: Battery.fraction
            fillColor: Battery.tint
            // The meter reads high-is-good here, which is the opposite of every
            // other one in the shell - a full battery is not a warning.
            warnAtHigh: false
        }
    }
}
