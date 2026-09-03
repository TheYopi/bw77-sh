import QtQuick
import Quickshell
import qs.Config
import qs.Common
import qs.Services
import qs.Modules.QuickSettings

/*
 * Overview: live system state plus the switches people reach for most.
 *
 * Deliberately holds no settings of its own. Frame decoration and the font
 * pickers used to live here, which meant two of the shell's most-changed
 * appearance settings were in the one pane whose name promised it was a
 * summary. They are in Effects and Theme now.
 */
PaneScroll {
    id: pane

    /*
     * No readings here any more.
     *
     * The four gauges are across the head of the Control Center itself, so they
     * are on screen whichever tab is open rather than only on this one. What is
     * left is what this pane was for: the switches people reach for.
     */
    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Language")
        accentColor: Theme.accent
        glitch: false
    }

    SettingRow {
        label: Settings.t("Interface language")
        // Every translated binding reads general.language through Settings.t(),
        // so the whole shell re-renders on the same frame as this click - no
        // reload, no restart.
        description: Settings.t("Anything without a translation stays in English")
        CyberSelector {
            options: [{ v: "en", l: "English" }, { v: "ru", l: "\u0420\u0443\u0441\u0441\u043A\u0438\u0439" }]
            current: Settings.general.language
            onPicked: (v) => Settings.general.language = v
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Quick actions")
        accentColor: Theme.accent
        glitch: false
    }

    /*
     * The same tiles as Quick Settings, rather than a row of buttons.
     *
     * Four of these five are toggles with a state to show, and a CyberButton
     * only says "on" by filling its background - which is also what it does on
     * hover, so at a glance the pointer looked like a fifth thing switched on.
     * The tile carries a glyph, its state and its label separately.
     */
    Grid {
        width: pane.innerWidth
        columns: Math.max(1, Math.floor(pane.innerWidth / 230))
        spacing: Theme.space2

        readonly property int cellWidth:
            Math.floor((pane.innerWidth - Theme.space2 * (columns - 1)) / columns)

        QsTile {
            width: parent.cellWidth
            glyph: "\uf1f6"
            label: Settings.t("Do not disturb")
            on: Settings.notifications.doNotDisturb
            onActivated: Settings.notifications.doNotDisturb =
                !Settings.notifications.doNotDisturb
        }

        QsTile {
            width: parent.cellWidth
            glyph: "\uf044"
            label: Settings.t("Desktop edit mode")
            // Not a toggle for the same reason as the Desktop pane's button:
            // it takes you somewhere rather than setting something, and it
            // closes the window that would otherwise be in the way.
            onActivated: Shell.enterDesktopEditMode()
        }

        QsTile {
            width: parent.cellWidth
            glyph: "\uf03e"
            label: Settings.t("Random wallpaper")
            // Not a toggle - it fires and nothing stays on afterwards.
            onActivated: Wallpapers.random()
        }

        QsTile {
            width: parent.cellWidth
            glyph: "\uf0eb"
            label: Settings.t("Reduce motion")
            on: Settings.general.reducedMotion
            onActivated: Settings.general.reducedMotion = !Settings.general.reducedMotion
        }

        QsTile {
            width: parent.cellWidth
            glyph: "\uf023"
            label: Settings.t("Lock")
            danger: true
            onActivated: { Shell.controlCenterOpen = false; Session.lock(); }
        }
    }
}
