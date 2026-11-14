import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "pollers"
import "components/widgets"
import "components/labels"
import "components/common"
import "theme" as Theme

ShellRoot {
    MemPoller {
        id: memPoller
    }

    CpuPoller {
        id: cpuPoller
    }

    BatteryPoller {
        id: batteryPoller
    }

    BatteryStatusPoller {
        id: batteryStatusPoller
    }

    CpuTempPoller {
        id: cpuTempPoller
    }

    GpuTempPoller {
        id: gpuTempPoller
    }

    StoragePoller {
        id: storagePoller
    }

    PowerProfilePoller {
        id: powerProfilePoller
    }

    IdleInhibitorPoller {
        id: idleInhibitorPoller
    }

    VolumePoller {
        id: volumePoller
    }

    NightLightPoller {
        id: nightLightPoller
    }

    NotificationServer {
        id: notificationServer

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        inlineReplySupported: true
        persistenceSupported: true
        onNotification: (notification) => {
            return notification.tracked = true;
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Scope {
                id: screenScope

                required property var modelData

                PanelWindow {
                    id: barWindow

                    property bool showCpuFahrenheit: false
                    property bool showGpuFahrenheit: false
                    property bool diagnosticsExpanded: true

                    screen: screenScope.modelData
                    anchors.top: true
                    anchors.left: true
                    anchors.right: true
                    implicitHeight: Theme.Theme.barHeight
                    color: Theme.Theme.bg

                    Item {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.Theme.gap
                        anchors.right: middleSection.left
                        anchors.rightMargin: Theme.Theme.gap
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        clip: true

                        RowLayout {
                            id: leftSection

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: implicitWidth
                            spacing: Theme.Theme.gap

                            StyledText {
                                text: "(^_^)-O"
                            }

                            Seperator {
                            }

                            WorkspaceSwitcher {
                            }

                            Seperator {
                            }

                            SystemTrayWidget {
                                screen: screenScope.modelData
                            }

                            Seperator {
                            }

                            MediaControls {
                            }

                        }

                    }

                    RowLayout {
                        id: middleSection

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.Theme.gap

                        Seperator {
                        }

                        Clock {
                            id: clock
                        }

                        Seperator {
                        }

                    }

                    Item {
                        id: rightSection

                        anchors.left: middleSection.right
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.Theme.gap
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        clip: true

                        RowLayout {
                            id: pinnedRow

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.Theme.gap

                            NotificationIndicator {
                                id: notificationIndicator

                                unreadCount: notificationServer.trackedNotifications.values.length
                            }

                        }

                        Flickable {
                            id: rightScrollArea

                            property bool hasOverflow: scrollContent.implicitWidth > (rightSection.width - pinnedRow.width - Theme.Theme.gap)

                            anchors.left: parent.left
                            anchors.right: pinnedRow.left
                            anchors.leftMargin: hasOverflow ? 18 : 0
                            anchors.rightMargin: Theme.Theme.gap + (hasOverflow ? 18 : 0)
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            contentWidth: Math.max(scrollContent.implicitWidth, width)
                            contentHeight: height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            flickableDirection: Flickable.HorizontalFlick

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: (event) => {
                                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                                    rightScrollArea.contentX = Math.max(0, Math.min(rightScrollArea.contentWidth - rightScrollArea.width, rightScrollArea.contentX - delta));
                                }
                            }

                            RowLayout {
                                id: scrollContent

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.Theme.gap

                                WidgetFolder {
                                    label: "System"
                                    expanded: barWindow.diagnosticsExpanded
                                    onToggleRequested: barWindow.diagnosticsExpanded = !barWindow.diagnosticsExpanded

                                    Seperator {
                                        visible: barWindow.diagnosticsExpanded
                                    }

                                    UsageLabel {
                                        label: "CPU: "
                                        value: cpuPoller.cpuUsage
                                        append: "%"
                                        visible: barWindow.diagnosticsExpanded
                                    }

                                    TempToggleLabel {
                                        tempC: cpuTempPoller.tempC
                                        tempF: cpuTempPoller.tempF
                                        showFahrenheit: barWindow.showCpuFahrenheit
                                        onClicked: barWindow.showCpuFahrenheit = !barWindow.showCpuFahrenheit
                                        visible: barWindow.diagnosticsExpanded
                                    }

                                    Seperator {
                                        visible: barWindow.diagnosticsExpanded
                                    }

                                    TempToggleLabel {
                                        label: "GPU: "
                                        tempC: gpuTempPoller.tempC
                                        tempF: gpuTempPoller.tempF
                                        showFahrenheit: barWindow.showGpuFahrenheit
                                        onClicked: barWindow.showGpuFahrenheit = !barWindow.showGpuFahrenheit
                                        visible: barWindow.diagnosticsExpanded
                                    }

                                    Seperator {
                                        visible: barWindow.diagnosticsExpanded
                                    }

                                    DiskUsageLabel {
                                        label: "Disk: "
                                        usedStorage: storagePoller.usedStorage
                                        totalStorage: storagePoller.totalStorage
                                        percentage: storagePoller.percentage
                                        visible: barWindow.diagnosticsExpanded
                                    }

                                    Seperator {
                                        visible: barWindow.diagnosticsExpanded
                                    }

                                    UsageLabel {
                                        label: "Mem: "
                                        value: memPoller.memUsage
                                        append: "%"
                                        visible: barWindow.diagnosticsExpanded
                                    }

                                    Seperator {
                                    }

                                }

                                VolumeWidget {
                                    volume: volumePoller.volume
                                    muted: volumePoller.muted
                                }

                                Seperator {
                                }

                                NightLightButton {
                                    nightLightEnabled: nightLightPoller.nightLightEnabled
                                    onToggleRequested: nightLightPoller.toggle()
                                }

                                Seperator {
                                    visible: batteryPoller.hasBattery
                                }

                                BatteryWidget {
                                    percentage: batteryPoller.percentage
                                    charging: batteryPoller.isCharging
                                    visible: batteryPoller.hasBattery
                                }

                                BatteryStatusLabel {
                                    status: batteryStatusPoller.status
                                    timeToFullSec: batteryStatusPoller.timeToFullSec
                                    hasBattery: batteryStatusPoller.hasBattery
                                    visible: batteryStatusPoller.hasBattery
                                }

                                Seperator {
                                    visible: batteryPoller.hasBattery
                                }

                                PowerProfileButton {
                                    profile: powerProfilePoller.profile
                                    availableProfiles: powerProfilePoller.availableProfiles
                                    pending: powerProfilePoller.pending
                                    visible: batteryPoller.hasBattery && powerProfilePoller.availableProfiles.length > 0
                                    onProfileChangeRequested: (next) => {
                                        return powerProfilePoller.setProfile(next);
                                    }
                                }

                                Seperator {
                                }

                                IdleInhibitorButton {
                                    inhibitEnabled: idleInhibitorPoller.inhibitEnabled
                                    onToggleRequested: idleInhibitorPoller.toggle()
                                }

                                Seperator {
                                }

                            }

                        }

                        Item {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: parent.height
                            z: 1
                            visible: rightScrollArea.hasOverflow && rightScrollArea.contentX > 0

                            StyledText {
                                anchors.centerIn: parent
                                text: "<-"
                                fontSize: Theme.Theme.fontSize
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rightScrollArea.contentX = Math.max(0, rightScrollArea.contentX - rightScrollArea.width * 0.75)
                            }

                        }

                        Item {
                            anchors.right: pinnedRow.left
                            anchors.rightMargin: Theme.Theme.gap
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: parent.height
                            z: 1
                            visible: rightScrollArea.hasOverflow && rightScrollArea.contentX < rightScrollArea.contentWidth - rightScrollArea.width

                            StyledText {
                                anchors.centerIn: parent
                                text: "->"
                                fontSize: Theme.Theme.fontSize
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rightScrollArea.contentX = Math.min(rightScrollArea.contentWidth - rightScrollArea.width, rightScrollArea.contentX + rightScrollArea.width * 0.75)
                            }

                        }

                    }

                }

                PanelWindow {
                    id: calendarWindow

                    // property bool hoverActive: clock.hovered || calendarPopup.hovered
                    property bool hoverActive: clock.hovered

                    screen: screenScope.modelData
                    anchors.top: true
                    anchors.left: true
                    anchors.right: true
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    visible: hoverActive || calendarCloseTimer.running
                    implicitHeight: calendarPopup.implicitHeight
                    margins.top: Theme.Theme.barHeight
                    onHoverActiveChanged: hoverActive ? calendarCloseTimer.stop() : calendarCloseTimer.start()

                    Timer {
                        id: calendarCloseTimer

                        interval: 300
                    }

                    CalendarPopup {
                        id: calendarPopup

                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                }

                PanelWindow {
                    id: notificationWindow

                    property bool hoverActive: notificationIndicator.hovered || notificationPopup.hovered

                    screen: screenScope.modelData
                    anchors.top: true
                    anchors.left: true
                    anchors.right: true
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    visible: hoverActive || notificationCloseTimer.running
                    implicitHeight: notificationPopup.implicitHeight
                    margins.top: Theme.Theme.barHeight
                    onHoverActiveChanged: hoverActive ? notificationCloseTimer.stop() : notificationCloseTimer.start()

                    Timer {
                        id: notificationCloseTimer

                        interval: 300
                    }

                    NotificationPopup {
                        id: notificationPopup

                        notifServer: notificationServer
                        anchors.right: parent.right
                        anchors.rightMargin: 0
                    }

                }

                PanelWindow {
                    id: toastWindow

                    screen: screenScope.modelData
                    anchors.top: true
                    anchors.right: true
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    visible: toastStack.count > 0
                    implicitWidth: 320
                    implicitHeight: toastStack.implicitHeight
                    margins.top: Theme.Theme.barHeight + Theme.Theme.gap
                    margins.right: Theme.Theme.gap

                    Connections {
                        function onNotification(notification) {
                            toastStack.show(notification);
                        }

                        target: notificationServer
                    }

                    NotificationToastStack {
                        id: toastStack
                    }

                }

            }

        }

    }

}
