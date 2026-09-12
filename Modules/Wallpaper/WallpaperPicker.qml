import QtQuick
import Quickshell
import qs.Config
import qs.Common
import qs.Services

/* Grid of everything in the wallpaper folder. Lives inside the Control Center. */
Item {
    id: root

    // Backstop. The column below is sized to the pane, but a child that
    // mis-reports its height must not be able to paint over the Control
    // Center's footer.
    clip: true

    Column {
        anchors.fill: parent
        spacing: Theme.space3

        SectionHeader {
            width: parent.width
            title: Settings.t("Wallpaper")
            subtitle: `${Wallpapers.files.length} images in ${Settings.wallpaper.folder}`
        }

        // niri draws its overview on a backdrop that shell surfaces are not
        // part of by default, so the wallpaper has to be opted in by name.
        Panel {
            visible: Compositor.kindName === "niri"
            width: parent.width
            height: niriNote.implicitHeight + Theme.space4 * 2
            emphasis: "quiet"
            serial: false
            padding: Theme.space3

            Column {
                id: niriNote
                width: parent.width
                spacing: Theme.space1

                CyberText {
                    text: Settings.t("Wallpaper in the niri overview")
                    role: "label"
                    color: Theme.warn
                }

                CyberText {
                    width: parent.width
                    text: "A second background surface is drawn purely for the overview backdrop, "
                        + "because niri removes a matched surface from the workspace thumbnails. "
                        + "Enabling niri under App theming writes the rule; otherwise add it to config.kdl:"
                    role: "micro"
                    caps: false
                    color: Theme.textDim
                    wrapMode: Text.Wrap
                }

                CyberText {
                    width: parent.width
                    text: 'layer-rule {\n    match namespace="^bw77-backdrop"\n    place-within-backdrop true\n}'
                    role: "mono"
                    caps: false
                    font.pixelSize: Theme.fontSmall
                    color: Theme.accent
                    wrapMode: Text.Wrap
                }

                Row {
                    width: parent.width
                    spacing: Theme.space3

                    CyberText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Settings.t("Backdrop surface")
                        role: "micro"
                        color: Theme.textDim
                    }

                    CyberToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Settings.wallpaper.niriBackdrop
                        onToggled: (v) => Settings.wallpaper.niriBackdrop = v
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.space3
                    visible: Settings.wallpaper.niriBackdrop

                    CyberText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Settings.t("Build it only in the overview")
                        role: "micro"
                        color: Theme.textDim
                    }

                    CyberToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Settings.wallpaper.backdropOnDemand
                        onToggled: (v) => Settings.wallpaper.backdropOnDemand = v
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.space3
                    visible: Settings.wallpaper.niriBackdrop

                    CyberText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 140
                        text: Settings.t("Backdrop brightness")
                        role: "micro"
                        color: Theme.textDim
                    }

                    CyberSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 200
                        from: 0.1; to: 1.0; stepSize: 0.05
                        decimals: 2
                        value: Settings.wallpaper.backdropDim
                        onMoved: (v) => Settings.wallpaper.backdropDim = v
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.space3
                    visible: Settings.wallpaper.niriBackdrop

                    CyberText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 140
                        text: Settings.t("Backdrop blur")
                        role: "micro"
                        color: Theme.textDim
                    }

                    CyberSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 200
                        from: 0; to: 1.0; stepSize: 0.05
                        decimals: 2
                        value: Settings.wallpaper.backdropBlur
                        onMoved: (v) => Settings.wallpaper.backdropBlur = v
                    }
                }
            }
        }

        // --- source
        Row {
            width: parent.width
            spacing: Theme.space2

            CyberText {
                anchors.verticalCenter: parent.verticalCenter
                width: 90
                text: Settings.t("Source")
                role: "label"
                color: Theme.text
            }

            CyberSelector {
                anchors.verticalCenter: parent.verticalCenter
                options: [{ v: "image", l: Settings.t("Image") }, { v: "color", l: Settings.t("Theme colour") }]
                current: Settings.wallpaper.mode
                onPicked: (v) => Settings.wallpaper.mode = v
            }
        }

        /*
         * --- colour mode controls
         *
         * Given the rest of the pane and allowed to scroll inside it, rather
         * than sized to its own content.
         *
         * This pane is not a PaneScroll - it is a fixed-height column, because
         * the image grid underneath needs to be handed whatever height is left
         * and a Flickable cannot hand out a remainder. So a Loader sized to
         * `item.implicitHeight` had nowhere to put the overflow: selecting the
         * gradient style adds two more colour rows and an angle slider, the
         * column grew past the bottom of the card, and the extra controls drew
         * over the footer with the keyboard hints in it.
         *
         * Taking the remaining height and scrolling within it is the same deal
         * the grid gets, so the two modes behave the same way and neither can
         * push the pane out of shape.
         */
        Flickable {
            id: colorScroll
            width: parent.width
            visible: Settings.wallpaper.mode === "color"
            height: visible ? Math.max(0, parent.height - y) : 0
            contentWidth: width
            contentHeight: colorEditor.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WallpaperColorEditor {
                id: colorEditor
                width: colorScroll.width
            }

            // Only appears when there is something below the fold.
            Rectangle {
                parent: colorScroll
                x: colorScroll.width - width
                y: colorScroll.contentHeight > 0
                    ? colorScroll.visibleArea.yPosition * colorScroll.height : 0
                width: 3
                height: Math.max(24, colorScroll.visibleArea.heightRatio * colorScroll.height)
                color: Theme.alpha(Theme.danger, 0.85)
                visible: colorScroll.contentHeight > colorScroll.height
            }
        }

        Row {
            visible: Settings.wallpaper.mode === "image"
            width: parent.width
            spacing: Theme.space2

            NotchRect {
                width: parent.width - refresh.width - random.width - Theme.space2 * 2
                height: 32
                fillColor: Theme.alpha(Theme.bgDeep, 0.9)
                strokeColor: Theme.border
                notch: Theme.notchSmall

                TextInput {
                    anchors.fill: parent
                    anchors.margins: Theme.space3
                    verticalAlignment: Text.AlignVCenter
                    text: Settings.wallpaper.folder
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSmall
                    selectionColor: Theme.accent
                    onEditingFinished: Settings.wallpaper.folder = text
                }
            }

            CyberButton {
                id: refresh
                text: Settings.t("Rescan")
                onClicked: Wallpapers.scan()
            }

            CyberButton {
                id: random
                text: Settings.t("Random")
                onClicked: Wallpapers.random()
            }
        }

        GridView {
            id: grid
            visible: Settings.wallpaper.mode === "image"
            width: parent.width
            height: parent.height - y
            clip: true
            cellWidth: 200
            cellHeight: 124
            model: Wallpapers.files

            delegate: Item {
                required property string modelData
                readonly property bool current: modelData === Wallpapers.current

                width: grid.cellWidth - Theme.space2
                height: grid.cellHeight - Theme.space2

                Image {
                    id: thumb
                    anchors.fill: parent
                    anchors.margins: 2
                    source: "file://" + modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 320
                    clip: true
                }

                NotchRect {
                    anchors.fill: parent
                    fillColor: "transparent"
                    strokeColor: parent.current ? Theme.accent
                        : (thumbMouse.containsMouse ? Theme.danger : Theme.alpha(Theme.border, 0.7))
                    strokeWidth: parent.current ? 2 : 1
                    notch: Theme.notchSmall

                    Behavior on strokeColor { ColorAnimation { duration: Theme.durFast } }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 18
                    color: Theme.alpha(Theme.bgDeep, 0.8)
                    // The filename strip fades with the frame rather than
                    // popping in on the frame the pointer crosses the thumbnail.
                    opacity: thumbMouse.containsMouse || parent.current ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

                    CyberText {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space1
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.split("/").pop()
                        role: "micro"
                        caps: false
                        color: parent.parent.current ? Theme.accent : Theme.textDim
                    }
                }

                MouseArea {
                    id: thumbMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wallpapers.set(modelData)
                }
            }
        }
    }
}
