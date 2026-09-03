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
 * to its visible children and re-lays out when one of them is hidden. So the
 * fold is just `visible` on the body, there is no height to compute, nothing
 * to animate against the layout, and nothing to clip.
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
            anchors.rightMargin: root.collapsible ? Theme.space5 : 0
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
            id: chevron
            visible: root.collapsible
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf078"
            role: "icon"
            sizeOverride: Theme.fontSmall
            color: headerMouse.containsMouse ? root.accentColor
                : Theme.alpha(root.accentColor, 0.7)

            rotation: root.expanded ? 0 : -90

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
            enabled: root.collapsible
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded

            // Clicking a heading moves the keyboard position with it, so the
            // arrows carry on from where the mouse left off rather than from
            // wherever they were last.
            onPressed: CcNav.setActive(headerRow, false)
        }
    }

    Column {
        id: body
        width: parent.width
        spacing: Theme.space2

        // Hidden rather than clipped, so the rows inside drop out of the
        // keyboard order too - CcNav filters on visibility - and so the
        // enclosing Column stops reserving room for them.
        visible: root.expanded
    }
}
