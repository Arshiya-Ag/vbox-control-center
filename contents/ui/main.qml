import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // Tell Plasma shell not to render any default theme background or frame
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // Preferred and minimum sizing for clean floating portrait card
    preferredRepresentation: fullRepresentation
    Layout.preferredWidth: 360
    Layout.preferredHeight: 520
    Layout.minimumWidth: 320
    Layout.minimumHeight: 380

    // Tokyo Night Palette Constants
    readonly property color colBg: "#1A1B26"
    readonly property color colBgCard: "#24283B"
    readonly property color colTextPri: "#C0CAF5"
    readonly property color colTextSec: "#9AA5CE"
    readonly property color colBlue: "#7AA2F7"
    readonly property color colPurple: "#BB9AF7"
    readonly property color colCyan: "#7DCFFF"
    readonly property color colGreen: "#9ECE6A"
    readonly property color colOrange: "#E0AF68"
    readonly property color colRed: "#F7768E"
    readonly property color colBorder: "#414868"

    readonly property real cardOpacity: (Plasmoid.configuration && Plasmoid.configuration.cardOpacity > 0)
        ? Plasmoid.configuration.cardOpacity : 0.88

    readonly property int refreshSecs: (Plasmoid.configuration && Plasmoid.configuration.refreshInterval > 0)
        ? Plasmoid.configuration.refreshInterval : 8

    readonly property string defaultStartMode: (Plasmoid.configuration && Plasmoid.configuration.defaultStartMode)
        ? Plasmoid.configuration.defaultStartMode : "gui"

    // VM Data State
    property var allVms: []
    property bool isLoading: false
    property string statusMessage: ""
    property string searchQuery: ""
    property int runningCount: 0
    property int stoppedCount: 0

    // Update Counts
    function updateCounts() {
        var r = 0;
        var s = 0;
        for (var i = 0; i < root.allVms.length; ++i) {
            if (root.allVms[i].stateCategory === "running") {
                r++;
            } else {
                s++;
            }
        }
        root.runningCount = r;
        root.stoppedCount = s;
    }

    // Filtered Model
    readonly property var filteredVms: {
        var list = root.allVms || [];
        var q = root.searchQuery.trim().toLowerCase();
        if (!q) {
            return list;
        }
        return list.filter(function(vm) {
            var name = (vm.name || "").toLowerCase();
            var os = (vm.ostype || "").toLowerCase();
            var state = (vm.stateLabel || "").toLowerCase();
            return name.indexOf(q) !== -1 || os.indexOf(q) !== -1 || state.indexOf(q) !== -1;
        });
    }

    // -------------------------------------------------------------
    // D-Bus Asynchronous Command Execution
    // -------------------------------------------------------------
    Plasma5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            var stdout = (data["stdout"] || "").trim();
            var stderr = (data["stderr"] || "").trim();
            var exitCode = data["exit code"];

            disconnectSource(sourceName);

            if (sourceName.indexOf("GetVMs") !== -1) {
                root.isLoading = false;
                if (stdout) {
                    try {
                        root.allVms = JSON.parse(stdout);
                        root.updateCounts();
                        root.statusMessage = "";
                    } catch (e) {
                        root.statusMessage = "JSON Parse error: " + e;
                    }
                } else if (stderr) {
                    root.statusMessage = stderr;
                }
            } else if (sourceName.indexOf("Refresh") !== -1) {
                // Triggered a refresh, fetch new VMs
                root.fetchVms();
            } else {
                // Operation completed (start, pause, etc.)
                root.fetchVms();
            }
        }
    }

    function runDbusCmd(cmd) {
        execSource.connectSource(cmd);
    }

    function fetchVms() {
        root.isLoading = true;
        var cmd = "qdbus-qt6 org.kde.plasma.vboxcontrolcenter /VirtualBox org.kde.plasma.VirtualBoxControlCenter.GetVMs";
        runDbusCmd(cmd);
    }

    function triggerRefresh() {
        var cmd = "qdbus-qt6 org.kde.plasma.vboxcontrolcenter /VirtualBox org.kde.plasma.VirtualBoxControlCenter.Refresh";
        runDbusCmd(cmd);
    }

    function requestStartVM(uuid, mode) {
        var m = mode || root.defaultStartMode;
        var cmd = "qdbus-qt6 org.kde.plasma.vboxcontrolcenter /VirtualBox org.kde.plasma.VirtualBoxControlCenter.StartVM " + uuid + " " + m;
        runDbusCmd(cmd);
    }

    function requestPauseVM(uuid) {
        var cmd = "qdbus-qt6 org.kde.plasma.vboxcontrolcenter /VirtualBox org.kde.plasma.VirtualBoxControlCenter.PauseVM " + uuid;
        runDbusCmd(cmd);
    }

    function requestResumeVM(uuid) {
        var cmd = "qdbus-qt6 org.kde.plasma.vboxcontrolcenter /VirtualBox org.kde.plasma.VirtualBoxControlCenter.ResumeVM " + uuid;
        runDbusCmd(cmd);
    }

    function requestSaveVM(uuid) {
        var cmd = "qdbus-qt6 org.kde.plasma.vboxcontrolcenter /VirtualBox org.kde.plasma.VirtualBoxControlCenter.SaveStateVM " + uuid;
        runDbusCmd(cmd);
    }

    function requestShutdownVM(uuid) {
        var cmd = "qdbus-qt6 org.kde.plasma.vboxcontrolcenter /VirtualBox org.kde.plasma.VirtualBoxControlCenter.ShutdownVM " + uuid;
        runDbusCmd(cmd);
    }

    function requestConsoleVM(uuid) {
        var cmd = "qdbus-qt6 org.kde.plasma.vboxcontrolcenter /VirtualBox org.kde.plasma.VirtualBoxControlCenter.OpenConsole " + uuid;
        runDbusCmd(cmd);
    }

    function requestOpenManager() {
        var cmd = "qdbus-qt6 org.kde.plasma.vboxcontrolcenter /VirtualBox org.kde.plasma.VirtualBoxControlCenter.OpenManager";
        runDbusCmd(cmd);
    }

    function requestToggleFavorite(uuid) {
        var cmd = "qdbus-qt6 org.kde.plasma.vboxcontrolcenter /VirtualBox org.kde.plasma.VirtualBoxControlCenter.ToggleFavorite " + uuid;
        runDbusCmd(cmd);
    }

    // Auto Refresh Timer
    Timer {
        id: autoRefreshTimer
        interval: root.refreshSecs * 1000
        running: true
        repeat: true
        onTriggered: root.fetchVms()
    }

    Component.onCompleted: {
        root.fetchVms();
    }

    // Contextual Actions
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh Machines")
            icon.name: "view-refresh"
            onTriggered: root.fetchVms()
        },
        PlasmaCore.Action {
            text: i18n("Open VirtualBox Manager…")
            icon.name: "virtualbox"
            onTriggered: root.requestOpenManager()
        }
    ]

    // -------------------------------------------------------------
    // Full Representation: Floating macOS Tokyo Night Dashboard
    // -------------------------------------------------------------
    fullRepresentation: Item {
        id: container
        anchors.fill: parent

        // Outer Soft Drop Shadow
        Rectangle {
            anchors.fill: card
            anchors.margins: -4
            radius: card.radius + 4
            color: Qt.rgba(0, 0, 0, 0.22)
            z: -2
        }
        Rectangle {
            anchors.fill: card
            anchors.margins: -1
            anchors.topMargin: 0
            radius: card.radius + 1
            color: Qt.rgba(0, 0, 0, 0.35)
            z: -1
        }

        // Main Glass Card
        Rectangle {
            id: card
            anchors.fill: parent
            anchors.margins: 4
            radius: 20
            color: Qt.rgba(0.102, 0.106, 0.149, root.cardOpacity)
            border.color: Qt.rgba(0.255, 0.282, 0.408, 0.65)
            border.width: 1
            clip: true

            // Subtle Glassmorphism Top Highlight Line
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 1
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1.0, 1.0, 1.0, 0.14) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Card Content Layout
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                // 1. Header Section
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 8
                            Text {
                                text: i18n("◈ VIRTUAL MACHINES")
                                color: root.colTextPri
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                font.letterSpacing: 1.2
                            }

                            // Glowing Pulse Status Dot (Green if any running, Blue if none)
                            Rectangle {
                                width: 7
                                height: 7
                                radius: 3.5
                                color: root.runningCount > 0 ? root.colGreen : root.colBlue
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 13
                                    height: 13
                                    radius: 6.5
                                    color: root.runningCount > 0 ? root.colGreen : root.colBlue
                                    opacity: 0.25
                                }
                            }
                        }

                        Text {
                            text: i18n("VirtualBox Control Center")
                            color: root.colTextSec
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }

                    // Refresh Button
                    Rectangle {
                        width: 26
                        height: 26
                        radius: 6
                        color: refreshMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        border.color: refreshMouse.containsMouse ? root.colBorder : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "↻"
                            color: root.isLoading ? root.colBlue : root.colTextSec
                            font.pixelSize: 15
                            rotation: root.isLoading ? 360 : 0
                            Behavior on rotation {
                                NumberAnimation { duration: 600; loops: Animation.Infinite }
                            }
                        }

                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.fetchVms()
                            QQC2.ToolTip.visible: containsMouse
                            QQC2.ToolTip.delay: 600
                            QQC2.ToolTip.text: i18n("Refresh virtual machine statuses")
                        }
                    }
                }

                // 2. Summary Status Badge Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Running Count Pill
                    Rectangle {
                        height: 22
                        radius: 5
                        color: Qt.rgba(0.620, 0.808, 0.416, 0.15)
                        border.color: Qt.rgba(0.620, 0.808, 0.416, 0.35)
                        border.width: 1
                        implicitWidth: runningText.implicitWidth + 14

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Rectangle { width: 5; height: 5; radius: 2.5; color: root.colGreen }
                            Text {
                                id: runningText
                                text: root.runningCount + " " + i18n("Running")
                                color: root.colGreen
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    // Stopped Count Pill
                    Rectangle {
                        height: 22
                        radius: 5
                        color: Qt.rgba(0.604, 0.647, 0.808, 0.12)
                        border.color: Qt.rgba(0.604, 0.647, 0.808, 0.25)
                        border.width: 1
                        implicitWidth: stoppedText.implicitWidth + 14

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Rectangle { width: 5; height: 5; radius: 2.5; color: root.colTextSec }
                            Text {
                                id: stoppedText
                                text: root.stoppedCount + " " + i18n("Powered Off")
                                color: root.colTextSec
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // 3. Search Bar (Toggleable / Configurable)
                Rectangle {
                    visible: !Plasmoid.configuration || Plasmoid.configuration.showSearch !== false
                    Layout.fillWidth: true
                    height: 28
                    radius: 7
                    color: Qt.rgba(0.141, 0.157, 0.231, 0.70)
                    border.color: searchField.activeFocus ? root.colBlue : Qt.rgba(0.255, 0.282, 0.408, 0.40)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        spacing: 6

                        Text {
                            text: "🔍"
                            font.pixelSize: 10
                            color: root.colTextSec
                        }

                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            color: root.colTextPri
                            font.pixelSize: 11
                            clip: true
                            onTextChanged: root.searchQuery = text

                            Text {
                                anchors.fill: parent
                                text: i18n("Search virtual machines…")
                                color: Qt.rgba(0.604, 0.647, 0.808, 0.4)
                                font.pixelSize: 11
                                visible: !searchField.text && !searchField.activeFocus
                            }
                        }

                        // Clear search text button
                        Rectangle {
                            visible: !!searchField.text
                            width: 16
                            height: 16
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: root.colTextSec
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchField.text = ""
                            }
                        }
                    }
                }

                // Divider Line
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(0.604, 0.647, 0.808, 0.12)
                }

                // 4. Virtual Machines Scrollable List
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Loading Placeholder
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: root.isLoading && root.allVms.length === 0

                        QQC2.BusyIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            running: true
                        }
                        Text {
                            text: i18n("Scanning VirtualBox machines…")
                            color: root.colTextSec
                            font.pixelSize: 11
                        }
                    }

                    // Empty State
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: !root.isLoading && root.filteredVms.length === 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.searchQuery ? i18n("No matching virtual machines") : i18n("No VirtualBox machines found")
                            color: root.colTextSec
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            visible: !root.searchQuery
                            Layout.alignment: Qt.AlignHCenter
                            height: 28
                            radius: 6
                            color: Qt.rgba(0.478, 0.635, 0.969, 0.2)
                            border.color: root.colBlue
                            border.width: 1
                            implicitWidth: openBtnText.implicitWidth + 16

                            Text {
                                id: openBtnText
                                anchors.centerIn: parent
                                text: i18n("Open VirtualBox Manager")
                                color: root.colBlue
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.requestOpenManager()
                            }
                        }
                    }

                    // VM ListView
                    QQC2.ScrollView {
                        anchors.fill: parent
                        clip: true
                        visible: root.filteredVms.length > 0
                        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                        ListView {
                            id: vmListView
                            anchors.fill: parent
                            spacing: 8
                            model: root.filteredVms

                            delegate: VmCard {
                                width: vmListView.width
                                vmData: modelData
                                defaultMode: root.defaultStartMode

                                onStartRequested: (uuid, mode) => root.requestStartVM(uuid, mode)
                                onPauseRequested: (uuid) => root.requestPauseVM(uuid)
                                onResumeRequested: (uuid) => root.requestResumeVM(uuid)
                                onSaveRequested: (uuid) => root.requestSaveVM(uuid)
                                onShutdownRequested: (uuid) => root.requestShutdownVM(uuid)
                                onConsoleRequested: (uuid) => root.requestConsoleVM(uuid)
                                onFavoriteToggled: (uuid) => root.requestToggleFavorite(uuid)
                            }
                        }
                    }
                }

                // Divider Line
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(0.604, 0.647, 0.808, 0.12)
                }

                // 5. Footer: Manager Launcher & Stats
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: i18np("1 Machine Registered", "%1 Machines Registered", (root.allVms && root.allVms.length) ? root.allVms.length : 0)
                        color: root.colTextSec
                        font.pixelSize: 10
                    }

                    Item { Layout.fillWidth: true }

                    // Open VirtualBox Button
                    Rectangle {
                        height: 24
                        radius: 6
                        color: openVBoxMouse.containsMouse ? Qt.rgba(0.478, 0.635, 0.969, 0.25) : Qt.rgba(0.141, 0.157, 0.231, 0.7)
                        border.color: root.colBorder
                        border.width: 1
                        implicitWidth: openVBoxText.implicitWidth + 14

                        RowLayout {
                            id: openVBoxText
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "📦"; font.pixelSize: 9 }
                            Text {
                                text: i18n("VirtualBox")
                                color: root.colTextPri
                                font.pixelSize: 10
                                font.weight: Font.SemiBold
                            }
                        }

                        MouseArea {
                            id: openVBoxMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.requestOpenManager()
                            QQC2.ToolTip.visible: containsMouse
                            QQC2.ToolTip.text: i18n("Open full VirtualBox Manager application")
                        }
                    }
                }
            }
        }
    }
}
