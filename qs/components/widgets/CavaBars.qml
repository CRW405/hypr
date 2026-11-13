import QtQuick
import Quickshell.Io
import "../../theme" as Theme

Item {
    id: root

    clip: true

    property int bars: 20 // change it in cava.conf too
    property int maxValue: 750
    property int barWidth: 4
    property int barSpacing: 2
    property int padding: 2
    // property int barHeight: Theme.Theme.barHeight
    property int barHeight: Theme.Theme.iconSize * 2
    property int radius: Theme.Theme.radius
    property int barRadius: Theme.Theme.radius
    property color barColor: Theme.Theme.accent
    property color backgroundColor: "transparent"
    property var values: []
    readonly property string cavaConfigPath: Qt.resolvedUrl("cava.conf").toString().replace("file://", "")

    implicitWidth: (bars * barWidth) + ((bars - 1) * barSpacing) + padding * 2
    implicitHeight: barHeight

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
        radius: root.radius
    }

    Row {
        id: barRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding
        spacing: root.barSpacing

        Repeater {
            model: root.bars

            Rectangle {
                width: root.barWidth
                height: {
                    var value = root.values[index] || 0;
                    if (value <= 0)
                        return 0;

                    return Math.max(1, Math.round((value / root.maxValue) * (root.height - root.padding * 2)));
                }
                radius: root.barRadius
                color: root.barColor
                anchors.bottom: parent.bottom
            }

        }

    }

    Process {
        id: cavaProc

        command: ["cava", "-p", root.cavaConfigPath]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                const parts = data.trim().split(";");
                if (parts.length < root.bars)
                    return ;

                const next = [];
                for (let i = 0; i < root.bars; i++) {
                    const value = parseInt(parts[i], 10);
                    next.push(Number.isFinite(value) ? Math.min(root.maxValue, value) : 0);
                }
                root.values = next;
            }
        }

    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!cavaProc.running)
                cavaProc.running = true;

        }
    }

}
