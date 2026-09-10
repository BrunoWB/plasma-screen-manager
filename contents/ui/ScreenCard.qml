import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

Item {
    id: cardRoot

    property var screenData: ({})
    property bool isFetching: false
    property bool isImposing: false
    property bool isEditingName: false
    property bool resettingDefault: false

    signal requestSetPrimary(string connector)
    signal requestToggleEnabled(string connector, bool currentEnabled)
    signal requestSetAlias(string connector, string alias)
    signal requestClearAlias(string connector)

    implicitWidth: 216
    implicitHeight: 162

    readonly property bool isEnabled: screenData && screenData.enabled !== undefined ? screenData.enabled : true
    readonly property bool isPrimary: screenData && screenData.isPrimary !== undefined ? screenData.isPrimary : false
    readonly property string connector: screenData && screenData.connector ? screenData.connector : ""
    readonly property string displayName: screenData && screenData.name ? screenData.name : connector
    readonly property string defaultName: screenData && screenData.defaultName ? screenData.defaultName : displayName
    readonly property bool isCustomName: screenData && screenData.isCustomName !== undefined ? screenData.isCustomName : false
    readonly property string modeStr: screenData && screenData.mode ? screenData.mode : ""

    function startEditing() {
        if (isFetching) return;
        isEditingName = true;
        nameInput.text = displayName;
        nameInput.forceActiveFocus();
        nameInput.selectAll();
    }

    function commitEdit() {
        if (!isEditingName) return;
        isEditingName = false;
        var trimmed = nameInput.text.trim();
        if (trimmed === "") {
            nameInput.text = defaultName;
            cardRoot.requestClearAlias(connector);
        } else if (trimmed !== displayName) {
            if (trimmed === defaultName) {
                cardRoot.requestClearAlias(connector);
            } else {
                cardRoot.requestSetAlias(connector, trimmed);
            }
        }
    }

    function cancelEdit() {
        if (!isEditingName) return;
        isEditingName = false;
        nameInput.text = displayName;
    }

    function clearToDefault() {
        resettingDefault = true;
        isEditingName = false;
        nameInput.text = defaultName;
        cardRoot.requestClearAlias(connector);
        resettingDefault = false;
    }

    onDisplayNameChanged: {
        if (!isEditingName) {
            nameInput.text = displayName;
        }
    }

    Component.onDestruction: {
        isEditingName = false;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Monitor Display Mockup Frame (16:9 widescreen ratio)
        Rectangle {
            id: monitorBox
            Layout.fillWidth: true
            Layout.preferredHeight: 114
            radius: 10
            color: isEnabled ? (isPrimary ? "#181d26" : "#141820") : "#0e1015"
            border.color: isPrimary ? "#00c8ff" : (isEnabled ? "#2b3345" : "#1b202c")
            border.width: isPrimary ? 2 : 1

            // Smooth opacity transition for imposing state
            opacity: isImposing ? 0.45 : (isEnabled ? 1.0 : 0.6)
            Behavior on opacity {
                NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
            }

            // Subtle glow when primary
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: "#00c8ff"
                border.width: 1
                opacity: isPrimary ? 0.35 : 0.0
                scale: 1.02
                z: -1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                // Top row: Connector tag and Primary tag
                RowLayout {
                    Layout.fillWidth: true

                    // Connector pill
                    Rectangle {
                        color: Qt.rgba(0, 0, 0, 0.45)
                        radius: 4
                        implicitWidth: connText.implicitWidth + 12
                        implicitHeight: connText.implicitHeight + 4

                        Text {
                            id: connText
                            anchors.centerIn: parent
                            text: connector
                            color: "#8899aa"
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.5
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Primary pill badge
                    Rectangle {
                        visible: isPrimary
                        color: Qt.rgba(0, 0.78, 1.0, 0.18)
                        border.color: Qt.rgba(0, 0.8, 1.0, 0.5)
                        border.width: 1
                        radius: 4
                        implicitWidth: primaryText.implicitWidth + 10
                        implicitHeight: primaryText.implicitHeight + 4

                        Text {
                            id: primaryText
                            anchors.centerIn: parent
                            text: "PRIMARY"
                            color: "#00e5ff"
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Centered Device Name Area
                Item {
                    id: nameArea
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22

                    HoverHandler {
                        id: nameAreaHover
                    }

                    // Centered Device Name Label
                    Text {
                        id: nameText
                        visible: !cardRoot.isEditingName
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 44)
                        text: displayName
                        color: isEnabled ? "#ffffff" : "#556677"
                        font.pixelSize: 11
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1

                        MouseArea {
                            id: nameLabelMouse
                            anchors.fill: parent
                            anchors.topMargin: -3
                            anchors.bottomMargin: -3
                            anchors.leftMargin: -6
                            anchors.rightMargin: -6
                            cursorShape: Qt.IBeamCursor
                            hoverEnabled: true
                            enabled: !cardRoot.isEditingName && !isFetching
                            onClicked: cardRoot.startEditing()
                        }
                    }

                    // Inline Name Editor
                    Rectangle {
                        id: editBg
                        visible: cardRoot.isEditingName
                        anchors.centerIn: parent
                        width: Math.min(Math.max(nameInput.implicitWidth + 16, 70), parent.width - 44)
                        height: 20
                        radius: 4
                        color: "#18202c"
                        border.color: "#00c8ff"
                        border.width: 1

                        TextInput {
                            id: nameInput
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            text: displayName
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.bold: true
                            selectByMouse: true
                            clip: true

                            Keys.onReturnPressed: cardRoot.commitEdit()
                            Keys.onEnterPressed: cardRoot.commitEdit()
                            Keys.onEscapePressed: (event) => {
                                cardRoot.cancelEdit();
                                event.accepted = true;
                            }

                            onActiveFocusChanged: {
                                if (!activeFocus && cardRoot.isEditingName && !cardRoot.resettingDefault) {
                                    cardRoot.commitEdit();
                                }
                            }
                        }
                    }

                    // Clear / Reset to default 'X' button
                    Item {
                        id: xBtn
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: cardRoot.isEditingName ? editBg.right : nameText.right
                        anchors.leftMargin: 4
                        z: 10

                        opacity: (nameAreaHover.hovered || nameLabelMouse.containsMouse || clearMouse.containsMouse || cardRoot.isEditingName) ? 1.0 : 0.0
                        visible: opacity > 0
                        Behavior on opacity {
                            NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: clearMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: clearMouse.containsMouse ? "#8899aa" : "transparent"
                            border.width: 1

                            Image {
                                anchors.centerIn: parent
                                source: "assets/clear.svg"
                                sourceSize.width: 9
                                sourceSize.height: 9
                            }
                        }

                        QQC2.ToolTip.visible: clearMouse.containsMouse && !isFetching
                        QQC2.ToolTip.text: "Clear to default (" + cardRoot.defaultName + ")"

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: !isFetching
                            cursorShape: isFetching ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !isFetching
                            onPressed: {
                                cardRoot.resettingDefault = true;
                            }
                            onReleased: {
                                cardRoot.resettingDefault = false;
                            }
                            onCanceled: {
                                cardRoot.resettingDefault = false;
                            }
                            onClicked: {
                                if (!isFetching) {
                                    cardRoot.clearToDefault();
                                }
                            }
                        }
                    }
                }

                // Centered Resolution & Refresh Rate
                Text {
                    Layout.fillWidth: true
                    text: isEnabled && modeStr ? modeStr : (isEnabled ? "Active" : "DISABLED")
                    color: isEnabled ? "#00e5ff" : "#445566"
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.fillHeight: true }
            }

            // Disabled state overlay
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, 0.45)
                visible: !isEnabled
            }
        }

        // Bottom Controls: Star (Primary) & Eye (Toggle Enable/Disable)
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 20

            // Primary Toggle Button (Star)
            Rectangle {
                id: starBtn
                implicitWidth: 32
                implicitHeight: 32
                radius: 16
                color: starMouse.containsMouse && !isFetching ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                enabled: !isFetching && isEnabled

                opacity: isImposing ? 0.45 : (isEnabled ? 1.0 : 0.3)
                Behavior on opacity {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                }

                Image {
                    anchors.centerIn: parent
                    source: isPrimary ? "assets/star-filled.svg" : "assets/star-outline.svg"
                    sourceSize.width: 18
                    sourceSize.height: 18
                }

                QQC2.ToolTip.visible: starMouse.containsMouse && !isFetching
                QQC2.ToolTip.text: isPrimary ? "Primary Display" : "Click to set as Primary Display"

                MouseArea {
                    id: starMouse
                    anchors.fill: parent
                    hoverEnabled: !isFetching
                    cursorShape: isFetching ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (!isPrimary && isEnabled && !isFetching) {
                            cardRoot.requestSetPrimary(connector);
                        }
                    }
                }
            }

            // Enable/Disable Toggle Button (Eye)
            Rectangle {
                id: eyeBtn
                implicitWidth: 32
                implicitHeight: 32
                radius: 16
                color: eyeMouse.containsMouse && !isFetching ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                enabled: !isFetching

                opacity: isImposing ? 0.45 : 1.0
                Behavior on opacity {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                }

                Image {
                    anchors.centerIn: parent
                    source: isEnabled ? "assets/eye.svg" : "assets/eye-off.svg"
                    sourceSize.width: 20
                    sourceSize.height: 20
                }

                QQC2.ToolTip.visible: eyeMouse.containsMouse && !isFetching
                QQC2.ToolTip.text: isEnabled ? "Display is Enabled (Click to turn off)" : "Display is Disabled (Click to turn on)"

                MouseArea {
                    id: eyeMouse
                    anchors.fill: parent
                    hoverEnabled: !isFetching
                    cursorShape: isFetching ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (!isFetching) {
                            cardRoot.requestToggleEnabled(connector, isEnabled);
                        }
                    }
                }
            }
        }
    }
}
