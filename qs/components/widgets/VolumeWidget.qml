import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../common"
import "../../theme" as Theme

Item {
    id: root

    property real volume: 0
    property bool muted: false
    property color textColor: Theme.Theme.fg
    property color mutedColor: Theme.Theme.muted
    property int fontSize: Theme.Theme.fontSize

    Layout.leftMargin: Theme.Theme.gap
    Layout.rightMargin: Theme.Theme.gap
    implicitWidth: volumeSlot.implicitWidth
    implicitHeight: volumeSlot.implicitHeight

    Process {
        id: wpctlProc
    }

    SlotText {
        id: volumeSlot

        anchors.fill: parent
        widthSamples: ["Vol: 100%", "Vol: Muted"]
        content: volumeText

        StyledText {
            id: volumeText

            text: root.muted ? "Vol: Muted" : "Vol: " + Math.round(root.volume * 100) + "%"
            textColor: root.muted ? root.mutedColor : root.textColor
            fontSize: root.fontSize
        }

    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            wpctlProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
            wpctlProc.running = true;
        }
        onWheel: (wheel) => {
            if (wheel.angleDelta.y === 0) {
                wheel.accepted = false;
                return;
            }
            wpctlProc.command = wheel.angleDelta.y > 0 ? ["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", "1%+"] : ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "1%-"];
            wpctlProc.running = true;
        }
    }

}
