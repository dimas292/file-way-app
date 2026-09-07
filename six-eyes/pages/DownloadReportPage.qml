import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Application

Page {
    id: root

    property bool connected: false
    property string deviceName: ""
    property var dataBankFiles: JSON.parse(DeviceBackend.filesJson)
    property string selectedFileName: fileSelector.currentIndex >= 0 && fileSelector.currentIndex < dataBankFiles.length ? dataBankFiles[fileSelector.currentIndex] : ""

    title: qsTr("Download Report")

    background: Rectangle {
        color: "#eeeeee"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        Label {
            Layout.fillWidth: true
            text: qsTr("Download from device")
            color: "#171A22"
            font.pixelSize: 22
            font.bold: true
        }

        Label {
            Layout.fillWidth: true
            text: qsTr("Select a file from %1 data bank, or download all files at once.").arg(root.deviceName.length > 0 ? root.deviceName : qsTr("the device"))
            color: "#5A6070"
            font.pixelSize: 15
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 112
            color: "#F8F9FC"
            border.color: "#E2E5ED"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label {
                        text: qsTr("Data bank file")
                        color: "#5A6070"
                    }

                    ComboBox {
                        id: fileSelector
                        Layout.fillWidth: true
                        model: root.dataBankFiles
                        enabled: root.connected && !DeviceBackend.busy && count > 0
                        displayText: count > 0 && currentIndex >= 0 ? currentText : qsTr("No files found")
                    }
                }

                Button {
                    text: qsTr("Refresh")
                    enabled: root.connected && !DeviceBackend.busy
                    onClicked: DeviceBackend.refreshDirectory()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                Layout.fillWidth: true
                text: DeviceBackend.error.length > 0 ? DeviceBackend.error : DeviceBackend.status
                color: DeviceBackend.error.length > 0 ? "#A32D2D" : "#5A6070"
                wrapMode: Text.WordWrap
            }

            BusyIndicator {
                running: DeviceBackend.busy
                visible: running
            }

            Button {
                Layout.preferredWidth: 120
                text: qsTr("Download")
                palette.button: "#3A86FF"
                palette.buttonText: '#0f0e0e'
                enabled: root.connected && root.selectedFileName.length > 0 && !DeviceBackend.busy
                onClicked: saveDialog.open()
            }

            Button {
                Layout.preferredWidth: 120
                text: qsTr("Download all")
                palette.button: "#3A86FF"
                palette.buttonText: '#0f0e0e'
                enabled: root.connected && root.dataBankFiles.length > 0 && !DeviceBackend.busy
                onClicked: downloadAllDialog.open()
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    FileDialog {
        id: saveDialog
        title: qsTr("Save %1").arg(root.selectedFileName)
        fileMode: FileDialog.SaveFile
        onAccepted: DeviceBackend.download(root.selectedFileName, selectedFile.toString())
    }

    FolderDialog {
        id: downloadAllDialog
        title: qsTr("Choose destination folder")
        onAccepted: DeviceBackend.downloadAll(selectedFolder.toString())
    }
}
