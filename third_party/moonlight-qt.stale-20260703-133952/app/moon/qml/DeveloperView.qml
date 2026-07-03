import QtQuick 2.15
import QtQuick.Controls 2.15

import MoonOS 1.0

// Raw shell logs — only reachable when developer mode is on.
FocusScope {
    id: page

    Column {
        anchors.fill: parent
        anchors.margins: Theme.screenMargin
        spacing: Theme.pad

        Row {
            spacing: Theme.pad
            Text {
                text: qsTr("Logs")
                color: Theme.text
                font.pixelSize: Theme.fontTitle
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            FocusButton {
                width: 220; height: 70
                label: qsTr("Refresh")
                anchors.verticalCenter: parent.verticalCenter
                onActivated: logText.text = MoonSystem.shellLog(400)
            }
        }

        Rectangle {
            width: parent.width
            height: parent.height - y
            radius: Theme.radiusSmall
            color: "#05070f"
            border.color: Theme.panelHigh
            border.width: 1

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: Theme.padSmall
                contentHeight: logText.height
                clip: true
                focus: true

                Keys.onUpPressed: contentY = Math.max(0, contentY - 120)
                Keys.onDownPressed: contentY = Math.min(Math.max(0, contentHeight - height), contentY + 120)

                Text {
                    id: logText
                    width: flick.width
                    text: MoonSystem.shellLog(400)
                    color: "#9fe8a0"
                    font.family: "monospace"
                    font.pixelSize: 16
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }

    HintBar {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.pad
        anchors.horizontalCenter: parent.horizontalCenter
        hints: [
            { button: "☰", label: qsTr("Scroll") },
            { button: "B", label: qsTr("Back") }
        ]
    }
}
