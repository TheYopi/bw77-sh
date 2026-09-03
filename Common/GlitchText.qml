import QtQuick
import qs.Config

/*
 * Text that resolves out of noise.
 *
 * Characters scramble through a glyph set before settling, used when a value
 * changes or a surface opens.
 *
 * This also used to draw static red/cyan copies of itself offset by a pixel -
 * the game's constant low-level chromatic split. It was three Text items per
 * label for an effect that, at the sizes the shell actually renders text, was
 * indistinguishable from the subpixel antialiasing already happening. On a
 * settings pane of forty rows it tripled the item count to produce a fringe
 * nobody could see, so it is gone and the wrapper draws one layer.
 */
Item {
    id: root

    property string text: ""
    property string role: "body"
    property bool caps: true
    property bool bold: false
    property color color: Theme.text
    property bool decodeOnChange: Settings.fx.glitchOnOpen
                                  && Settings.animations.textDecode
    property int decodeDuration: 340

    /*
     * Bump to re-run the scramble without the text having changed.
     *
     * The Control Center resolves every label out of noise when it opens, and
     * those labels are static - "TOP BAR" is "TOP BAR" whether the surface was
     * opened now or an hour ago, so there is no text change to hang the effect
     * on. A counter the surface increments once per open gives one trigger for
     * the whole screen without anything having to reach in and call decode() on
     * each label individually.
     */
    property int decodeTrigger: 0
    onDecodeTriggerChanged: if (decodeTrigger > 0) decode()

    // Overrides the size implied by `role`. Zero means "use the role's size".
    // This exists because GlitchText is an Item wrapping a Text rather than
    // being one, so it has no font group of its own to assign into.
    property real fontSize: 0

    // Forwarded for the same reason as fontSize: this is an Item wrapping a
    // Text, so it has no font group of its own to assign into.
    property int weightOverride: 0

    // Forwarded, so a constrained GlitchText elides like a plain one instead of
    // overflowing its container.
    property int elide: Text.ElideRight
    property real textWidth: 0

    /*
     * Alignment, forwarded for the same reason as elide.
     *
     * This is an Item wrapping a Text, so none of Text's own properties exist
     * on it - setting horizontalAlignment here reads as a plain CyberText and
     * fails at load with "cannot assign to non-existent property". Every other
     * Text property this wrapper needs has had to be re-declared and passed
     * down, and these two were simply the ones nothing had asked for yet.
     */
    property int horizontalAlignment: Text.AlignLeft
    property int verticalAlignment: Text.AlignVCenter

    // Wrapping too: a GlitchText given a width and long text clipped rather
    // than wrapping, because the inner Text was left on the default.
    property int wrapMode: Text.NoWrap
    property int maximumLineCount: 0

    readonly property string glyphs: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/\\<>[]{}#$%&*+=-_|"

    property string _shown: text

    implicitWidth: main.implicitWidth
    implicitHeight: main.implicitHeight

    function decode() {
        // Off-screen labels still cost a timer each, and a pane can hold forty
        // of them below the fold where the effect is never seen. Skipping them
        // is the difference between a scramble and a stutter on open.
        if (Theme.reducedMotion || !decodeOnChange || !visible || text === "") {
            _shown = text;
            return;
        }
        decodeAnim.restart();
    }

    onTextChanged: decode()

    CyberText {
        id: main
        text: root._shown
        role: root.role
        caps: root.caps
        bold: root.bold
        color: root.color
        sizeOverride: root.fontSize
        weightOverride: root.weightOverride
        elide: root.elide
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        wrapMode: root.wrapMode
        // Text treats 0 as "no limit" only via the undefined default, so the
        // property is left alone unless a limit was actually asked for.
        maximumLineCount: root.maximumLineCount > 0
            ? root.maximumLineCount : Number.MAX_SAFE_INTEGER
        // Fills the wrapper so vertical alignment has room to work. Safe
        // because implicitWidth/Height below read the CONTENT size, not this.
        width: root.textWidth > 0 ? root.textWidth : root.width
        height: root.height
    }

    SequentialAnimation {
        id: decodeAnim

        ScriptAction {
            script: {
                decodeTimer.frame = 0;
                decodeTimer.start();
            }
        }
        PauseAnimation { duration: root.decodeDuration }
        ScriptAction {
            script: {
                decodeTimer.stop();
                root._shown = root.text;
            }
        }
    }

    Timer {
        id: decodeTimer
        property int frame: 0
        readonly property int totalFrames: Math.max(1, Math.round(root.decodeDuration / 28))

        interval: 28
        repeat: true
        onTriggered: {
            frame++;
            const target = root.text;
            // Characters lock in left to right as the animation progresses.
            const settled = Math.floor(target.length * (frame / totalFrames));
            let out = target.substring(0, settled);
            for (let i = settled; i < target.length; i++) {
                out += target[i] === " "
                    ? " "
                    : root.glyphs[Math.floor(Math.random() * root.glyphs.length)];
            }
            root._shown = out;
        }
    }
}
