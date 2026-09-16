import QtQuick
import qs.Config
import qs.Common

/*
 * The processes using the most of one resource, as a short table.
 *
 * Three columns: a marker, the name, and the reading. The marker is the shell's
 * notched rectangle at glyph size rather than an application icon - these are
 * command names off the process table, not desktop entries, and half of them
 * have no icon to find. A row of identical markers reads as a list; a row of
 * mismatched icons and blank squares reads as a list that is broken.
 *
 * The name column takes whatever the reading does not, so a long name elides
 * rather than pushing the figure it belongs to off the edge. That is the one
 * arrangement that cannot lose the number, which is the part being measured.
 */
Item {
    id: root

    // Entries as they come from Procs: { n: name, v: number }.
    property var model: []

    property color accentColor: Theme.accent

    // How the number is turned into text. Set by the caller because the same
    // list draws percentages for the processor and byte counts for memory.
    property var formatter: (v) => String(v)

    // Cut to what actually fits rather than to a fixed five: a block half the
    // height of the one next to it shows three rows instead of overflowing.
    property real rowHeight: Math.max(12, Theme.fontMicro + 5)
    readonly property int capacity: Math.max(0, Math.floor(height / rowHeight))

    /*
     * --- why the rows are held rather than bound
     *
     * `model` arrives from a binding that also reads the live gauge values, so
     * it is handed here as a brand new array ten times a second even when the
     * five processes in it have not changed - and a Repeater given a new array
     * destroys and rebuilds every delegate it has. That is four items and their
     * bindings per row, torn down and remade at the sampler's rate, on a widget
     * that lives on the wallpaper and is never closed.
     *
     * So the rows are rebuilt only when what they would DRAW actually differs.
     * The signature is the names and their readings, which is exactly the set
     * of things visible on screen: two samples that rank the same processes at
     * the same figures leave the delegates alone, and the list is genuinely
     * static most of the time because the sampler runs at half a hertz while
     * the gauges run at ten.
     */
    property var rows: []

    readonly property string signature: {
        const m = root.model || [];
        const n = Math.min(5, root.capacity);
        let sig = String(n);
        for (let i = 0; i < n && i < m.length; i++)
            sig += "\u001f" + m[i].n + "\u001e" + m[i].v;
        return sig;
    }

    function rebuild() {
        const m = root.model || [];
        root.rows = m.slice(0, Math.min(5, root.capacity));
    }

    onSignatureChanged: root.rebuild()
    Component.onCompleted: root.rebuild()

    property string emptyText: ""

    CyberText {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: root.rows.length === 0 && root.emptyText !== ""
                 && root.capacity > 0
        text: root.emptyText
        role: "micro"
        caps: false
        color: Theme.textMuted
        elide: Text.ElideRight
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        Repeater {
            model: root.rows

            Item {
                id: row
                required property var modelData

                width: root.width
                height: root.rowHeight

                readonly property real markerSize:
                    Math.max(5, Math.round(root.rowHeight * 0.55))

                NotchRect {
                    id: marker
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: row.markerSize
                    height: row.markerSize
                    fillColor: root.accentColor
                    strokeColor: "transparent"
                    strokeWidth: 0
                    // A quarter of the marker, so the cut reads at this size -
                    // the frame's own notch is a fixed number of pixels and
                    // would be most of a six-pixel square.
                    notch: Math.max(2, Math.round(row.markerSize * 0.35))
                    notchTopLeft: true
                    notchTopRight: false
                    notchBottomRight: true
                    notchBottomLeft: false
                }

                CyberText {
                    id: reading
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: root.formatter(row.modelData.v)
                    role: "micro"
                    color: Theme.alpha(root.accentColor, 0.95)
                }

                CyberText {
                    anchors.left: marker.right
                    anchors.leftMargin: Theme.space2
                    anchors.right: reading.left
                    anchors.rightMargin: Theme.space2
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.n
                    role: "micro"
                    caps: false
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
            }
        }
    }
}
