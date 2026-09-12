import QtQuick
import qs.Config
import qs.Common
import qs.Services

BarItem {
    id: root

    // Polling runs only while something is displaying it.
    Component.onCompleted: SysMon.acquire()
    Component.onDestruction: SysMon.release()

    readonly property bool anyTraffic: SysMon.down > 0 || SysMon.up > 0
    readonly property bool showIcon: (config && config.showIcon !== undefined)
        ? config.showIcon : true
    readonly property bool showRates: (config && config.showRates !== undefined)
        ? config.showRates : true

    /*
     * Reserved width for a rate, so the widgets to the left do not jump every
     * time the figure changes width - "0 B/S" to "1.2 MB/S" and back. Scaled
     * off the bar's own text size rather than fixed, or a larger bar font
     * would clip its own readout.
     */
    readonly property int rateWidth:
        Math.round((root.cfgFontSize > 0 ? root.cfgFontSize : Theme.fontBase) * 4.4)

    tooltip: "Network activity"
    active: Popups.current === "network"
    onClicked: Popups.openAt("network", root, screenRef)

    Row {
        spacing: Theme.space2
        height: parent.height

        CyberText {
            visible: root.showIcon
            height: parent.height
            text: root.anyTraffic ? "\uf1eb" : "\uf127"
            role: "icon"
            sizeOverride: root.cfgFontSize
            color: root.cfgColor(root.anyTraffic ? Theme.accent : Theme.textMuted)
        }

        /*
         * Both directions on one line.
         *
         * They used to be stacked as two "micro" rows, which at bar height put
         * two half-size lines where the rest of the bar has one - legible only
         * if you went looking. One line at the bar's own text size reads at a
         * glance, and the arrows carry the direction that the stacking used to.
         */
        Row {
            visible: root.showRates
            height: parent.height
            spacing: Theme.space1

            CyberText {
                height: parent.height
                // nf-md-download
                text: "\udb80\uddda"
                role: "icon"
                sizeOverride: root.cfgFontSize
                color: root.cfgColor(Theme.c("chartNet"))
            }

            CyberText {
                height: parent.height
                width: root.rateWidth
                text: SysMon.downLabel
                role: "mono"
                sizeOverride: root.cfgFontSize
                color: root.cfgColor(Theme.c("chartNet"))
            }

            CyberText {
                height: parent.height
                // nf-md-upload
                text: "\udb81\udd52"
                role: "icon"
                sizeOverride: root.cfgFontSize
                color: root.cfgColor(Theme.textMuted)
            }

            CyberText {
                height: parent.height
                width: root.rateWidth
                text: SysMon.upLabel
                role: "mono"
                sizeOverride: root.cfgFontSize
                color: root.cfgColor(Theme.textMuted)
            }
        }
    }
}
