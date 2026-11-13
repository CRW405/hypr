import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications
import "../common"
import "../../theme" as Theme

Rectangle {
    id: root

    property var notifServer: null
    readonly property bool hovered: hoverHandler.hovered
    readonly property int popupPadding: Theme.Theme.gap
    readonly property int itemPadding: 2
    readonly property int itemBottomPadding: Theme.Theme.gap
    readonly property int collapsedItemHeight: Theme.Theme.fontSize * 4 + itemPadding * 2 + itemBottomPadding * 2
    readonly property int count: notifServer ? notifServer.trackedNotifications.values.length : 0

    function clearAll() {
        if (!notifServer)
            return
        var notifications = notifServer.trackedNotifications.values
        for (var i = notifications.length - 1; i >= 0; i--)
            notifications[i].dismiss()
    }

    color: Theme.Theme.bg
    border.color: Theme.Theme.muted
    border.width: 1
    radius: Theme.Theme.radius
    implicitWidth: 320
    implicitHeight: Math.min(400, list.contentHeight + popupPadding * 2)

    HoverHandler {
        id: hoverHandler
    }

    Flickable {
        id: list

        anchors.fill: parent
        anchors.margins: root.popupPadding
        clip: true
        contentWidth: contentColumn.width
        contentHeight: contentColumn.height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: contentColumn

            width: list.width - 6
            height: implicitHeight
            spacing: Theme.Theme.gap

            ColumnLayout {
                visible: root.count > 0
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        text: "Notifications"
                        textColor: Theme.Theme.fg
                    }

                    StyledText {
                        text: "Clear all"
                        textColor: Theme.Theme.accent

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearAll()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.Theme.muted
                    opacity: 0.6
                }
            }

            StyledText {
                visible: root.count === 0
                text: "No notifications"
                textColor: Theme.Theme.muted
            }

            Repeater {
                model: root.notifServer ? root.notifServer.trackedNotifications : null

                delegate: Rectangle {
                    id: notifRow

                    required property var modelData
                    required property int index
                    property bool expanded: false
                    readonly property color urgencyColor: modelData.urgency === NotificationUrgency.Critical ? Theme.Theme.warn : modelData.urgency === NotificationUrgency.Low ? Theme.Theme.muted : Theme.Theme.accent
                    readonly property string category: modelData.hints && modelData.hints.category ? modelData.hints.category : ""
                    readonly property string metadataText: {
                        var details = []
                        if (category) details.push("Category: " + category)
                        if (modelData.expireTimeout > 0) details.push("Timeout: " + modelData.expireTimeout + "s")
                        if (modelData.transient) details.push("Transient")
                        if (modelData.resident) details.push("Resident")
                        return details.join(" | ")
                    }
                    readonly property bool canExpand: summaryText.truncated || bodyText.truncated || modelData.image !== "" || modelData.actions.length > 0 || modelData.hasInlineReply || metadataText.length > 0
                    readonly property bool canToggleExpansion: expanded || canExpand

                    function sendReply() {
                        var reply = replyInput.text.trim()
                        if (!reply || !modelData.hasInlineReply)
                            return
                        modelData.sendInlineReply(reply)
                        replyInput.clear()
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: expanded ? notificationContent.implicitHeight + root.itemPadding + root.itemBottomPadding : root.collapsedItemHeight
                    color: "transparent"
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: notifRow.canToggleExpansion ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.MiddleButton)
                                notifRow.modelData.dismiss()
                            else if (notifRow.canToggleExpansion)
                                notifRow.expanded = !notifRow.expanded
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: root.itemPadding
                        anchors.leftMargin: root.itemPadding + 5
                        anchors.bottomMargin: root.itemBottomPadding
                        spacing: Theme.Theme.gap

                        ColumnLayout {
                            id: notificationContent

                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.Theme.gap

                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignLeft
                                    text: notifRow.modelData.appName || notifRow.modelData.desktopEntry || "Notification"
                                    textColor: Theme.Theme.muted
                                    elide: Text.ElideRight
                                }

                                Image {
                                    source: notifRow.modelData.appIcon ? Quickshell.iconPath(notifRow.modelData.appIcon, "application-x-executable") : ""
                                    visible: source !== ""
                                    sourceSize.width: 20
                                    sourceSize.height: 20
                                    Layout.preferredWidth: visible ? 20 : 0
                                    Layout.preferredHeight: visible ? 20 : 0
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: summaryText.implicitHeight
                                clip: true

                                StyledText {
                                    id: summaryText

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    text: notifRow.modelData.summary
                                    textColor: Theme.Theme.fg
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    maximumLineCount: notifRow.expanded ? -1 : 1
                                    elide: notifRow.expanded ? Text.ElideNone : Text.ElideRight
                                    clip: true
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    width: 20
                                    height: parent.height
                                    color: Theme.Theme.bg
                                    visible: !notifRow.expanded && summaryText.truncated

                                    StyledText {
                                        anchors.fill: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "..."
                                        textColor: Theme.Theme.muted
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: bodyText.implicitHeight
                                clip: true

                                StyledText {
                                    id: bodyText

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    text: notifRow.modelData.body
                                    textColor: Theme.Theme.muted
                                    textFormat: Text.RichText
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    maximumLineCount: notifRow.expanded ? -1 : 1
                                    elide: notifRow.expanded ? Text.ElideNone : Text.ElideRight
                                    clip: true
                                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    width: 20
                                    height: parent.height
                                    color: Theme.Theme.bg
                                    visible: !notifRow.expanded && bodyText.truncated

                                    StyledText {
                                        anchors.fill: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "..."
                                        textColor: Theme.Theme.muted
                                    }
                                }
                            }

                            Image {
                                source: notifRow.expanded ? notifRow.modelData.image : ""
                                visible: source !== "" && status === Image.Ready
                                sourceSize.width: 280
                                Layout.fillWidth: true
                                Layout.preferredHeight: visible ? Math.min(160, implicitHeight) : 0
                                fillMode: Image.PreserveAspectFit
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: notifRow.expanded && notifRow.metadataText.length > 0
                                text: notifRow.metadataText
                                textColor: Theme.Theme.muted
                                fontSize: Theme.Theme.fontSize - 1
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            }

                            Flow {
                                Layout.fillWidth: true
                                Layout.preferredHeight: childrenRect.height
                                visible: notifRow.expanded && notifRow.modelData.actions.length > 0
                                spacing: Theme.Theme.gap

                                Repeater {
                                    model: notifRow.modelData.actions

                                    delegate: Rectangle {
                                        required property var modelData

                                        implicitWidth: actionLabel.implicitWidth + Theme.Theme.gap * 2 + (notifRow.modelData.hasActionIcons ? 14 + Theme.Theme.gap : 0)
                                        implicitHeight: actionLabel.implicitHeight + Theme.Theme.gap
                                        color: Theme.Theme.bgAlt
                                        border.color: Theme.Theme.muted
                                        border.width: 1
                                        radius: Theme.Theme.radius

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: Theme.Theme.gap

                                            Image {
                                                visible: notifRow.modelData.hasActionIcons
                                                source: visible ? Quickshell.iconPath(modelData.identifier, "") : ""
                                                sourceSize.width: 14
                                                sourceSize.height: 14
                                                Layout.preferredWidth: visible ? 14 : 0
                                                Layout.preferredHeight: visible ? 14 : 0
                                                fillMode: Image.PreserveAspectFit
                                            }

                                            StyledText {
                                                id: actionLabel
                                                text: modelData.text
                                                textColor: Theme.Theme.fg
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: modelData.invoke()
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                visible: notifRow.expanded && notifRow.modelData.hasInlineReply
                                Layout.fillWidth: true
                                spacing: Theme.Theme.gap

                                TextField {
                                    id: replyInput
                                    Layout.fillWidth: true
                                    placeholderText: notifRow.modelData.inlineReplyPlaceholder || "Reply"
                                    color: Theme.Theme.fg
                                    placeholderTextColor: Theme.Theme.muted
                                    font.pixelSize: Theme.Theme.fontSize
                                    font.family: Theme.Theme.fontFamily
                                    onAccepted: notifRow.sendReply()
                                    background: Rectangle {
                                        color: Theme.Theme.bgAlt
                                        border.color: Theme.Theme.muted
                                        border.width: 1
                                        radius: Theme.Theme.radius
                                    }
                                }

                                StyledText {
                                    text: "Send"
                                    textColor: Theme.Theme.accent

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notifRow.sendReply()
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 34
                            spacing: 2

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                visible: notifRow.canExpand || notifRow.expanded
                                text: notifRow.expanded ? "Less" : "More"
                                textColor: Theme.Theme.accent

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: notifRow.expanded = !notifRow.expanded
                                }
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "X"
                                textColor: Theme.Theme.warn

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: notifRow.modelData.dismiss()
                                }
                            }

                        }

                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: notifRow.urgencyColor
                        visible: notifRow.modelData.urgency !== NotificationUrgency.Low
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Theme.Theme.muted
                        opacity: 0.45
                        visible: notifRow.index < root.count - 1
                    }
                }

            }

        }

        ScrollBar.vertical: ScrollBar {
            policy: list.contentHeight > list.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: 5

            background: Rectangle {
                color: Theme.Theme.bgAlt
                radius: width / 2
            }

            contentItem: Rectangle {
                color: Theme.Theme.accent
                radius: width / 2
            }
        }

    }

}
