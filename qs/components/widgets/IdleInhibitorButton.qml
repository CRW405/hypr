import QtQuick
import "../common"
import "../../theme" as Theme

Item {
    id: root

    property bool inhibitEnabled: false
    property color textColor: Theme.Theme.fg
    property color activeColor: Theme.Theme.warn
    property int fontSize: Theme.Theme.fontSize

    signal toggleRequested()

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    StyledText {
        id: label

        text: root.inhibitEnabled ? "Inhibit" : "Idle"
        textColor: root.textColor
        fontSize: root.fontSize
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleRequested()
    }
}
