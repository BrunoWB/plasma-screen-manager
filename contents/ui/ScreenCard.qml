import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

Item {
    id: cardRoot

    property var screenData: ({})
    property bool isFetching: false

    signal requestSetPrimary(string connector)
    signal requestToggleEnabled(string connector, bool currentEnabled)

    implicitWidth: 216
    implicitHeight: 162

    readonly property bool isEnabled: screenData && screenData.enabled !== undefined ? screenData.enabled : true
    readonly property bool isPrimary: screenData && screenData.isPrimary !== undefined ? screenData.isPrimary : false
    readonly property string connector: screenData && screenData.connector ? screenData.connector : ""
    readonly property string displayName: screenData && screenData.name ? screenData.name : connector
    readonly property string modeStr: screenData && screenData.mode ? screenData.mode : ""

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

                // Centered Device Name
                Text {
                    id: nameText
                    Layout.fillWidth: true
                    text: displayName.toUpperCase()
                    color: isEnabled ? "#ffffff" : "#556677"
                    font.pixelSize: 11
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
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
                color: starMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                opacity: isFetching ? 0.4 : (isEnabled ? 1.0 : 0.3)
                enabled: !isFetching && isEnabled

                Image {
                    anchors.centerIn: parent
                    source: isPrimary ? "assets/star-filled.svg" : "assets/star-outline.svg"
                    sourceSize.width: 18
                    sourceSize.height: 18
                }

                QQC2.ToolTip.visible: starMouse.containsMouse
                QQC2.ToolTip.text: isPrimary ? "Primary Display" : "Click to set as Primary Display"

                MouseArea {
                    id: starMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!isPrimary && isEnabled) {
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
                color: eyeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                opacity: isFetching ? 0.4 : 1.0
                enabled: !isFetching

                Image {
                    anchors.centerIn: parent
                    source: isEnabled ? "assets/eye.svg" : "assets/eye-off.svg"
                    sourceSize.width: 20
                    sourceSize.height: 20
                }

                QQC2.ToolTip.visible: eyeMouse.containsMouse
                QQC2.ToolTip.text: isEnabled ? "Display is Enabled (Click to turn off)" : "Display is Disabled (Click to turn on)"

                MouseArea {
                    id: eyeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        cardRoot.requestToggleEnabled(connector, isEnabled);
                    }
                }
            }
        }
    }
}
