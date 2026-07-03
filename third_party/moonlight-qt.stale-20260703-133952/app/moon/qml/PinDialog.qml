import QtQuick 2.15
import QtQuick.Controls 2.15

// Pairing PIN display: giant digits the user types into Sunshine on the PC.
Popup {
    id: root

    property string pin: ""
    property string hostName: ""

    function show(name, pinString) {
        hostName = name
        pin = pinString
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width * 0.62 : 900, 1000)
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    padding: Theme.pad * 2

    Overlay.modal: Rectangle { color: "#c00a0d1c" }

    background: Rectangle {
        radius: Theme.radius
        color: Theme.panel
        border.color: Theme.accent
        border.width: 2
    }

    contentItem: Column {
        spacing: Theme.pad

        Text {
            text: qsTr("Pairing with %1").arg(root.hostName)
            color: Theme.text
            font.pixelSize: Theme.fontH2
            font.weight: Font.DemiBold
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: qsTr("Enter this PIN in the Sunshine web UI on your PC\n(https://your-pc:47990 → PIN)")
            color: Theme.textDim
            font.pixelSize: Theme.fontBody
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            spacing: Theme.pad
            anchors.horizontalCenter: parent.horizontalCenter
            Repeater {
                model: root.pin.length
                Rectangle {
                    width: 110; height: 140
                    radius: Theme.radius
                    color: Theme.panelHigh
                    border.color: Theme.accent
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: root.pin.charAt(index)
                        color: Theme.text
                        font.pixelSize: 84
                        font.weight: Font.Bold
                    }
                }
            }
        }

        Row {
            spacing: Theme.padSmall
            anchors.horizontalCenter: parent.horizontalCenter
            MoonSpinner { anchors.verticalCenter: parent.verticalCenter; width: 40; height: 40 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Waiting for the PC to accept…")
                color: Theme.textDim
                font.pixelSize: Theme.fontBody
            }
        }

        FocusButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 260; height: 72
            label: qsTr("Cancel")
            focus: true
            onActivated: root.close()
        }
    }
}
