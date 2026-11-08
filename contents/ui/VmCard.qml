import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property var vmData: ({})
    property string defaultMode: "gui"

    signal startRequested(string uuid, string mode)
    signal pauseRequested(string uuid)
    signal resumeRequested(string uuid)
    signal saveRequested(string uuid)
    signal shutdownRequested(string uuid)
    signal consoleRequested(string uuid)
    signal favoriteToggled(string uuid)

    // Palette Colors
    readonly property color colBgCard: "#24283B"
    readonly property color colBgHover: "#2F354D"
    readonly property color colBorder: "#414868"
    readonly property color colBorderHover: "#565F89"
    readonly property color colTextPri: "#C0CAF5"
    readonly property color colTextSec: "#9AA5CE"
    readonly property color colBlue: "#7AA2F7"
    readonly property color colPurple: "#BB9AF7"
    readonly property color colCyan: "#7DCFFF"
    readonly property color colOrange: "#E0AF68"
    readonly property color colGreen: "#9ECE6A"
    readonly property color colRed: "#F7768E"

    Layout.fillWidth: true
    implicitHeight: mainLayout.implicitHeight + 20
    radius: 12
    color: hoverArea.containsMouse ? colBgHover : colBgCard
    border.color: hoverArea.containsMouse ? colBorderHover : colBorder
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 8

        // 1. Header: OS Icon + VM Name + State + Favorite Pin
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // OS Distro Icon
            Rectangle {
                width: 28
                height: 28
                radius: 6
                color: Qt.rgba(0.102, 0.106, 0.149, 0.6)
                border.color: Qt.rgba(0.255, 0.282, 0.408, 0.4)
                border.width: 1

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: root.vmData.osIcon || "computer"
                    fallback: "computer"
                }
            }

            // Name & State
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.vmData.name || "Unknown VM"
                    color: root.colTextPri
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                RowLayout {
                    spacing: 5

                    // Status Indicator Dot with Glow
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: root.vmData.stateColor || root.colTextSec

                        Rectangle {
                            anchors.centerIn: parent
                            width: 13
                            height: 13
                            radius: 6.5
                            color: root.vmData.stateColor || root.colTextSec
                            opacity: 0.25
                        }
                    }

                    Text {
                        text: root.vmData.stateLabel || "Unknown"
                        color: root.vmData.stateColor || root.colTextSec
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }
            }

            // Favorite Pin Star Button
            Rectangle {
                width: 24
                height: 24
                radius: 4
                color: favMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: root.vmData.isFavorite ? "★" : "☆"
                    color: root.vmData.isFavorite ? root.colOrange : root.colTextSec
                    font.pixelSize: 14
                }

                MouseArea {
                    id: favMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.favoriteToggled(root.vmData.uuid)
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: root.vmData.isFavorite ? i18n("Unpin from favorites") : i18n("Pin to top")
                }
            }
        }

        // 2. Hardware Specs Badges
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // vCPU Badge
            Rectangle {
                height: 18
                radius: 4
                color: Qt.rgba(0.102, 0.106, 0.149, 0.5)
                border.color: Qt.rgba(0.478, 0.635, 0.969, 0.3)
                border.width: 1
                implicitWidth: cpuRow.implicitWidth + 8

                RowLayout {
                    id: cpuRow
                    anchors.centerIn: parent
                    spacing: 3
                    Text { text: "⚙"; font.pixelSize: 9; color: root.colBlue }
                    Text { text: (root.vmData.cpus || 1) + " vCPU"; font.pixelSize: 10; color: root.colTextSec }
                }
            }

            // RAM Badge
            Rectangle {
                height: 18
                radius: 4
                color: Qt.rgba(0.102, 0.106, 0.149, 0.5)
                border.color: Qt.rgba(0.733, 0.604, 0.969, 0.3)
                border.width: 1
                implicitWidth: ramRow.implicitWidth + 8

                RowLayout {
                    id: ramRow
                    anchors.centerIn: parent
                    spacing: 3
                    Text { text: "⚡"; font.pixelSize: 9; color: root.colPurple }
                    Text { text: root.vmData.memoryLabel || "RAM"; font.pixelSize: 10; color: root.colTextSec }
                }
            }

            // Network Badge
            Rectangle {
                height: 18
                radius: 4
                color: Qt.rgba(0.102, 0.106, 0.149, 0.5)
                border.color: Qt.rgba(0.490, 0.812, 1.0, 0.3)
                border.width: 1
                implicitWidth: netRow.implicitWidth + 8

                RowLayout {
                    id: netRow
                    anchors.centerIn: parent
                    spacing: 3
                    Text { text: "🌐"; font.pixelSize: 9; color: root.colCyan }
                    Text { text: root.vmData.network || "Net"; font.pixelSize: 10; color: root.colTextSec }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // 3. Interactive VM Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // When VM is busy (operation executing)
            Rectangle {
                visible: root.vmData.isBusy
                Layout.fillWidth: true
                height: 26
                radius: 6
                color: Qt.rgba(0.478, 0.635, 0.969, 0.15)
                border.color: root.colBlue
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    QQC2.BusyIndicator {
                        implicitWidth: 16
                        implicitHeight: 16
                        running: root.vmData.isBusy
                    }
                    Text {
                        text: i18n("Operation in progress…")
                        color: root.colBlue
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }
            }

            // START BUTTON (Powered Off, Saved, Aborted)
            Rectangle {
                visible: !root.vmData.isBusy && root.vmData.canStart
                Layout.fillWidth: true
                height: 26
                radius: 6
                color: startBtnMouse.containsMouse ? Qt.rgba(0.478, 0.635, 0.969, 0.35) : Qt.rgba(0.478, 0.635, 0.969, 0.2)
                border.color: root.colBlue
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "▶"; color: root.colBlue; font.pixelSize: 10 }
                    Text { text: i18n("Start"); color: root.colTextPri; font.pixelSize: 11; font.weight: Font.Bold }
                }

                MouseArea {
                    id: startBtnMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.startRequested(root.vmData.uuid, root.defaultMode)
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: i18n("Start Virtual Machine (%1 mode)", root.defaultMode.toUpperCase())
                }
            }

            // HEADLESS START BUTTON (Optional quick action for server lab VMs)
            Rectangle {
                visible: !root.vmData.isBusy && root.vmData.canStart && root.defaultMode !== "headless"
                width: 26
                height: 26
                radius: 6
                color: headlessBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                border.color: root.colBorder
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "◲"
                    color: root.colTextSec
                    font.pixelSize: 12
                }

                MouseArea {
                    id: headlessBtnMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.startRequested(root.vmData.uuid, "headless")
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: i18n("Start in background (Headless mode)")
                }
            }

            // OPEN / CONSOLE BUTTON (When running)
            Rectangle {
                visible: !root.vmData.isBusy && root.vmData.stateRaw === "running"
                Layout.fillWidth: true
                height: 26
                radius: 6
                color: consoleBtnMouse.containsMouse ? Qt.rgba(0.490, 0.812, 1.0, 0.3) : Qt.rgba(0.490, 0.812, 1.0, 0.15)
                border.color: root.colCyan
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "🖥"; font.pixelSize: 10 }
                    Text { text: i18n("Console"); color: root.colTextPri; font.pixelSize: 11; font.weight: Font.DemiBold }
                }

                MouseArea {
                    id: consoleBtnMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.consoleRequested(root.vmData.uuid)
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: i18n("Show graphical VM console window")
                }
            }

            // PAUSE BUTTON (When running)
            Rectangle {
                visible: !root.vmData.isBusy && root.vmData.canPause
                width: 32
                height: 26
                radius: 6
                color: pauseBtnMouse.containsMouse ? Qt.rgba(0.878, 0.686, 0.408, 0.3) : Qt.rgba(0.878, 0.686, 0.408, 0.15)
                border.color: root.colOrange
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "⏸"
                    color: root.colOrange
                    font.pixelSize: 11
                }

                MouseArea {
                    id: pauseBtnMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.pauseRequested(root.vmData.uuid)
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: i18n("Pause virtual machine execution")
                }
            }

            // RESUME BUTTON (When paused)
            Rectangle {
                visible: !root.vmData.isBusy && root.vmData.canResume
                Layout.fillWidth: true
                height: 26
                radius: 6
                color: resumeBtnMouse.containsMouse ? Qt.rgba(0.620, 0.808, 0.416, 0.35) : Qt.rgba(0.620, 0.808, 0.416, 0.2)
                border.color: root.colGreen
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "▶"; color: root.colGreen; font.pixelSize: 10 }
                    Text { text: i18n("Resume"); color: root.colTextPri; font.pixelSize: 11; font.weight: Font.Bold }
                }

                MouseArea {
                    id: resumeBtnMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.resumeRequested(root.vmData.uuid)
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: i18n("Resume paused virtual machine")
                }
            }

            // SAVE STATE BUTTON (When running or paused)
            Rectangle {
                visible: !root.vmData.isBusy && root.vmData.canSave
                width: 32
                height: 26
                radius: 6
                color: saveBtnMouse.containsMouse ? Qt.rgba(0.733, 0.604, 0.969, 0.3) : Qt.rgba(0.733, 0.604, 0.969, 0.15)
                border.color: root.colPurple
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "💾"
                    color: root.colPurple
                    font.pixelSize: 11
                }

                MouseArea {
                    id: saveBtnMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.saveRequested(root.vmData.uuid)
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: i18n("Save VM state and suspend")
                }
            }

            // GRACEFUL SHUTDOWN BUTTON (ACPI Power Button)
            Rectangle {
                visible: !root.vmData.isBusy && root.vmData.canShutdown
                width: 32
                height: 26
                radius: 6
                color: shutdownBtnMouse.containsMouse ? Qt.rgba(0.969, 0.463, 0.557, 0.3) : Qt.rgba(0.969, 0.463, 0.557, 0.15)
                border.color: root.colRed
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "⏻"
                    color: root.colRed
                    font.pixelSize: 12
                }

                MouseArea {
                    id: shutdownBtnMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.shutdownRequested(root.vmData.uuid)
                    QQC2.ToolTip.visible: containsMouse
                    QQC2.ToolTip.text: i18n("ACPI Graceful Shutdown\nSends power-button signal to guest OS.")
                }
            }
        }
    }
}
