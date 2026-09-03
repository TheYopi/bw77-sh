import QtQuick
import qs.Config
import qs.Common

/*
 * The frame every desktop widget sits in.
 *
 * The widgets had drifted apart. The system monitor drew its own heading with a
 * crimson tab, the media player drew a dot matrix, the clock and the visualiser
 * drew nothing at all - so four things sitting on the same wallpaper looked like
 * four things from four different programs. They also inherited Panel, which
 * gave them the same opaque card as the Control Center: correct for a surface
 * you open, wrong for something that lives on the desktop permanently and has
 * to sit over a wallpaper without blotting it out.
 *
 * So this is a frame rather than a card: a dark translucent fill and a light
 * outline rather than an opaque surface.
 *
 * The outline is the shell's own notched rectangle - cut at the top left and
 * the bottom right, exactly as the Control Center and every other panel is cut.
 * It was four loose corner brackets for a while, on the reasoning that an
 * unbroken outline reads as a window and competes with real ones. That is true
 * of a HEAVY outline, and the answer to it is weight rather than a different
 * shape: these draw the notched outline at a fraction of the opacity a panel
 * uses. Brackets made the desktop widgets the one family in the shell with a
 * silhouette of their own, which is the opposite of what a shared frame is for.
 *
 * No title. Each widget briefly carried a label tab on its top edge, and it was
 * four words on the desktop restating what the contents obviously are - a clock
 * face labelled TIME, a spectrum labelled AUDIO. It cost a line of every widget
 * and the smallest ones could not spare it.
 *
 * This is the one place in the shell that is deliberately not opaque. Everything
 * else went solid because it sits over the desktop briefly and has to be read;
 * these sit over the wallpaper permanently and have to be lived with.
 */
Item {
    id: root

    default property alias body: content.data

    property color accentColor: Theme.accent
    property real padding: Theme.space3

    /*
     * The standard cut, at the standard size, whatever the widget's size.
     *
     * This used to scale with the shorter side, on the reasoning that a cut
     * tuned for a panel would vanish into the corner of a very large widget.
     * The cost of that was worse than the problem: the notch changed size as
     * the widget was dragged, so two widgets on the same desktop had visibly
     * different corners, and resizing one animated its corner along with it.
     * A notch is a piece of the shell's identity, like a border width - those
     * do not scale with the thing they outline either, and nobody expects the
     * corner radius of a window to grow when the window does.
     */
    property real notch: Theme.notch

    readonly property real fill: Settings.desktop.widgetOpacity

    // --- backing and outline, in one shape
    //
    // Translucent rather than the opaque fill a Panel uses, and the stroke sits
    // well below full strength: the notch says which family this belongs to,
    // and the weight says it is furniture on the wallpaper rather than a window
    // over it.
    NotchRect {
        id: frame
        anchors.fill: parent

        // bgBase, not bgDeep. bgDeep is the shell's darkest tone and is what
        // sits UNDER things - the backdrop behind a modal, the trough of a
        // meter. A widget filled with it reads as a hole punched in the
        // wallpaper rather than as a panel resting on it, and on the darker
        // palettes it went nearly black regardless of the theme's own colour.
        fillColor: Theme.alpha(Theme.bgBase, root.fill)
        strokeColor: Theme.alpha(root.accentColor, 0.45)
        strokeWidth: Theme.borderWidth
        notch: root.notch

        notchTopLeft: true
        notchTopRight: false
        notchBottomRight: true
        notchBottomLeft: false
    }

    Scanlines {
        anchors.fill: parent
        active: Settings.fx.scanlines
        drift: false
        opacity: 0.6
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
