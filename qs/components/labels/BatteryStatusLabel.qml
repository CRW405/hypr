import QtQuick
import QtQuick.Layouts
import "../common"
import "../../theme" as Theme

SlotText {
    id: root
    property string status: "Unknown"
    property int timeToFullSec: 0
    property bool showEstimate: false
    property bool hasBattery: true

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return ""
        var totalMinutes = Math.round(seconds / 60)
        var hours = Math.floor(totalMinutes / 60)
        var minutes = totalMinutes % 60
        if (hours > 0) return hours + "h " + minutes + "m"
        return minutes + "m"
    }

    function baseLabel() {
        if (status === "Charging") return "Charging"
        if (status === "Discharging") return "Discharging"
        if (status === "Full") return "Full"
        return "Battery"
    }

    widthSamples: root.showEstimate && root.status === "Charging" && root.timeToFullSec > 0 ? ["Charging " + root.formatTime(root.timeToFullSec), "Discharging", "Full", "Battery"] : ["Charging", "Discharging", "Full", "Battery"]
    Layout.minimumWidth: implicitWidth + 2 * Theme.Theme.gap
    Layout.preferredWidth: implicitWidth + 2 * Theme.Theme.gap
    visible: root.hasBattery
    content: labelText

    StyledText {
        id: labelText
        text: {
            if (!root.hasBattery) return ""
            var label = root.baseLabel()
            if (root.showEstimate && root.status === "Charging") {
                var eta = root.formatTime(root.timeToFullSec)
                if (eta) label += " " + eta
            }
            return label
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.showEstimate = !root.showEstimate
    }
}
