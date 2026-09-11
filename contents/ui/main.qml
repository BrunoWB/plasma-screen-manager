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
    property bool isEditingName: false
    
    // Expected state synchronization
    property var pendingSync: null
    readonly property bool isSyncing: pendingSync !== null

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

    property double fetchStartTime: 0
    property int minFetchDuration: 0

    Timer {
        id: minDurationTimer
        repeat: false
        onTriggered: {
            root.fetchMode = "none";
            root.lastFetchTime = Date.now();
        }
    }

    // Intensified polling timer during state transitions (400ms interval)
    Timer {
        id: syncPollTimer
        interval: 400
        repeat: true
        running: root.isSyncing
        onTriggered: {
            if (executable.connectedSources.length === 0) {
                var cmd = "python3 \"" + root.scriptPath + "\" status # sync_" + Date.now();
                executable.connectSource(cmd);
            }
        }
    }

    // Timeout guard for state synchronization (5 seconds)
    Timer {
        id: syncTimeoutTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (root.pendingSync) {
                console.warn("Display state sync timed out after 5s for connector:", root.pendingSync.connector);
                root.showNotice("Display sync timed out (5s)");
                root.pendingSync = null;
                root.runCommand("status", "shy", 0);
            }
        }
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        interval: 0
        connectedSources: []

        onNewData: (sourceName, data) => {
            var stdout = data["stdout"] || "";
            disconnectSource(sourceName);

            if (stdout && stdout.trim().length > 0) {
                try {
                    var res = JSON.parse(stdout);
                    if (res.presentationMode !== undefined) {
                        root.presentationActive = res.presentationMode;
                    }
                    if (res.error) {
                        root.showNotice(res.error);
                        if (root.pendingSync) {
                            root.pendingSync = null;
                            syncTimeoutTimer.stop();
                        }
                    }
                    if (res.screens !== undefined) {
                        if (root.pendingSync) {
                            var matched = false;
                            var targetScreen = null;
                            for (var i = 0; i < res.screens.length; i++) {
                                if (res.screens[i].connector === root.pendingSync.connector) {
                                    targetScreen = res.screens[i];
                                    break;
                                }
                            }

                            if (root.pendingSync.action === "enable") {
                                matched = (targetScreen !== null && targetScreen.enabled === true);
                            } else if (root.pendingSync.action === "disable") {
                                matched = (targetScreen === null || targetScreen.enabled === false);
                            } else if (root.pendingSync.action === "primary") {
                                matched = (targetScreen !== null && targetScreen.isPrimary === true);
                            }

                            if (matched) {
                                root.pendingSync = null;
                                syncTimeoutTimer.stop();
                                root.displayList = res.screens;
                                root.lastFetchTime = Date.now();
                            }
                        } else {
                            root.displayList = res.screens;
                        }
                    }
                } catch (err) {
                    console.error("Failed to parse JSON response:", err, stdout);
                }
            }

            var isSyncPoll = sourceName.indexOf("# sync_") !== -1;
            if (!isSyncPoll) {
                var elapsed = Date.now() - root.fetchStartTime;
                if (root.minFetchDuration > 0 && elapsed < root.minFetchDuration) {
                    minDurationTimer.interval = root.minFetchDuration - elapsed;
                    minDurationTimer.start();
                } else {
                    root.fetchMode = "none";
                    root.lastFetchTime = Date.now();
                }
            }
        }
    }

    function runCommand(args, mode, minDuration) {
        root.fetchMode = mode || "imposing";
        root.fetchStartTime = Date.now();
        root.minFetchDuration = minDuration || 0;
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
        
        runCommand("status", reqMode, 0);
    }

    function forceManualRefresh() {
        if (!root.isFetching && !root.isSyncing) {
            runCommand("status", "imposing", 500);
        }
    }

    function setPrimaryScreen(connector) {
        if (root.isSyncing) return;
        root.pendingSync = {
            connector: connector,
            action: "primary",
            expectedPrimary: true,
            expectedEnabled: true,
            startTime: Date.now()
        };
        syncTimeoutTimer.restart();
        runCommand("set-primary " + connector, "shy");
    }

    function toggleScreenEnabled(connector, currentEnabled) {
        if (root.isSyncing) return;
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
        var willEnable = (nextState === "1");
        root.pendingSync = {
            connector: connector,
            action: willEnable ? "enable" : "disable",
            expectedEnabled: willEnable,
            startTime: Date.now()
        };
        syncTimeoutTimer.restart();
        runCommand("set-enabled " + connector + " " + nextState, "shy");
    }

    function setScreenAlias(connector, alias) {
        var safeAlias = alias.replace(/'/g, "'\\''");
        runCommand("set-alias " + connector + " '" + safeAlias + "'", "imposing");
    }

    function clearScreenAlias(connector) {
        runCommand("clear-alias " + connector, "imposing");
    }

    function togglePresentation() {
        runCommand("toggle-presentation", "imposing");
    }

    Component.onCompleted: {
        // Initial load: fetch immediately
        runCommand("status", "shy");
    }

    // Periodic Background Sync: 30-second interval with SHY state (no dimming, no spinner, unclickable for 75ms)
    // Pauses when user is actively editing a screen name or sync is in progress
    Timer {
        id: periodicTimer
        interval: 30000 // 30 seconds
        running: !root.isEditingName && !root.isSyncing
        repeat: true
        onTriggered: {
            if (!root.isFetching && !root.isEditingName && !root.isSyncing) {
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
        focus: true

        readonly property bool isWindowedApp: Qt.application.name === "plasmawindowed"
        property bool windowWasActive: false

        // Setup frameless overlay styling when launched via plasmawindowed
        Component.onCompleted: {
            if (isWindowedApp && Window.window) {
                Window.window.flags = Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint;
                Window.window.color = "transparent";
            }
        }

        // Auto-close on click-away (loss of active window focus)
        Timer {
            id: focusLossTimer
            interval: 120
            repeat: false
            onTriggered: {
                if (fullRepItem.isWindowedApp && fullRepItem.windowWasActive && (!fullRepItem.Window || !fullRepItem.Window.active) && !root.isEditingName) {
                    if (root.expanded) {
                        root.expanded = false;
                    }
                    executable.connectSource("pkill -f 'plasmawindowed.*org\\.scyan\\.screenmanager'");
                }
            }
        }

        Window.onActiveChanged: {
            if (!isWindowedApp) return;
            if (Window.active) {
                fullRepItem.windowWasActive = true;
                focusLossTimer.stop();
            } else if (fullRepItem.windowWasActive) {
                focusLossTimer.restart();
            }
        }

        Keys.onEscapePressed: (event) => {
            if (!root.isEditingName) {
                if (root.expanded) {
                    root.expanded = false;
                }
                executable.connectSource("pkill -f 'plasmawindowed.*org\\.scyan\\.screenmanager'");
                event.accepted = true;
            }
        }

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
            enabled: root.autoRefreshOnHover && !root.isEditingName && !root.isSyncing
            onHoveredChanged: {
                if (hovered && !root.isFetching && !root.isEditingName && !root.isSyncing) {
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

                // Notice Pill: only shows on warning/error message
                Rectangle {
                    visible: root.statusMessage.length > 0
                    radius: 8
                    color: Qt.rgba(1.0, 0.2, 0.3, 0.15)
                    border.color: "#ff5555"
                    border.width: 1
                    implicitWidth: statusText.implicitWidth + 14
                    implicitHeight: 20

                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                    }

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: root.statusMessage
                        color: "#ff7777"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }

                Item { Layout.fillWidth: true }

                // Presentation Mode Toggle Button
                Rectangle {
                    id: presBtn
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: 7
                    color: root.presentationActive ? Qt.rgba(0, 0.78, 1.0, 0.22) : (presMouse.containsMouse && !root.isFetching && !root.isSyncing ? "#1e2430" : "#161a22")
                    border.color: root.presentationActive ? "#00c8ff" : (presMouse.containsMouse && !root.isFetching && !root.isSyncing ? "#3b4458" : "#2a3040")
                    border.width: 1
                    enabled: !root.isFetching && !root.isSyncing

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

                    QQC2.ToolTip.visible: presMouse.containsMouse && !root.isFetching && !root.isSyncing
                    QQC2.ToolTip.text: root.presentationActive ? "Presentation Mode: Active (Sleep blocked)\nClick to turn off" : "Presentation Mode: Inactive\nClick to keep screens awake"

                    MouseArea {
                        id: presMouse
                        anchors.fill: parent
                        hoverEnabled: !root.isFetching && !root.isSyncing
                        cursorShape: (root.isFetching || root.isSyncing) ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!root.isFetching && !root.isSyncing) {
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
                    color: refMouse.containsMouse && !root.isFetching && !root.isSyncing ? "#1e2430" : "#161a22"
                    border.color: refMouse.containsMouse && !root.isFetching && !root.isSyncing ? "#3b4458" : "#2a3040"
                    border.width: 1
                    enabled: !root.isFetching && !root.isSyncing

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

                        // Spins during any fetch or state synchronization
                        RotationAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 700
                            loops: Animation.Infinite
                            running: root.isFetching || root.isSyncing
                        }
                    }

                    QQC2.ToolTip.visible: refMouse.containsMouse && !root.isFetching && !root.isSyncing
                    QQC2.ToolTip.text: root.isSyncing ? "Synchronizing displays..." : "Refresh Displays"

                    MouseArea {
                        id: refMouse
                        anchors.fill: parent
                        hoverEnabled: !root.isFetching && !root.isSyncing
                        cursorShape: (root.isFetching || root.isSyncing) ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (!root.isFetching && !root.isSyncing) {
                                root.forceManualRefresh();
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
                        id: cardsRepeater
                        model: root.displayList

                        ScreenCard {
                            screenData: modelData
                            isFetching: root.isFetching
                            isImposing: root.isImposing
                            isSyncing: root.pendingSync !== null && root.pendingSync.connector === modelData.connector
                            anySyncing: root.isSyncing
                            syncAction: root.pendingSync ? root.pendingSync.action : ""
                            expectedEnabled: (root.pendingSync && root.pendingSync.connector === modelData.connector) ? root.pendingSync.expectedEnabled : undefined
                            expectedPrimary: (root.pendingSync && root.pendingSync.connector === modelData.connector) ? root.pendingSync.expectedPrimary : undefined
                            onRequestSetPrimary: (connector) => root.setPrimaryScreen(connector)
                            onRequestToggleEnabled: (connector, currentEnabled) => root.toggleScreenEnabled(connector, currentEnabled)
                            onRequestSetAlias: (connector, alias) => root.setScreenAlias(connector, alias)
                            onRequestClearAlias: (connector) => root.clearScreenAlias(connector)
                            onIsEditingNameChanged: {
                                var anyEditing = false;
                                for (var i = 0; i < cardsRepeater.count; i++) {
                                    var card = cardsRepeater.itemAt(i);
                                    if (card && card.isEditingName) {
                                        anyEditing = true;
                                        break;
                                    }
                                }
                                root.isEditingName = anyEditing;
                            }
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
