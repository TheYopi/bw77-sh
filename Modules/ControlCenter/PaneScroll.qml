import QtQuick
import qs.Config
import qs.Common

/* Scroll container shared by every pane, with a chamfered scrollbar. */
Flickable {
    id: root

    default property alias body: column.data
    property alias spacing: column.spacing

    // Marker rather than a type check: SettingRow walks its parent chain
    // looking for the pane that owns it, and `instanceof` is not available to
    // it from QML.
    readonly property bool isPaneScroll: true

    contentWidth: width
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 6000
    maximumFlickVelocity: 2600

    /*
     * Keyboard movement glides rather than teleporting, but only just - a long
     * ease here reads as the list lagging behind the arrow key.
     *
     * Deliberately an explicit animation and not `Behavior on contentY`. A
     * Behavior intercepts every write to the property, including the ones the
     * Flickable makes sixty times a second while a drag or a flick is in
     * progress, which turns its physics into a fight between two things both
     * trying to own the same number. This is only ever started by the keyboard.
     */
    NumberAnimation {
        id: glide
        target: root
        property: "contentY"
        duration: Theme.durFast
        easing.type: Theme.easeSnap
    }

    function glideTo(y) {
        glide.stop();
        if (Theme.reducedMotion || !Settings.animations.surfaceOpen) {
            contentY = y;
            return;
        }
        glide.to = y;
        glide.start();
    }

    // A touch or a wheel takes the view back off the keyboard immediately.
    onMovementStarted: glide.stop()
    onFlickStarted: glide.stop()

    /*
     * Pull a focused row into view.
     *
     * Mapped into contentItem rather than read off the row's own y: rows sit
     * inside Columns and Repeaters, so their y is relative to a wrapper that is
     * itself somewhere down the content, and using it directly scrolled to the
     * wrong place on every pane that groups its settings.
     */
    function revealItem(item) {
        if (!item || contentHeight <= height) return;

        const p = item.mapToItem(contentItem, 0, 0);
        if (!p) return;

        const pad = Theme.space5;
        const top = p.y - pad;
        const bottom = p.y + item.height + pad;
        const max = Math.max(0, contentHeight - height);

        if (top < contentY) glideTo(Math.max(0, top));
        else if (bottom > contentY + height) glideTo(Math.min(max, bottom - height));
    }

    function scrollBy(px) {
        const max = Math.max(0, contentHeight - height);
        // Chained from the live position rather than the animation's target, so
        // holding PageDown accelerates through the pane instead of repeatedly
        // re-aiming at the same place.
        glideTo(Math.max(0, Math.min(max, contentY + px)));
    }

    function scrollTo(y) {
        const max = Math.max(0, contentHeight - height);
        glideTo(Math.max(0, Math.min(max, y)));
    }

    // Runs after every child has registered, so the incoming pane can claim its
    // own rows and drop whatever the outgoing pane left behind.
    Component.onCompleted: CcNav.adopt(root)
    Component.onDestruction: CcNav.release(root)

    /*
     * Room held back for the scrollbar, on every pane and at all times.
     *
     * The bar is drawn on top of the pane at its right edge, so content laid
     * out to the full width ran underneath it - the stepper arrows on the
     * right-hand side of every row were the worst of it, with a crimson bar
     * sitting across them.
     *
     * Reserved unconditionally rather than only while the pane scrolls. Making
     * it conditional means the entire column changes width the moment a group
     * is folded or unfolded and the content crosses the height of the view,
     * which reflows every row in the pane as a side effect of opening one
     * section.
     */
    readonly property real scrollGutter: 3 + Theme.space2

    /*
     * The width a pane's contents actually have.
     *
     * Panes size their own blocks off this rather than off `width`, which is
     * the Flickable's full width including the gutter above. Fifteen files
     * were laying things out to `pane.width` and drawing the right-hand edge
     * of every one of them underneath the scrollbar.
     */
    readonly property real innerWidth: Math.max(0, width - scrollGutter)

    Column {
        id: column
        width: root.width - root.scrollGutter
        spacing: Theme.space2
        // Breathing room so a pane's own SectionHeader is not shaved by the
        // Flickable's clip on the first pixel row.
        topPadding: Theme.space2
        bottomPadding: Theme.space6
    }

    /*
     * Scrollbar.
     *
     * `parent: root` is the whole trick. A Flickable puts its declared children
     * into contentItem, which is the thing that moves - so the bar was being
     * scrolled by exactly the amount it was trying to indicate, and sat there
     * looking broken. Reparenting it onto the Flickable itself takes it out of
     * the moving surface and leaves the position binding to do its job.
     *
     * Positioned with x rather than anchors: at the moment the anchor is
     * evaluated this is still a child of contentItem, so `root` is neither its
     * parent nor its sibling, QML drops the anchor with a warning and the bar
     * lands at x=0 - over the content, on the wrong side entirely.
     */
    Rectangle {
        parent: root
        x: root.width - width
        width: 3
        height: root.height
        color: Theme.alpha(Theme.border, 0.35)
        visible: root.contentHeight > root.height
    }

    Rectangle {
        parent: root
        x: root.width - width
        y: root.contentHeight > 0 ? root.visibleArea.yPosition * root.height : 0
        width: 3
        height: Math.max(24, root.visibleArea.heightRatio * root.height)
        color: Theme.alpha(Theme.danger, 0.85)
        visible: root.contentHeight > root.height
    }
}
