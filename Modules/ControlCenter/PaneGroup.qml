import QtQuick
import qs.Config
import qs.Common

/*
 * A section of a settings pane that can be folded away.
 *
 * The panes that need this are the ones with four or more sections - the dock
 * has six, audio five, the top bar and quick settings four each. Opened flat
 * they are a single column of thirty-odd controls, and the one you came for is
 * somewhere in it. Folding the groups turns that into a list of four or six
 * headings you can read at a glance.
 *
 * Panes with three sections or fewer are left alone. At that length the whole
 * pane is already legible without scrolling much, and making them fold would
 * add a click to reach something that was already on screen.
 *
 * --- a Column, not an Item with arithmetic
 *
 * The first version of this was an Item that computed its own implicitHeight
 * from the header plus the body, animated that with a Behavior, and clipped.
 * Every pane using it rendered completely blank. Two of those three choices
 * were fighting: implicitHeight is written by the layout as well as read by
 * it, so putting a Behavior on it means the value the parent Column reads is
 * whatever the animation is currently part-way through - and with `clip` on
 * top, a height that started at zero clipped away the entire group before it
 * ever grew.
 *
 * A Column already does the one thing that arithmetic was for: it sizes itself
 * to its visible children and re-lays out when one of them is hidden.
 *
 * --- and the fold, which is not the same mistake
 *
 * The rows now sit in a plain Item whose EXPLICIT height is animated, with the
 * Column of rows inside it. That is a different thing from the version that
 * failed, in the way that matters: a Column reads its children's `height` and
 * never writes to it, so an explicit height animating between 0 and the
 * content's size is a value nothing else is fighting over. implicitHeight is
 * left alone - the group still reports its true size to the pane above it.
 *
 * The blank-pane trap does not apply either. Behaviors do not run during
 * component construction, so a group that starts open is laid out at its full
 * height on the first frame and the clip has nothing to cut; only a fold the
 * user actually asks for animates.
 *
 * The rows keep their `visible` binding, but off the container's height rather
 * than off `expanded` directly - so they stay on screen for as long as the
 * fold takes and drop out of the keyboard order at the end of it, which is the
 * point CcNav should stop finding them.
 *
 * --- what stays open
 *
 * The first group of a pane, because opening a pane onto nothing but headings
 * gives no sense of what is in it. Everything after it starts folded.
 *
 * State is per group instance and deliberately not persisted. It resets when
 * the Control Center is closed, which keeps the pane's opening shape
 * predictable - a remembered fold from three days ago is indistinguishable
 * from a pane that has lost its contents.
 *
 * --- keyboard
 *
 * The rows inside a collapsed group are invisible, and CcNav already filters
 * on visibility, so the arrows skip a folded group's contents without needing
 * to know this component exists.
 */
