import QtQuick
import qs.Config
import qs.Common
import qs.Services

/*
 * Right-click menu for a dock entry.
 *
 * Lists the application's open windows by title first, since jumping to a
 * specific window is the thing you most often want and hunting for it by
 * cycling is worse than picking it from a list.
 */
Item {
    id: root

    property string appId: ""
    property bool pinned: false
    property var windows: []

    signal dismiss()

    /*
     * Emitted the instant a row is clicked, before the action runs.
     *
     * The menu stays on screen for its closing animation, so anything the
     * action changes - windows closing, the app id clearing - would otherwise
     * play out in full view: the list visibly empties, and only then does the
     * menu fade. Freezing the content on this signal means it closes showing
     * exactly what was clicked.
     */
    signal actionStarted()

    readonly property int maxWindows: 8
    readonly property var shownWindows: windows.slice(0, maxWindows)

    /*
     * --- application-declared actions
     *
     * Read from the .desktop file's Actions key: "New Incognito Window" for a
     * browser, "New Spreadsheet" for LibreOffice, "New Private Window" for
     * Firefox. Whatever the application chose to advertise.
     *
     * Worth being precise about the name: this is a jumplist, not a Global
     * Menu. A Global Menu is the running application's own menu bar - File,
     * Edit, View - exported over D-Bus and drawn by the shell instead of by the
     * window. That needs the app to export com.canonical.dbusmenu, an importer
     * on this side, and only works for toolkits that support it. This is the
     * static list the app ships, so it works for every application, needs
     * nothing running, and is what docks actually show on right-click.
     */
    readonly property var entryActions:
        Settings.dock.showAppActions ? Apps.actionsFor(appId) : []
    readonly property int maxActions: 6

    /*
     * Actions the menu already offers itself, so the application's copy is
     * dropped rather than printed underneath it.
     *
     * Almost every browser and terminal ships a "New Window" entry in its
     * .desktop file, and this menu has always added its own "Open new window"
     * below - two rows, one above the other, doing exactly the same thing. The
     * app's own version usually wins on wording ("New Private Window") where it
     * differs, so only the ones that collide outright are removed.
     *
     * Matched on a normalised name rather than the exact string: the same
     * action is variously "New Window", "new window" and "Open a New Window"
     * across the desktop files on any given machine.
     */
    readonly property var builtinNames: ["new window", "open new window", "window"]

    function normalise(name) {
        return String(name || "").toLowerCase()
            .replace(/&/g, "")
            .replace(/^open (a )?/, "")
            .replace(/[^a-z ]/g, "")
            .trim();
    }

    readonly property var shownActions: entryActions
        .filter(a => root.builtinNames.indexOf(root.normalise(a.name)) < 0)
        .slice(0, maxActions)

    implicitWidth: 260
    implicitHeight: col.implicitHeight + Theme.space3 * 2

    /*
     * The same Panel and SectionHeader the Control Center uses, rather than a
     * bare outlined box. A crimson-stroked rectangle with a plain label read as
     * a different design language from every other surface in the shell.
     */
    Panel {
        anchors.fill: parent
        fillColor: Theme.bgDeep
        serial: false
        padding: 0
        notch: Theme.notch
    }

    Column {
        id: col
        anchors.centerIn: parent
        width: parent.width - Theme.space3 * 2
        spacing: 1

        // No subtitle here: the window count already has its own line as the
        // heading for the list below, and stating it twice reads as a mistake.
        SectionHeader {
            width: parent.width
            title: Apps.nameFor(root.appId)
            accentColor: Theme.danger
            glitch: false
        }

        // --- open windows
        CyberText {
            visible: root.shownWindows.length > 0
            width: parent.width
            text: root.windows.length === 1
                ? "1 open window"
                : `${root.windows.length} open windows`
            role: "micro"
            color: Theme.textMuted
            topPadding: 3
            bottomPadding: 1
        }

        Repeater {
            model: root.shownWindows

            Item {
                required property var modelData
                required property int index

                width: col.width
                height: 26

                Rectangle {
                    anchors.fill: parent
                    color: winMouse.containsMouse
                        ? Theme.alpha(Theme.accent, 0.18) : "transparent"
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space2
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space2

                    // Filled tick marks the window that currently has focus.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 12
                        color: modelData === Compositor.activeToplevel
                            ? Theme.warn : Theme.alpha(Theme.accent, 0.6)
                    }

                    CyberText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: col.width - 40
                        text: modelData.title && modelData.title !== ""
                            ? modelData.title : Apps.nameFor(root.appId)
                        role: "micro"
                        caps: false
                        color: winMouse.containsMouse ? Theme.accent : Theme.text
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: winMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    /*
                     * Act first, dismiss second.
                     *
                     * Dismissing clears the shared appId, and `windows` is
                     * derived from it - so the delegate's model empties, this
                     * row is destroyed mid-click, and whatever `modelData`
                     * referred to is gone before the action ever runs. The
                     * handle is captured first for the same reason.
                     */
                    onClicked: {
                        const target = modelData;
                        root.actionStarted();
                        if (target) target.activate();
                        root.dismiss();
                    }
                }
            }
        }

        CyberText {
            visible: root.windows.length > root.maxWindows
            width: parent.width
            text: `and ${root.windows.length - root.maxWindows} more`
            role: "micro"
            caps: false
            color: Theme.textMuted
        }

        Rectangle {
            visible: root.shownWindows.length > 0
            width: parent.width
            height: 1
            color: Theme.alpha(Theme.border, 0.9)
        }

        // --- what the application itself offers
        CyberText {
            visible: root.shownActions.length > 0
            width: parent.width
            text: Settings.t("From the application")
            role: "micro"
            color: Theme.textMuted
            topPadding: 3
            bottomPadding: 1
        }

        Repeater {
            model: root.shownActions

            Item {
                required property var modelData

                width: col.width
                height: 26

                Rectangle {
                    anchors.fill: parent
                    color: actMouse.containsMouse
                        ? Theme.alpha(Theme.accent, 0.18) : "transparent"
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space2
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space2

                    CyberText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        text: "\uf0da"
                        role: "icon"
                        color: Theme.alpha(Theme.accent, 0.8)
                    }

                    CyberText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: col.width - 40
                        text: modelData.name
                        role: "micro"
                        caps: false
                        color: actMouse.containsMouse ? Theme.accent : Theme.text
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: actMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Same capture-then-dismiss order as the window rows: the
                    // model empties when appId clears, taking modelData with it.
                    onClicked: {
                        const target = modelData;
                        root.actionStarted();
                        Apps.runAction(target);
                        root.dismiss();
                    }
                }
            }
        }

        Rectangle {
            visible: root.shownActions.length > 0
            width: parent.width
            height: 1
            color: Theme.alpha(Theme.border, 0.9)
        }

        // --- actions
        Repeater {
            model: [
                { label: Settings.t("Open new window"), glyph: "\uf0fe",
                  act: () => Apps.launch(root.appId) },
                { label: root.pinned ? Settings.t("Unpin from dock") : Settings.t("Pin to dock"),
                  glyph: root.pinned ? "\uf00d" : "\uf08d",
                  act: () => root.pinned ? Apps.unpin(root.appId) : Apps.pin(root.appId) },
                { label: Settings.t("Close all"), glyph: "\uf00d", danger: true,
                  needsRunning: true,
                  act: () => {
                      // Snapshot first: closing a window removes it from the
                      // live list, so iterating that list directly walks off
                      // the end and leaves half the windows open.
                      const targets = root.windows.slice();
                      for (let i = 0; i < targets.length; i++) {
                          if (targets[i]) targets[i].close();
                      }
                  } }
            ]

            Item {
                required property var modelData

                width: col.width
                height: visible ? 26 : 0
                visible: !modelData.needsRunning || root.windows.length > 0

                Rectangle {
                    anchors.fill: parent
                    color: actionMouse.containsMouse
                        ? Theme.alpha(modelData.danger ? Theme.danger : Theme.accent, 0.18)
                        : "transparent"
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space2

                    CyberText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.glyph
                        role: "icon"
                        font.pixelSize: Theme.fontSmall
                        color: modelData.danger ? Theme.danger : Theme.accent
                    }

                    CyberText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: col.width - 40
                        text: modelData.label
                        role: "micro"
                        color: modelData.danger ? Theme.danger : Theme.text
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Same ordering rule as the window rows above: the
                        // action closes over data that dismissing invalidates.
                        const run = modelData.act;
                        root.actionStarted();
                        if (run) run();
                        root.dismiss();
                    }
                }
            }
        }
    }
}
