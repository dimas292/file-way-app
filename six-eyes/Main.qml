import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import pages
import Application

ApplicationWindow {
    id: win

    property bool deviceConnected: DeviceBackend.connected
    property string deviceName: DeviceBackend.deviceName

    visible: true
    title: "six-eyes"
    width: 860
    height: 520
    minimumWidth: 520
    minimumHeight: 380
    color: "#eeeeee"

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: win.deviceConnected ? workspaceComponent : alertComponent
        }
    }

    Component {
        id: alertComponent

        AlertConnection {
            connected: win.deviceConnected
        }
    }

    Component {
        id: workspaceComponent

        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 14

                Label {
                    Layout.fillWidth: true
                    text: qsTr("Data Import Wizard")
                    color: "#171A22"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                TabBar {
                    id: pageTabs
                    Layout.fillWidth: true
                    currentIndex: 0
                    spacing: 4
                    padding: 4

                    TabButton {
                        id: uploadTab
                        text: qsTr("Upload")

                        contentItem: Text {
                            text: uploadTab.text
                            color: uploadTab.checked ? "#FFFFFF" : "#333333"
                            font: uploadTab.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: uploadTab.checked ? "#3A86FF" : "#eeeeee"
                            border.width: 1
                            border.color: uploadTab.checked ? "#2F6FD1" : "#C8CDD6"
                            radius: 4
                        }
                    }

                    TabButton {
                        id: downloadTab
                        text: qsTr("Download Report")

                        contentItem: Text {
                            text: downloadTab.text
                            color: downloadTab.checked ? "#FFFFFF" : "#333333"
                            font: downloadTab.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: downloadTab.checked ? "#3A86FF" : "#eeeeee"
                            border.width: 1
                            border.color: downloadTab.checked ? "#2F6FD1" : "#C8CDD6"
                            radius: 4
                        }
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: pageTabs.currentIndex

                    UploadPage {
                        connected: win.deviceConnected
                        deviceName: win.deviceName
                    }

                    DownloadReportPage {
                        connected: win.deviceConnected
                        deviceName: win.deviceName
                    }
                }
            }
        }
    }
}
