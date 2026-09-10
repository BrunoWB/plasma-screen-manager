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
    readonly property int pollIntervalSeconds: Plasmoid.configuration.pollInterval ? Plasmoid.configuration.pollInterval : 20

    property var displayList: []
    property bool presentationActive: false
    property bool isFetching: false
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
            root.isFetching = false;

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

    function runCommand(args) {
        root.isFetching = true;
        var cmd = "python3 \"" + root.scriptPath + "\" " + args + " # " + Date.now();
        executable.connectSource(cmd);
    }

    function fetchStatus(force) {
        var now = Date.now();
        if (!force && (now - root.lastFetchTime < 4000)) {
            return;
        }
        runCommand("status");
    }

    function setPrimaryScreen(connector) {
        runCommand("set-primary " + connector);
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
        runCommand("set-enabled " + connector + " " + nextState);
    }

    function togglePresentation() {
        runCommand("toggle-presentation");
    }

    Component.onCompleted: {
        fetchStatus(true);
    }

    Timer {
        id: periodicTimer
        interval: Math.max(5000, root.pollIntervalSeconds * 1000)
        running: true
        repeat: true
        onTriggered: root.fetchStatus(false)
    }

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

    fullRepresentation: Item {
        id: fullRepItem
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#101319"
            border.color: "#232836"
            border.width: 1
        }

        HoverHandler {
            id: mainHover
            enabled: root.autoRefreshOnHover
            onHoveredChanged: {
                if (hovered) {
                    root.fetchStatus(false);
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Image {
                    source: "assets/monitor.svg"
                    sourceSize.width: 17
                    sourceSize.height: 17
                }

                Text {
                    text: "Screen Manager"
                    color: "#f0f4f8"
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 0.2
                }

                Rectangle {
                    visible: root.isFetching || root.statusMessage.length > 0
                    radius: 8
                    color: root.statusMessage.length > 0 ? Qt.rgba(1.0, 0.2, 0.3, 0.15) : Qt.rgba(0, 0.8, 1.0, 0.14)
                    border.color: root.statusMessage.length > 0 ? "#ff5555" : Qt.rgba(0, 0.8, 1.0, 0.35)
                    border.width: 1
                    implicitWidth: statusText.implicitWidth + 14
                    implicitHeight: 20

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            visible: root.isFetching && root.statusMessage.length === 0
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

                Rectangle {
                    id: presBtn
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: 7
                    color: root.presentationActive ? Qt.rgba(0, 0.78, 1.0, 0.22) : (presMouse.containsMouse ? "#1e2430" : "#161a22")
                    border.color: root.presentationActive ? "#00c8ff" : (presMouse.containsMouse ? "#3b4458" : "#2a3040")
                    border.width: 1
                    enabled: !root.isFetching
                    opacity: enabled ? 1.0 : 0.5

                    Image {
                        anchors.centerIn: parent
                        source: root.presentationActive ? "assets/presentation-active.svg" : "assets/presentation.svg"
                        sourceSize.width: 16
                        sourceSize.height: 16
                    }

                    QQC2.ToolTip.visible: presMouse.containsMouse
                    QQC2.ToolTip.text: root.presentationActive ? "Presentation Mode: Active (Sleep blocked)\nClick to turn off" : "Presentation Mode: Inactive\nClick to keep screens awake"

                    MouseArea {
                        id: presMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePresentation()
                    }
                }

                Rectangle {
                    id: refreshBtn
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: 7
                    color: refMouse.containsMouse ? "#1e2430" : "#161a22"
                    border.color: refMouse.containsMouse ? "#3b4458" : "#2a3040"
                    border.width: 1
                    enabled: !root.isFetching

                    Image {
                        id: refreshImg
                        anchors.centerIn: parent
                        source: "assets/refresh.svg"
                        sourceSize.width: 15
                        sourceSize.height: 15

                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 700
                            loops: Animation.Infinite
                            running: root.isFetching
                        }
                    }

                    QQC2.ToolTip.visible: refMouse.containsMouse
                    QQC2.ToolTip.text: "Refresh Displays"

                    MouseArea {
                        id: refMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.fetchStatus(true)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#232836"
                opacity: 0.6
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 14
                    visible: root.displayList.length > 0

                    Repeater {
                        model: root.displayList

                        ScreenCard {
                            screenData: modelData
                            isFetching: root.isFetching
                            onRequestSetPrimary: (connector) => root.setPrimaryScreen(connector)
                            onRequestToggleEnabled: (connector, currentEnabled) => root.toggleScreenEnabled(connector, currentEnabled)
                        }
                    }
                }

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
