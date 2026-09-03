import QtQuick
import qs.Config

/*
 * Default text style for the shell: condensed display face, uppercase, tracked
 * out. Set `caps: false` for body copy and file names where readability wins.
 */
Text {
    id: root

    property bool caps: true
    property string role: "body"   // body | label | title | headline | mono | micro | icon

    // Forces the heavier weight on a role that would not normally carry it.
    // The category strip uses it: sixteen tab labels at the same weight as the
    // settings underneath them did not read as a level above.
    property bool bold: false

    // Overrides the size implied by `role`. Zero means "use the role's size".
    property real sizeOverride: 0

    /*
     * Overrides the weight implied by `role`. Zero means "use the role's".
     *
     * `bold` is a switch between two fixed weights, which is the right control
     * for a heading. The bar wants a continuous one - see Settings.bar
     * fontWeight - and setting font.weight at the call site would have meant
     * every caller silently dropping the role's own weight logic on the floor.
     * This keeps that logic and lets a caller step around it deliberately.
     */
    property int weightOverride: 0

    /*
     * Only "icon" uses the second family. Everything else is text.
     *
     * "mono" and "micro" used to resolve to it as well, which is how the clock,
     * the date, the battery percentage, the workspace labels and every small
     * caption in the shell ended up set in the Nerd Font. That was defensible
     * when there were three families and the third was a monospace text face,
     * but there are two now and the second one exists to draw glyphs - so
     * anything routed to it that is not a glyph is simply in the wrong font.
     *
     * "mono" still means what it always meant to the call sites - a readout,
     * something with a number in it - it just gets the interface face now.
     * "icon" is the new role, and it is the only one that must be a Nerd Font.
     */
    font.family: role === "icon" ? Theme.fontIcons : Theme.fontUI

    font.pixelSize: {
        if (sizeOverride > 0) return sizeOverride;
        switch (role) {
        // Its own size, not the text size. See Theme.fontIcon.
        case "icon":     return Theme.fontIcon;
        case "micro":    return Theme.fontMicro;
        case "label":    return Theme.fontSmall;
        case "title":    return Theme.fontLarge;
        case "headline": return Theme.fontTitle;
        default:         return Theme.fontBase;
        }
    }

    font.weight: weightOverride > 0 ? weightOverride
        : (bold ? Font.Bold
            : ((role === "title" || role === "headline") ? Font.DemiBold : Font.Medium))
    font.letterSpacing: role === "icon" ? 0
        : ((role === "title" || role === "headline")
            ? Theme.trackingHeadline : Theme.trackingWide)
    font.capitalization: (caps && role !== "icon")
        ? Font.AllUppercase : Font.MixedCase

    color: Theme.text
    renderType: Text.NativeRendering
    elide: Text.ElideRight

    // Align to the line box rather than the item box. Only has an effect when
    // the item is given a height larger than implicitHeight, which is what the
    // bar widgets do - see BarItem.
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignLeft

    /*
     * --- optical vertical centring
     *
     * `AlignVCenter` centres the LINE BOX, not the letters. The line box is
     * ascent + descent, and both of those are whatever the font declares -
     * which for a patched Nerd Font is not a measure of the letters at all. The
     * patcher raises the ascender and drops the descender to make room for
     * glyphs that reach far past normal type, so the line box gains space above
     * and below asymmetrically and the actual capitals end up sitting off
     * centre in it. Every widget in the bar inherited that: the clock, the
     * workspace numerals, the layout code and the window title all sat high in
     * their frames, and the amount they sat off by changed with the font.
     *
     * What the eye centres on for a short label in capitals is the cap height,
     * so that is what gets centred here. With the item height h, Qt puts the
     * baseline at h/2 + (ascent - descent)/2; centring the capitals wants it at
     * h/2 + capHeight/2. The difference is the nudge:
     *
     *     (capHeight - ascent + descent) / 2
     *
     * Taken from FontMetrics at runtime rather than from a table, so it is
     * computed against the numbers Qt is actually laying out with - it
     * self-corrects for any font rather than being tuned for one.
     *
     * Applied as a transform, not as padding, so it moves the glyphs without
     * touching implicitHeight and cannot reflow anything that measures this
     * item. Rounded because NativeRendering on a fractional offset is blurry.
     */
    property bool opticalCenter: role !== "icon"

    FontMetrics {
        id: metrics
        font: root.font
    }

    readonly property real capHeight: {
        // capitalHeight is the right measure and is what Qt reports for any
        // font with the tables filled in. Some patched and bitmap fonts leave
        // it at zero, so fall back to the x-height (roughly 0.7 of the caps in
        // most faces) and then to a proportion of the size itself.
        const cap = metrics.capitalHeight;
        if (cap > 0) return cap;
        if (metrics.xHeight > 0) return metrics.xHeight * 1.4;
        return root.font.pixelSize * 0.7;
    }

    readonly property int opticalOffset: root.opticalCenter
        ? Math.round((root.capHeight - metrics.ascent + metrics.descent) / 2)
          + Settings.general.textNudge
        : 0

    transform: Translate { y: root.opticalOffset }
}
