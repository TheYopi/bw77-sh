import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Config
import qs.Common
import qs.Services

BarItem {
    id: root

    readonly property int maxWidth: (config && config.maxWidth) ? config.maxWidth : 300
    readonly property bool showIcon: (config && config.showIcon !== undefined)
        ? config.showIcon : true

    // appAndTitle | appOnly | titleOnly
    readonly property string mode: (config && config.mode) ? config.mode : "appAndTitle"

    readonly property bool wantApp: mode !== "titleOnly"
    readonly property bool wantTitle: mode !== "appOnly" && Compositor.activeTitle !== ""

    // With one field there is nothing to align against, so it centres.
    readonly property bool singleField: !(wantApp && wantTitle)

    interactive: false
    visible: Compositor.activeAppName !== ""
    implicitWidth: visible
        ? Math.min(root.maxWidth, layout.implicitWidth + hPadding * 2)
        : 0

    Row {
        id: layout
        height: parent.height
        spacing: Theme.space2

        IconImage {
            visible: root.showIcon && Compositor.activeIcon !== ""
            anchors.verticalCenter: parent.verticalCenter
            source: Compositor.activeIcon ? Quickshell.iconPath(Compositor.activeIcon, true) : ""
            implicitSize: 16
        }

        // Stacked when both fields are shown, a single centred line when only
        // one is. Sizing the Column to its content and centring it is what puts
        // a lone label on the widget's centre line - stretching it to the full
        // height left the text sitting at the top.
        // With both fields the two stack and share a left edge. With one, it
        // gets the widget's full height so vertical centring actually applies -
        // a text sized to its own content has no room to centre within.
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.singleField ? 0 : -1

            /*
             * These two now follow the bar's text size, which they never did
             * before: this widget had a "Text size" slider on its options tab
             * and nothing in here read it, so that one control was inert for
             * as long as it existed. The title keeps its own smaller role when
             * it is sharing the widget with the app name.
             */
            GlitchText {
                visible: root.wantApp
                height: root.singleField ? layout.height : implicitHeight
                text: Compositor.activeAppName
                role: "label"
                fontSize: root.cfgFontSize
                weightOverride: root.cfgFontWeight
                color: Theme.accent
                decodeOnChange: true
            }

            CyberText {
                visible: root.wantTitle
                height: root.singleField ? layout.height : implicitHeight
                text: Compositor.activeTitle
                role: root.wantApp ? "micro" : "label"
                // Held a step below the app name when both are shown, so the
                // pair still reads as a heading and a subtitle.
                sizeOverride: root.cfgFontSize > 0
                    ? (root.wantApp ? root.cfgFontSize - 1 : root.cfgFontSize)
                    : 0
                weightOverride: root.cfgFontWeight
                caps: false
                color: root.wantApp ? Theme.textMuted : Theme.text
                width: Math.min(root.maxWidth - 30, implicitWidth)
            }
        }
    }
}
