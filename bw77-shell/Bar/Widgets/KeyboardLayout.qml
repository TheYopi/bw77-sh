import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Keyboard layout indicator, always exactly two characters.
 *
 * Compositors report layouts as full descriptions ("English (US)", "Russian"),
 * and letting the width follow the name makes every widget to its left jump
 * whenever you switch. A fixed two-letter code keeps the row still.
 */
BarItem {
    id: root

    // Descriptions rarely contain the ISO code, so map the common ones and fall
    // back to the first two letters of the language name.
    readonly property var codes: ({
        "english": "EN", "us": "EN", "russian": "RU", "ru": "RU",
        "ukrainian": "UA", "german": "DE", "french": "FR", "spanish": "ES",
        "italian": "IT", "portuguese": "PT", "polish": "PL", "czech": "CS",
        "dutch": "NL", "swedish": "SV", "norwegian": "NO", "danish": "DA",
        "finnish": "FI", "turkish": "TR", "greek": "EL", "hebrew": "HE",
        "arabic": "AR", "persian": "FA", "hindi": "HI", "japanese": "JA",
        "korean": "KO", "chinese": "ZH", "thai": "TH", "vietnamese": "VI",
        "hungarian": "HU", "romanian": "RO", "bulgarian": "BG", "serbian": "SR",
        "croatian": "HR", "slovak": "SK", "slovenian": "SL", "estonian": "ET",
        "latvian": "LV", "lithuanian": "LT", "belarusian": "BE", "georgian": "KA",
        "armenian": "HY", "kazakh": "KK"
    })

    readonly property string code: {
        const l = Compositor.keyboardLayout;
        if (!l) return "--";

        // Leading language word, before any parenthesised variant.
        const lang = l.split("(")[0].trim().toLowerCase();
        if (codes[lang]) return codes[lang];

        // Some compositors report the raw xkb code already ("us", "ru").
        if (l.length <= 3 && codes[l.toLowerCase()]) return codes[l.toLowerCase()];

        return lang.substring(0, 2).toUpperCase();
    }

    readonly property bool showIcon: (config && config.showIcon !== undefined)
        ? config.showIcon : true

    visible: Compositor.keyboardLayout !== ""
    tooltip: Compositor.keyboardLayout
    onClicked: Compositor.cycleKeyboardLayout()

    Row {
        spacing: Theme.space1
        height: parent.height

        CyberText {
            visible: root.showIcon
            height: parent.height
            text: "\u2328"
            role: "icon"
            sizeOverride: root.cfgFontSize
            color: root.cfgColor(Theme.textDim)
        }

        CyberText {
            height: parent.height
            // `code` is always two characters in a monospaced face, so the
            // width is already constant and the bar cannot reflow on switch.
            text: root.code
            role: "mono"
            sizeOverride: root.cfgFontSize
            weightOverride: root.cfgFontWeight
            color: root.hovered ? Theme.accent : root.cfgColor(Theme.text)
        }
    }
}
