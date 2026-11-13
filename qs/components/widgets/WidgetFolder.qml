import QtQuick
import QtQuick.Layouts
import "../common"
import "../../theme" as Theme

Item {
    id: root

    property string label: ""
    property bool expanded: false
    property color textColor: Theme.Theme.fg
    property color activeColor: Theme.Theme.fg
    property color backgroundColor: "transparent"
    property int fontSize: Theme.Theme.fontSize
    default property alias content: innerRow.data

    signal toggleRequested()

    implicitWidth: innerRow.implicitWidth
    implicitHeight: innerRow.implicitHeight

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
        radius: Theme.Theme.radius
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleRequested()
    }

    RowLayout {
        id: innerRow

        spacing: Theme.Theme.gap

        StyledText {
            text: root.label
            textColor: root.expanded ? root.activeColor : root.textColor
            fontSize: root.fontSize
        }

        StyledText {
            text: root.expanded ? "[-]" : "[+]"
            fontSize: root.fontSize
        }

    }

}