Column {
    id: root

    default property alias content: body.data

    property string title: ""
    property string subtitle: ""
    property color accentColor: Theme.danger

    /*
     * Forwarded straight to the header underneath.
     *
     * These exist because a PaneGroup stands in for the SectionHeader a pane
     * used to declare directly, and a pane that had turned the decode off on a
     * heading still means to have it off. Leaving them out is what made every
     * grouped pane render blank: assigning a property a component does not
     * declare is a load error, so a single `glitch: false` carried over from a
     * converted header took the whole pane down with it.
     */
    property bool glitch: true
    property bool rule: false

    // A group that cannot fold still draws its header, so a pane can mix the
    // two without the headings looking different from each other.
    property bool collapsible: true
    property bool expanded: true

    /*
     * --- a group that is a page instead of a fold
     *
     * Set `page: true` and the group stops folding: it draws one row saying
     * what it is, and going into it puts its rows on a page of their own with
     * the way back at the top. PaneScroll carries the reasoning and does the
     * hiding; this end owns the rows, so this end moves them.
     *
     * Worth it for a topic with several settings that is not what you came to
     * the pane for - the bar's outlines, a dock's autohide timings. Not worth
     * it for two rows, which is a click to see less than a fold would have
     * shown you for nothing.
     */
    property bool page: false

    // The value shown on the right of the row, the way GNOME's list says
    // "Connected" or "Off" before you go in. Optional; most groups have no one
    // word that summarises them.
    property string pageValue: ""

    readonly property var ownerScroll: {
        let p = parent;
        while (p) {
            if (p.isPaneScroll === true) return p;
            p = p.parent;
        }
        return null;
    }

    readonly property bool paged: root.page && root.ownerScroll !== null
    readonly property bool pushed: paged && root.ownerScroll.openPage === root

    /*
     * The rows themselves move; nothing is rebuilt.
     *
     * `body` is this group's content Column, and its width binding is written
     * against `parent`, so it re-measures against whichever host it is hung
     * from without anything here having to say so.
     */
    onPushedChanged: body.parent = root.pushed ? root.ownerScroll.pageHost : fold

    width: parent ? parent.width : 0
    spacing: Theme.space2

    /*
     * The header is a navigable row in its own right.
     *
     * Without this, folding every group on a pane made the pane unreachable by
     * keyboard: CcNav only walks rows that are visible, a collapsed group hides
     * all of its rows, and the headers were not rows - so `ordered()` came back
     * empty, the arrows had nothing to move between, and there was no keyboard
     * way to expand anything again. The one state you could reach by keyboard
     * was a state you could not leave by keyboard.
     *
     * It registers with the same contract SettingRow uses - CcNav does not care
     * what a row is, only that it can report a position and be activated - so
     * arrowing down a pane stops on each heading, and Enter or Space folds and
     * unfolds it.
     */
    Item {
        id: headerRow
        width: parent.width
        height: header.implicitHeight

        // --- CcNav row contract
        readonly property var ownerPane: {
            let p = parent;
            while (p) {
                if (p.isPaneScroll === true) return p;
                p = p.parent;
            }
            return null;
        }

        // Only worth stopping on when there is something to fold.
        readonly property bool navigable: root.collapsible

        function absoluteY() {
            const p = mapToItem(null, 0, 0);
            return p ? p.y : 0;
        }

        // Nothing inside to steer: left and right have no meaning on a heading,
        // so they are declined and the pane keeps them.
        function navControl() { return null; }
        function navStep(delta) { return false; }

        function navActivate() {
            if (root.paged) {
                root.ownerScroll.pushPage(root);
                return true;
            }
            if (!root.collapsible) return false;
            root.expanded = !root.expanded;
            return true;
        }

        readonly property bool navActive: CcNav.activeRow === headerRow

        Component.onCompleted: CcNav.register(headerRow)
        Component.onDestruction: CcNav.unregister(headerRow)

        // Reads the same as a selected SettingRow, so a heading and a setting
        // do not look like two different kinds of selection - and at one
        // strength for both inputs, for the same reason SettingRow does.
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -Theme.space2
            anchors.rightMargin: -Theme.space2
            visible: headerRow.navActive
            color: Theme.alpha(root.accentColor, 0.14)
        }

        SectionHeader {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            // Room for the chevron, so a long title cannot run under it.
            anchors.rightMargin: (root.collapsible || root.paged)
                ? Theme.space5 + (root.pageValue !== "" ? valueText.width + Theme.space3 : 0)
                : 0
            title: root.title
            subtitle: root.subtitle
            accentColor: root.accentColor
            glitch: root.glitch
            rule: root.rule
        }

        /*
         * Rotated rather than swapped for a second glyph, so the two states
         * are the same shape at different angles and the movement between them
         * says which way the group is going.
         */
        CyberText {
            id: valueText
            visible: root.paged && root.pageValue !== ""
            anchors.right: chevron.left
            anchors.rightMargin: Theme.space3
            anchors.verticalCenter: parent.verticalCenter
            text: root.pageValue
            role: "label"
            caps: false
            color: Theme.textMuted
        }

        CyberText {
            id: chevron
            visible: root.collapsible || root.paged
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf078"
            role: "icon"
            sizeOverride: Theme.fontSmall
            color: headerMouse.containsMouse ? root.accentColor
                : Theme.alpha(root.accentColor, 0.7)

            // A fold turns; a page points. -90 is the same glyph aimed the way
            // the group is about to go, which is out to the right rather than
            // down the pane.
            rotation: root.paged ? -90 : (root.expanded ? 0 : -90)

            Behavior on rotation {
                enabled: !Theme.reducedMotion && Settings.animations.surfaceOpen
                NumberAnimation {
                    duration: Theme.durFast
                    easing.type: Theme.easeOut
                }
            }

            Behavior on color { ColorAnimation { duration: Theme.durFast } }
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            enabled: root.collapsible || root.paged
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.paged) root.ownerScroll.pushPage(root);
                else root.expanded = !root.expanded;
            }

            // Clicking a heading moves the keyboard position with it, so the
            // arrows carry on from where the mouse left off rather than from
            // wherever they were last.
            onPressed: CcNav.setActive(headerRow, false)
        }
    }

    Item {
        id: fold
        width: parent.width

        /*
         * Shut is minus one spacing, not zero.
         *
         * Leaving the layout costs this group the `spacing` the Column was
         * reserving for it as well as its height, and that part went in one
         * frame - a step at the end of every fold. Folding on past zero by
         * exactly that spacing closes the gap at the same rate as the rest,
         * since a Column places the next child at `y + height + spacing`.
         * QsSubmenu carries the long version of this.
         */
        readonly property real shutHeight: -root.spacing
        readonly property bool drawable: height > 0

        /*
         * --- a group that starts shut has to be measurable while it is shut
         *
         * This fold is sized from the Column inside it, and the Column was
         * hidden whenever the fold was - so for a group declared `expanded:
         * false`, the height binding asked how tall the rows were, the rows
         * were not on screen to answer, and the fold opened to nothing. It
         * then stayed shut, because a fold that is nothing tall hides its own
         * contents, which is what it was asking. Every group on every pane
         * that started collapsed could never be opened; the ones that started
         * open were fine, because they had been measured before they were ever
         * hidden, and Qt keeps the last answer.
         *
         * Two things break the circle. The Column no longer switches itself
         * off - the fold around it is already invisible when shut, which takes
         * the rows out of the keyboard order just the same, since `visible`
         * reads through parents. And the height is remembered from the first
         * frame, when nothing has been hidden yet: `measured` is false for
         * exactly that long, the fold is up but folded to nothing, and the
         * figure it takes then is what it opens to if it is ever asked while
         * cold.
         *
         * `Math.max` rather than a plain fallback, so a group whose rows grew
         * while it was shut opens to the rows it actually has: the cached
         * figure only ever wins when the live one is not available.
         */
        property real coldHeight: 0
        property bool measured: false

        Component.onCompleted: {
            fold.coldHeight = body.implicitHeight;
            fold.measured = true;
        }

        // A pushed group's rows are not in here any more, and an unpushed one
        // has nothing to show until it is: either way a paged group's fold is
        // shut, and the row above it is the whole of it.
        height: (root.expanded && !root.paged)
            ? Math.max(body.implicitHeight, fold.coldHeight)
            : shutHeight

        // Only while it is actually part-way through a fold. A permanent clip
        // costs a scissor rect on every group on every pane to hide nothing.
        clip: height < body.implicitHeight

        // Out of the enclosing Column's layout entirely once fully shut - by
        // which point it is contributing -spacing + spacing, so nothing moves.
        //
        // Up regardless for the first frame, which is what makes the height
        // above measurable. It is folded to nothing and clipped for that frame,
        // so there is nothing on screen either way.
        visible: !fold.measured || height > shutHeight + 0.01

        // The category curve opens it; a collapse eases in and out, which it
        // can now that there is no step waiting at the end of it.
        Behavior on height {
            enabled: !Theme.reducedMotion && Settings.animations.surfaceOpen
            NumberAnimation {
                duration: Theme.durationFor("controlCenter")
                easing.type: root.expanded
                    ? Theme.curveFor("controlCenter") : Easing.InOutCubic
            }
        }

        Column {
            id: body
            width: parent.width
            spacing: Theme.space2

            // No `visible` of its own. The fold above is already invisible
            // once shut and `visible` reads through parents, so CcNav - which
            // filters on it - drops these rows either way. Switching the
            // Column off as well is what stopped it being measurable, and a
            // Column that cannot be measured is a group that cannot open.
        }
    }
}
