import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Backlight level.
 *
 * Headless, like the volume rows above it, so the three sliders read as one
 * block of levels rather than as three separate sections each announcing
 * itself. A heading per slider was more chrome than content.
 */
QsSection {
    id: root
    accentRole: "warn"

    Column {
        width: parent.width
        spacing: Theme.space2

        CyberSlider {
            width: parent.width
            from: 0.05; to: 1.0; stepSize: 0.05
            decimals: 0
            displayScale: 100
            value: Brightness.fraction
            barColor: root.accentColor

            iconText: "\uf185"
            iconColor: Brightness.available ? root.accentColor : Theme.textMuted

            // Read-only without brightnessctl: the value still shows, but the
            // slider will not pretend it can change it.
            enabled: Brightness.writable
            onMoved: (v) => Brightness.setFraction(v)
        }

        CyberText {
            visible: Brightness.available && !Brightness.writable
            width: parent.width
            text: Settings.t("Install brightnessctl to change this")
            role: "micro"
            caps: false
            color: Theme.textMuted
        }
    }
}
