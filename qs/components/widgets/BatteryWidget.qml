import QtQuick
import QtQuick.Layouts
import "../common"
import "../icons"
import "../../theme" as Theme

RowLayout {
    id: root
    property int percentage: 0
    property bool charging: false
    property int warningThreshold: 15
    property string label: ""
    property color textColor: Theme.Theme.fg
    property color warningColor: Theme.Theme.warn
    property int fontSize: Theme.Theme.fontSize
    property int iconWidth: Theme.Theme.iconSize + 2
    property int iconHeight: Math.round(iconWidth * 0.6)

    spacing: Theme.Theme.gap

    readonly property color stateColor: percentage <= warningThreshold ? warningColor : textColor

    BatteryIcon {
        level: root.percentage
        charging: root.charging
        color: root.stateColor
        iconWidth: root.iconWidth
        iconHeight: root.iconHeight
    }

    SlotText {
        widthSamples: [root.label + "100%"]
        content: percentageText
        Layout.minimumWidth: implicitWidth
        clip: true

        StyledText {
            id: percentageText

            text: root.label + root.percentage + "%"
            textColor: root.stateColor
            fontSize: root.fontSize
        }
    }
}
