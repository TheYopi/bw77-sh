import QtQuick
import qs.Config
import qs.Common

PaneScroll {
    id: pane

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Launcher")
        subtitle: Settings.t("Size, layout and how categories are shown")
    }

    SettingRow {
        label: Settings.t("Width")
        CyberSlider {
            width: 240
            from: 420; to: 1200; stepSize: 20
            value: Settings.launcher.width
            suffix: "px"
            onMoved: (v) => Settings.launcher.width = v
        }
    }

    SettingRow {
        label: Settings.t("Height")
        alternate: true
        CyberSlider {
            width: 240
            from: 300; to: 900; stepSize: 20
            value: Settings.launcher.height
            suffix: "px"
            onMoved: (v) => Settings.launcher.height = v
        }
    }

    SettingRow {
        label: Settings.t("Position")
        CyberSelector {
            options: [{ v: "center", l: Settings.t("Center") }, { v: "top", l: Settings.t("Top") }]
            current: Settings.launcher.position
            onPicked: (v) => Settings.launcher.position = v
        }
    }

    SettingRow {
        label: Settings.t("Results shown")
        alternate: true
        CyberSlider {
            width: 240
            from: 10; to: 100; stepSize: 5
            value: Settings.launcher.maxResults
            onMoved: (v) => Settings.launcher.maxResults = v
        }
    }

    SectionHeader {
        width: pane.innerWidth
        title: Settings.t("Categories")
        accentColor: Theme.accent
        glitch: false
    }

    SettingRow {
        label: Settings.t("Show categories")
        CyberToggle {
            checked: Settings.launcher.showCategories
            onToggled: (v) => Settings.launcher.showCategories = v
        }
    }

    SettingRow {
        label: Settings.t("Layout")
        description: Settings.t("Vertical is a rail down the left; horizontal is an icon strip above the results")
        alternate: true
        CyberSelector {
            options: [{ v: "vertical", l: Settings.t("Vertical") }, { v: "horizontal", l: Settings.t("Horizontal") }]
            current: Settings.launcher.categoryLayout
            onPicked: (v) => Settings.launcher.categoryLayout = v
        }
    }

    SettingRow {
        visible: Settings.launcher.categoryLayout === "vertical"
        label: Settings.t("Rail width")
        CyberSlider {
            width: 240
            from: 110; to: 260; stepSize: 5
            value: Settings.launcher.categoryWidth
            suffix: "px"
            onMoved: (v) => Settings.launcher.categoryWidth = v
        }
    }

    SettingRow {
        label: Settings.t("Application icons")
        alternate: true
        CyberToggle {
            checked: Settings.launcher.showIcons
            onToggled: (v) => Settings.launcher.showIcons = v
        }
    }
}
