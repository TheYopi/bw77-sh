import QtQuick
import qs.Config

/*
 * The tiny unreadable serial numbers scattered around the game's menus
 * ("TRN_TLCAS_800095", "IMAGE NAME: SILVERBIRCH-3.10.10"). They exist to make a
 * panel feel like a readout from a machine rather than a form.
 *
 * Deterministic per seed, so a given panel keeps the same fake serial across
 * reloads instead of flickering to a new one on every repaint.
 */
Text {
    id: root

    property string seed: "0"
    property string prefix: "TRN_TLCAS"

    function hash(s) {
        let h = 2166136261;
        for (let i = 0; i < s.length; i++) {
            h ^= s.charCodeAt(i);
            h = Math.imul(h, 16777619);
        }
        return Math.abs(h);
    }

    visible: Settings.fx.telemetryText
    text: {
        const h = hash(seed + prefix);
        const a = (h % 900000 + 100000).toString();
        return `${prefix}_${a}`;
    }

    font.family: Theme.fontMono
    font.pixelSize: Theme.fontMicro
    font.letterSpacing: 1
    color: Theme.textMuted
    opacity: 0.75
}
