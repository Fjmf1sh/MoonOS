import QtQuick 2.15

// Controller button hints pinned to the bottom of every screen.
// hints: [{ button: "A", label: "Select" }, ...]
Row {
    id: root
    property var hints: [
        { button: "A", label: qsTr("Select") },
        { button: "B", label: qsTr("Back") }
    ]

    spacing: Theme.pad * 1.5

    Repeater {
        model: root.hints
        Row {
            spacing: 10
            Rectangle {
                width: 40; height: 40; radius: 20
                color: Theme.panelHigh
                border.color: Theme.textDim
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: modelData.button
                    color: Theme.text
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.Bold
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: Theme.textDim
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
