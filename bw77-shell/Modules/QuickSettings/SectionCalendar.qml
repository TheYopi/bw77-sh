import QtQuick
import qs.Config
import qs.Common
import qs.Modules.Popups

QsSection {
    id: root
    title: Settings.t("Calendar")

    CalendarPopup {
        width: parent.width
    }
}
