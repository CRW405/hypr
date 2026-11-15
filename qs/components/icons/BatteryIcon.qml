import QtQuick
import "../../theme" as Theme

Item {
    id: root
    property int level: 0
    property bool charging: false
    property color color: Theme.Theme.fg
    property int iconWidth: Theme.Theme.iconSize + 2
    property int iconHeight: Math.round(iconWidth * 0.6)

    implicitWidth: iconWidth
    implicitHeight: iconHeight
    width: iconWidth
    height: iconHeight

    Rectangle {
        id: body
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 2
        height: parent.height
        radius: 0
        color: "transparent"
        border.width: 1
        border.color: root.color
    }

    Rectangle {
        id: tip
        width: 2
        height: parent.height / 2
        anchors.left: body.right
        anchors.verticalCenter: body.verticalCenter
        color: root.color
    }

    Rectangle {
        id: fill
        anchors.left: body.left
        anchors.leftMargin: 1
        anchors.verticalCenter: body.verticalCenter
        height: body.height - 2
        width: Math.max(0, Math.round((body.width - 2) * Math.min(100, Math.max(0, root.level)) / 100))
        color: root.color
    }

    Text {
        anchors.centerIn: body
        text: root.charging ? "+" : ""
        color: root.color
        font.pixelSize: body.height - 2
        visible: root.charging
    }
}
