import QtQuick
import QtQuick.Effects
import QtQuick.Controls

Page {
    id: root

    property bool connected: false
    property string deviceName: ""

    title: qsTr("USB Connection")

    background: Rectangle {
        color: "#F6F7FB"
    }

    Rectangle {
        width: Math.min(parent.width - 48, 520)
        height: 290
        anchors.centerIn: parent
        color: "#FFFFFF"
        border.color: "#E2E5ED"
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#80000000"
            shadowBlur: 0.8
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
        }

        Image {
            id: usbIcon
            source: "qrc:/assets/icons/usb.png"
            width: 64
            height: 64
            fillMode: Image.PreserveAspectFit
            anchors.top: parent.top
            anchors.topMargin: 36
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Label {
            id: heading
            anchors.top: usbIcon.bottom
            anchors.topMargin: 22
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.deviceName.length > 0
                  ? qsTr("Connecting to %1").arg(root.deviceName)
                  : qsTr("Connect your C72 device")
            color: "#171A22"
            font.pixelSize: 22
            font.bold: true
        }
    }
}
