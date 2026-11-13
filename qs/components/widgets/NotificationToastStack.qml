import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "../common"
import "../../theme" as Theme

ColumnLayout {
    id: root

    property int autoHideMs: 5000
    readonly property int count: toasts.count

    spacing: Theme.Theme.gap

    function show(notification) {
        toasts.append({
            notifId: notification.id,
            summary: notification.summary,
            body: notification.body,
            urgency: notification.urgency
        });
    }

    function dismiss(notifId) {
        for (let i = 0; i < toasts.count; i++) {
            if (toasts.get(i).notifId === notifId) {
                toasts.remove(i);
                return;
            }
        }
    }

    ListModel {
        id: toasts
    }

    Repeater {
        model: toasts

        delegate: Rectangle {
            id: toastCard
            required property int notifId
            required property string summary
            required property string body
            required property int urgency
            readonly property color urgencyColor: urgency === NotificationUrgency.Critical ? Theme.Theme.warn : urgency === NotificationUrgency.Low ? Theme.Theme.muted : Theme.Theme.accent

            Layout.preferredWidth: 320
            Layout.preferredHeight: content.implicitHeight + Theme.Theme.gap * 2
            color: Theme.Theme.bg
            border.color: Theme.Theme.muted
            border.width: 1
            radius: Theme.Theme.radius
            clip: true

            ColumnLayout {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Theme.Theme.gap + 5
                anchors.rightMargin: Theme.Theme.gap
                anchors.topMargin: Theme.Theme.gap
                height: implicitHeight
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: toastCard.summary
                    textColor: Theme.Theme.fg
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: toastCard.body
                    textColor: Theme.Theme.muted
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3
                color: toastCard.urgencyColor
                visible: toastCard.urgency !== NotificationUrgency.Low
            }

            Timer {
                interval: root.autoHideMs
                running: true
                onTriggered: root.dismiss(toastCard.notifId)
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.dismiss(toastCard.notifId)
            }
        }
    }
}
