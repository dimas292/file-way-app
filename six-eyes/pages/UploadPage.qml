import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Application

Page {
    id: root

    property bool connected: false
    property string deviceName: ""
    property string selectedFileName: ""
    property string selectedFileUrl: ""
    property var sessionFiles: JSON.parse(DeviceBackend.sessionFilesJson)
    property string lastUploadedFileName: sessionFiles.length > 0
                                                  ? sessionFiles[sessionFiles.length - 1]
                                                  : ""
    property real uploadProgress: DeviceBackend.progress
    property bool uploadRunning: DeviceBackend.busy && DeviceBackend.status === "Uploading file"
    property bool showUploadResult: false

    title: qsTr("Upload")

    RowLayout {
        anchors.fill: parent
        spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0

                RectangularShadow {
                    anchors.fill: statusCard
                    offset: Qt.vector2d(0, 4)
                    blur: 18
                    radius: statusCard.radius
                    color: "#24000000"
                }

                Rectangle {
                    id: statusCard
                    anchors.fill: parent
                    anchors.margins: 24
                    radius: 14
                    color: "#FFFFFF"
                    border.width: 1
                    border.color: "#E1E5ED"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            // Image {
                            //     Layout.preferredWidth: 28
                            //     Layout.preferredHeight: 28
                            //     source: "qrc:/assets/icons/rfid.png"
                            //     fillMode: Image.PreserveAspectFit
                            // }

                            Label {
                                Layout.fillWidth: true
                                text: root.deviceName.length > 0 ? root.deviceName : qsTr("No device")
                                color: "#171A22"
                                font.pixelSize: 17
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Label {
                                text: root.connected ? qsTr("Connected") : qsTr("Disconnected")
                                color: root.connected ? "#177245" : "#A32D2D"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 92


                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6

                                Label {
                                    Layout.fillWidth: true
                                    text: qsTr("Last uploaded file")
                                    color: "#757B8A"
                                    font.pixelSize: 12
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: root.lastUploadedFileName.length > 0
                                          ? root.lastUploadedFileName
                                          : qsTr("No file uploaded this session")
                                    color: root.lastUploadedFileName.length > 0 ? "#171A22" : "#9A9FAB"
                                    font.pixelSize: 14
                                    font.bold: root.lastUploadedFileName.length > 0
                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Item {
                        Layout.fillHeight: true
                    }

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Transfer to %1").arg(root.deviceName.length > 0 ? root.deviceName : "C72")
                        color: "#171A22"
                        font.pixelSize: 15
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Button {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 140
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Transfer")
                        enabled: root.connected && root.selectedFileUrl.length > 0 && !DeviceBackend.busy
                        onClicked: DeviceBackend.upload(root.selectedFileUrl)
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }


            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0

            Shape {
                id: borderShape
                anchors.fill: parent
                anchors.margins: 24

                property real cornerRadius: 12

                ShapePath {
                    strokeWidth: 2
                    strokeColor: "gray"
                    fillColor: "transparent"
                    strokeStyle: ShapePath.DashLine
                    capStyle: ShapePath.RoundCap
                    dashPattern: [1, 3]

                    startX: borderShape.cornerRadius + 1
                    startY: 1
                    PathLine { x: borderShape.width - borderShape.cornerRadius - 1; y: 1 }
                    PathArc {
                        x: borderShape.width - 1
                        y: borderShape.cornerRadius + 1
                        radiusX: borderShape.cornerRadius
                        radiusY: borderShape.cornerRadius
                    }
                    PathLine { x: borderShape.width - 1; y: borderShape.height - borderShape.cornerRadius - 1 }
                    PathArc {
                        x: borderShape.width - borderShape.cornerRadius - 1
                        y: borderShape.height - 1
                        radiusX: borderShape.cornerRadius
                        radiusY: borderShape.cornerRadius
                    }
                    PathLine { x: borderShape.cornerRadius + 1; y: borderShape.height - 1 }
                    PathArc {
                        x: 1
                        y: borderShape.height - borderShape.cornerRadius - 1
                        radiusX: borderShape.cornerRadius
                        radiusY: borderShape.cornerRadius
                    }
                    PathLine { x: 1; y: borderShape.cornerRadius + 1 }
                    PathArc {
                        x: borderShape.cornerRadius + 1
                        y: 1
                        radiusX: borderShape.cornerRadius
                        radiusY: borderShape.cornerRadius
                    }
                }
            }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 42
                    spacing: 10

                    Item {
                        Layout.fillHeight: true
                    }


                    Label {
                        Layout.fillWidth: true
                        text: root.selectedFileName.length > 0
                              ? root.selectedFileName
                              : qsTr("No file selected")
                        color: root.selectedFileName.length > 0 ? "#333846" : "#757B8A"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                    }

                    ProgressBar {
                        Layout.fillWidth: true
                        visible: root.uploadRunning || root.showUploadResult
                        indeterminate: root.uploadRunning
                        from: 0
                        to: 1
                        value: root.uploadProgress
                    }

                    Button {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 140
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Browse files")
                        enabled: !DeviceBackend.busy
                        onClicked: fileDialog.open()
                    }

                    Label {
                        Layout.fillWidth: true
                        visible: DeviceBackend.error.length > 0 || DeviceBackend.status.length > 0
                        text: DeviceBackend.error.length > 0 ? DeviceBackend.error : DeviceBackend.status
                        color: DeviceBackend.error.length > 0 ? "#A32D2D" : "#5A6070"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
    }

    FileDialog {
        id: fileDialog
        title: qsTr("Select data bank file")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("All files (*)")]

        onAccepted: {
            const fileUrl = selectedFile.toString()
            root.selectedFileUrl = fileUrl
            root.selectedFileName = decodeURIComponent(fileUrl.substring(fileUrl.lastIndexOf("/") + 1))
        }
    }

    Connections {
        target: DeviceBackend

        function onStatusChanged() {
            if (DeviceBackend.status === "Uploading file") {
                root.showUploadResult = false
                uploadResultTimer.stop()
            } else if (DeviceBackend.status.indexOf("Uploaded ") === 0) {
                root.showUploadResult = true
                uploadResultTimer.restart()
            }
        }
    }

    Timer {
        id: uploadResultTimer
        interval: 1500
        onTriggered: root.showUploadResult = false
    }
}
