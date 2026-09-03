import QtQuick
import Quickshell
import qs.Config
import qs.Common
import qs.Services

/*
 * Time and date on the bar.
 *
 * One source for the formats, and it is Settings.clock. This used to accept
 * per-widget `format`, `dateFormat` and `showDate` overrides that fell back to
 * the shared values - which meant every clock had two sets of controls in the
 * Control Center governing the same three things, and no way to tell from
 * either which one was winning. Two clocks on one bar showing different times
 * is not a feature anyone was asking for.
 *
 * What stays per-widget is appearance: size, colour and outline, all inherited
 * from BarItem. A second clock used as a date-only readout is a real thing to
 * want, and `showDate` being shared does not prevent it - drop the seconds from
 * the shared time format and set this one's colour instead.
 */
BarItem {
    id: root

    readonly property string timeFormat: Settings.clock.timeFormat
    readonly property string dateFormat: Settings.clock.dateFormat
    readonly property bool showDate: Settings.clock.showDate

    accentColor: Theme.warn
    tooltip: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
    active: Popups.current === "clock"
    onClicked: Popups.openAt("clock", root, screenRef)

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space3

        // Date and time share a size: a smaller date read as a subtitle rather
        // than as one clock, and the mismatch was the first thing the eye hit.
        // The date is dimmer instead, which separates them without resizing.
        CyberText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showDate
            text: Qt.formatDateTime(clock.date, root.dateFormat)
            role: "mono"
            sizeOverride: root.cfgFontSize
            weightOverride: root.cfgFontWeight
            color: root.cfgColor(Theme.textDim)
        }

        CyberText {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, root.timeFormat)
            role: "mono"
            sizeOverride: root.cfgFontSize
            weightOverride: root.cfgFontWeight
            color: root.cfgColor(Theme.warn)
        }
    }

    // Ticking every second when the format has no seconds in it wakes the
    // process sixty times a minute to redraw the same string.
    SystemClock {
        id: clock
        precision: root.timeFormat.indexOf("s") !== -1
            ? SystemClock.Seconds : SystemClock.Minutes
    }
}
