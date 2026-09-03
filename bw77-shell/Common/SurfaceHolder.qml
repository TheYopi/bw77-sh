import QtQuick
import Quickshell
import qs.Config

/*
 * Keeps a surface alive long enough to animate itself out.
 *
 * A plain LazyLoader bound to an open flag destroys its content the instant the
 * flag goes false, so a close animation never gets a chance to run. This holds
 * the component for closeDuration after the flag drops, then releases it.
 */
Scope {
    id: root

    property bool open: false
    property Component component: null

    /*
     * The motion category of the surface being held.
     *
     * This is the whole reason "Duration" under Motion by category looked like
     * it only worked on the way in. The hold was a flat Theme.dur(200) + 60 for
     * every surface, so a category set to anything longer than about 230ms had
     * its close animation cut off mid-flight - the GlitchBox inside was still
     * running when the Loader underneath it was torn down. Raising the duration
     * made the surface open slower and vanish at the same moment as before.
     *
     * Matching GlitchBox's own closeDuration (85% of the category) plus slack
     * means the hold ends when the animation does, whatever the category is set
     * to. Left empty it falls back to the old fixed window.
     */
    property string category: ""

    property int closeDuration: root.category !== ""
        ? Math.round(Theme.durationFor(root.category) * 0.85) + 60
        : Theme.dur(200) + 60

    readonly property bool active: open || hold.running

    onOpenChanged: {
        if (!open) hold.restart();
        else hold.stop();
    }

    Loader {
        active: root.active
        sourceComponent: root.component
    }

    Timer {
        id: hold
        interval: root.closeDuration
    }
}
