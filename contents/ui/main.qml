import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    implicitWidth: Math.max(490, (displayList.length * 224) + 36)
    implicitHeight: 240

    readonly property string scriptPath: Qt.resolvedUrl("../scripts/screen_ctl.py").toString().replace("file://", "")
    readonly property bool autoRefreshOnHover: Plasmoid.configuration.autoRefreshOnHover !== undefined ? Plasmoid.configuration.autoRefreshOnHover : true

    property var displayList: []
    property bool presentationActive: false
    
    // Fetch Modes: "none", "shy" (silent background), "imposing" (dimmed + spinning + banner)
    property string fetchMode: "none"
    readonly property bool isFetching: fetchMode !== "none"
    readonly property bool isImposing: fetchMode === "imposing"
    
    property double lastFetchTime: 0
    property string statusMessage: ""

    Timer {
        id: messageTimer
        interval: 3200
        onTriggered: root.statusMessage = ""
    }

    function showNotice(msg) {
        root.statusMessage = msg;
        messageTimer.restart();
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        interval: 0
        connectedSources: []

        onNewData: (sourceName, data) => {
            var stdout = data["stdout"] || "";
            disconnectSource(sourceName);
            root.fetchMode = "none";

            if (!stdout || stdout.trim().length === 0) {
                return;
            }

            try {
                var res = JSON.parse(stdout);
                if (res.screens !== undefined) {
                    root.displayList = res.screens;
                }
                if (res.presentationMode !== undefined) {
                    root.presentationActive = res.presentationMode;
                }
                if (res.error) {
                    root.showNotice(res.error);
                }
                root.lastFetchTime = Date.now();
            } catch (err) {
                console.error("Failed to parse JSON response:", err, stdout);
            }
        }
    }

    function runCommand(args, mode) {
        root.fetchMode = mode || "imposing";
        var cmd = "python3 \"" + root.scriptPath + "\" " + args + " # " + Date.now();
        executable.connectSource(cmd);
    }

    function fetchStatus(mode) {
        var reqMode = mode || "imposing";
        var now = Date.now();
        
        // Prevent rapid consequent fetches: if last fetch was less than 5 seconds ago, ignore
        if (now - root.lastFetchTime < 5000) {
            return;
        }
        
        runCommand("status", reqMode);
    }

    function setPrimaryScreen(connector) {
        runCommand("set-primary " + connector, "imposing");
    }

    function toggleScreenEnabled(connector, currentEnabled) {
        var activeCount = 0;
        for (var i = 0; i < root.displayList.length; i++) {
            if (root.displayList[i].enabled) {
                activeCount++;
            }
        }
        if (currentEnabled && activeCount <= 1) {
            root.showNotice("Cannot disable the only active screen.");
            return;
        }
        var nextState = currentEnabled ? "0" : "1";
        runCommand("set-enabled " + connector + " " + nextState, "imposing");
    }

    function togglePresentation() {
        runCommand("toggle-presentation", "imposing");
    }

    Component.onCompleted: {
        // Initial load: fetch immediately
        runCommand("status", "shy");
    }

    // Periodic Background Sync: 30-second interval with SHY state (no dimming, no spinner, unclickable for 75ms)
    Timer {
        id: periodicTimer
        interval: 30000 // 30 seconds
        running: true
        repeat: true
        onTriggered: {
            if (!root.isFetching) {
                root.fetchStatus("shy");
            }
        }
    }

    // Compact Representation (Taskbar / Panel)
    compactRepresentation: Item {
        Image {
            anchors.centerIn: parent
            source: root.presentationActive ? "assets/presentation-active.svg" : "assets/monitor.svg"
            sourceSize.width: 18
            sourceSize.height: 18
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    // Full Representation (Desktop Widget)
    fullRepresentation: Item {
        id: fullRepItem
        anchors.fill: parent

        // Main Card
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#101319"
            border.color: "#232836"
            border.width: 1
        }

        // Hover detection: Auto-refresh with IMPOSING state when mouse enters widget on desktop
        HoverHandler {
            id: mainHover
            enabled: root.autoRefreshOnHover
            onHoveredChanged: {
                if (hovered && !root.isFetching) {
                    root.fetchStatus("imposing");
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Top Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Header Icon
                Image {
                    source: "assets/monitor.svg"
                    sourceSize.width: 17
                    sourceSize.height: 17
                }

                // Title
                Text {
                    text: "Screen Manager"
                    color: "#f0f4f8"
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 0.2
                }

                // Status Pill: only shows on IMPOSING state or on error notice (never on shy)
                Rectangle {
                    visible: root.isImposing || root.statusMessage.length > 0
                    radius: 8
                    color: root.statusMessage.length > 0 ? Qt.rgba(1.0, 0.2, 0.3, 0.15) : Qt.rgba(0, 0.8, 1.0, 0.14)
                    border.color: root.statusMessage.length > 0 ? "#ff5555" : Qt.rgba(0, 0.8, 1.0, 0.35)
                    border.width: 1
                    implicitWidth: statusText.implicitWidth + 14
                    implicitHeight: 20

                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            visible: root.isImposing && root.statusMessage.length === 0
                            width: 6
                            height: 6
                            radius: 3
                            color: "#00e5ff"
                        }

                        Text {
                            id: statusText
                            text: root.statusMessage.length > 0 ? root.statusMessage : "Fetching recent data..."
                            color: root.statusMessage.length > 0 ? "#ff7777" : "#00e5ff"
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Presentation Mode Toggle Button
                Rectangle {
                    id: presBtn
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: 7
                    color: root.presentationActive ? Qt.rgba(0, 0.78, 1.0, 0.22) : (presMouse.containsMouse && !root.isFetching ? "#1e2430" : "#161a22")
                    border.color: root.presentationActive ? "#00c8ff" : (presMouse.containsMouse && !root.isFetching ? "#3b4458" : "#2a3040")
                    border.width: 1
                    enabled: !root.isFetching

                    opacity: root.isImposing ? 0.45 : 1.0
                    Behavior on opacity {
                        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                    }

                    Image {
                        anchors.centerIn: parent
                        source: root.presentationActive ? "assets/presentation-active.svg" : "assets/presentation.svg"
                        sourceSize.width: 16
                        sourceSize.height: 16
                    }

                    QQC2.ToolTip.visible: presMouse.containsMouse && !root.isFetching
                    QQC2.ToolTip.text: root.presentationActive ? "Presentation Mode: Active (Sleep blocked)\nClick to turn off" : "Presentation Mode: Inactive\nClick to keep screens awake"

                    MouseArea {
                        id: presMouse
                        anchors.fill: parent
                        hoverEnabled: !root.isFetching
                        cursorShape: root.isFetching ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!root.isFetching) {
                                root.togglePresentation();
                            }
                        }
                    }
                }

                // Refresh Button
                Rectangle {
                    id: refreshBtn
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: 7
                    color: refMouse.containsMouse && !root.isFetching ? "#1e2430" : "#161a22"
                    border.color: refMouse.containsMouse && !root.isFetching ? "#3b4458" : "#2a3040"
                    border.width: 1
                    enabled: !root.isFetching

                    opacity: root.isImposing ? 0.45 : 1.0
                    Behavior on opacity {
                        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                    }

                    Image {
                        id: refreshImg
                        anchors.centerIn: parent
                        source: "assets/refresh.svg"
                        sourceSize.width: 15
                        sourceSize.height: 15

                        // Only spin when imposing (manual click or hover), NOT on shy background poll
                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 700
                            loops: Animation.Infinite
                            running: root.isImposing
                        }
                    }

                    QQC2.ToolTip.visible: refMouse.containsMouse && !root.isFetching
                    QQC2.ToolTip.text: "Refresh Displays"

                    MouseArea {
                        id: refMouse
                        anchors.fill: parent
                        hoverEnabled: !root.isFetching
                        cursorShape: root.isFetching ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!root.isFetching) {
                                root.fetchStatus("imposing");
                            }
                        }
                    }
                }
            }

            // Separator Line
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#232836"
                opacity: 0.6
            }

            // Main Displays Container
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Displays Side by Side Row
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 14
                    visible: root.displayList.length > 0

                    Repeater {
                        model: root.displayList

                        ScreenCard {
                            screenData: modelData
                            isFetching: root.isFetching
                            isImposing: root.isImposing
                            onRequestSetPrimary: (connector) => root.setPrimaryScreen(connector)
                            onRequestToggleEnabled: (connector, currentEnabled) => root.toggleScreenEnabled(connector, currentEnabled)
                        }
                    }
                }

                // Empty / Loading state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.displayList.length === 0
                    spacing: 6

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        source: "assets/monitor.svg"
                        sourceSize.width: 32
                        sourceSize.height: 32
                        opacity: 0.5
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.isFetching ? "Detecting displays..." : "No connected displays found"
                        color: "#667788"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
