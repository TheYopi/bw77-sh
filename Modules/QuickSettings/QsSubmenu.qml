import QtQuick
import qs.Config
import qs.Common

/*
 * Drop-down list under an expandable tile.
 *
 * Capped at five visible rows and scrollable past that, so a long list of
 * access points cannot push the rest of the panel off screen.
 *
 * --- how it opens
 *
 * `expanded`, not `visible`. Toggling visibility made the list exist or not
 * exist between two frames, and because the panel below it is a Column, half
 * the quick settings jumped down the screen at the same instant - there was
 * nothing to say the rows had come from the tile above them rather than
 * appearing out of the panel at large.
 *
 * Rolling the height open instead is the whole animation: the Flickable inside
 * already clips, so the rows are revealed by the frame growing over them.
 * `visible` follows the height rather than driving it, which keeps a closed
 * submenu out of the Column's layout entirely - a zero-height child that is
 * still visible would leave the Column's spacing behind as a gap.
 */
Item {
    id: root

    default property alias content: column.data

    property bool expanded: true

    property int visibleRows: 5
    property int rowHeight: 34
    property color tint: Theme.accent
    property int rowCount: 0
    property string emptyText: "Nothing found"

    readonly property real maxHeight: visibleRows * rowHeight + Theme.space2

    readonly property real openHeight:
        Math.min(maxHeight, Math.max(rowHeight, column.implicitHeight + Theme.space2))

    /*
     * Explicit height, and implicitHeight left reporting the open size.
     *
     * A Column lays its children out by height and never writes to it, so an
     * animated height is safe here in a way an animated implicitHeight is not -
     * that one is both read and written by layouts, and animating it is what
     * made an earlier attempt at a folding group render blank.
     *
     * --- the last eight pixels belong to the Column, not to this
     *
     * Closing does not just remove this frame's height; it removes this frame,
     * and with it the one `spacing` the Column above was reserving for it. That
     * spacing went in a single frame however smooth the fold was, so the rows
     * below always stepped up by 8px at the end - the tiles appearing to snap
     * shut before the drop-down had finished. No curve fixes that. A curve can
     * only choose whether the step lands next to stillness or next to speed,
     * and both of those look like something being cut off.
     *
     * So the fold does not stop at zero. It carries on to minus one spacing,
     * which is exactly what the Column will reclaim, and a Column positions the
     * next child at `y + height + spacing` - so those last pixels close the gap
     * at the same rate as all the ones before them. Only once the frame is
     * fully negative does it leave the layout, and at that instant it is
     * contributing -spacing + spacing, which is the nothing it becomes. The
     * total height this occupies is continuous from open to shut, so there is
     * no step left to hide and the curve is free to be gentle at both ends.
     *
     * Below zero it is a spacer and nothing else: the frame and its contents
     * are switched off, so nothing is ever asked to draw itself inside out.
     */
    readonly property real hostSpacing:
        (parent && parent.spacing !== undefined) ? parent.spacing : 0

    readonly property real shutHeight: -root.hostSpacing

    height: root.expanded ? root.openHeight : root.shutHeight
    visible: height > root.shutHeight + 0.01

    readonly property bool drawable: height > 0

    /*
     * --- opening and closing are not the same curve
     *
     * The panel's category curve is "snap" - OutExpo - which is right for a
     * surface arriving: almost all of the distance is covered immediately and
     * the last of it settles. Run backwards on a collapse that shape is wrong
     * in a way that is hard to unsee: the list drops most of its height on the
     * first frame and then spends the rest of the animation creeping the last
     * few pixels shut, so it reads as a snap followed by a stall rather than as
     * one movement.
     *
     * A collapse takes an ease-in-out instead: it leaves gently, covers the
     * distance in the middle, and eases into nothing. That only reads as one
     * movement because there is no longer a spacing step waiting at the end of
     * it - see above. The opening still follows the category, which is the half
     * of it the Animations pane is for.
     */
    Behavior on height {
        enabled: !Theme.reducedMotion && Settings.animations.surfaceOpen
        NumberAnimation {
            duration: Theme.durationFor("quickSettings")
            easing.type: root.expanded
                ? Theme.curveFor("quickSettings") : Easing.InOutCubic
        }
    }

    /*
     * Whether the frame is at its resting size.
     *
     * Mid-fold the frame is shorter than the list inside it by definition, so
     * anything that asks "is there more content than there is room for" answers
     * yes for the length of the animation - which is how a scroll bar came to
     * flash down the side of a three-row list every time it opened. Waiting
     * until the fold has settled asks the question of the shape the reader
     * actually ends up looking at.
     */
    readonly property bool settled: Math.abs(height - openHeight) < 0.5

    /*
     * Fades slightly ahead of the fold, so the rows are readable before the
     * frame has finished opening and gone before it has finished closing.
     *
     * Ease-out both ways on purpose: on the way out that means the rows lose
     * most of their opacity immediately, so the frame is already empty for the
     * last of the fold - including the stretch below zero, where it is holding
     * the Column's spacing open and has nothing left to show.
     */
    opacity: root.expanded ? 1 : 0

    Behavior on opacity {
        enabled: !Theme.reducedMotion && Settings.animations.surfaceOpen
        NumberAnimation {
            duration: Math.round(Theme.durationFor("quickSettings") * 0.6)
            easing.type: Easing.InQuad
        }
    }

    NotchRect {
        anchors.fill: parent
        visible: root.drawable
        fillColor: Theme.alpha(Theme.bgDeep, 0.7)
        strokeColor: Theme.alpha(root.tint, 0.3)
        notch: Theme.notchSmall
        notchTopLeft: false
        notchTopRight: false
        notchBottomRight: true
        notchBottomLeft: false
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Theme.space1
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: column
            width: flick.width
            spacing: 1
        }
    }

    CyberText {
        anchors.centerIn: parent
        visible: root.drawable && root.rowCount === 0
        text: root.emptyText
        role: "micro"
        caps: false
        color: Theme.textMuted
    }

    /*
     * Scroll hint, since a capped list gives no other clue there is more.
     *
     * Only once the frame has stopped moving, and only if the list really does
     * overrun it - a list that fits still shows nothing, and one that does not
     * still shows the bar for as long as it is worth scrolling.
     */
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 2
        y: flick.contentHeight > 0 ? flick.visibleArea.yPosition * parent.height : 0
        width: 2
        height: Math.max(16, flick.visibleArea.heightRatio * parent.height)
        color: Theme.alpha(root.tint, 0.7)
        visible: root.settled && flick.contentHeight > flick.height + 0.5
    }
}
