import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Opens the quick settings menu directly under itself, wherever the widget
 * happens to sit in the bar.
 */
BarItem {
    id: root

    accentColor: Theme.accent
    tooltip: "Quick settings"
    active: Shell.quickSettingsOpen
    onClicked: Shell.toggleQuickSettings()

    CyberText {
        height: parent.height
        text: "\uf0ae"
        role: "icon"
        /*
         * The Icon size option had never worked. `font.pixelSize` was assigned
         * here as well, and assigning it at the call site replaces CyberText's
         * own binding outright - so sizeOverride was read by nothing and the
         * slider moved a number in settings.json and changed nothing on
         * screen. One property, with the old hardcoded value as its fallback.
         *
         * No weightOverride: this is a Nerd Font glyph, and asking for a
         * weight the icon family does not ship gets a synthesised or
         * substituted face rather than a heavier icon.
         */
        sizeOverride: root.cfgIconSize > 0 ? root.cfgIconSize : Theme.fontLarge
        color: root.active ? Theme.accent
            : (root.hovered ? Theme.accent : root.cfgColor(Theme.textDim))

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }
}
