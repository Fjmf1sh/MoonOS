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
            // A single-letter hint (A/B/X/Y) is a controller face button, drawn
            // as a lettered chip. Anything longer is a Material Icons ligature
            // name (e.g. "gamepad", "swap_horiz") and is drawn as an icon.
            readonly property bool isFaceButton: String(modelData.button).length === 1
            Rectangle {
                width: 40; height: 40; radius: 20
                color: Theme.panelHigh
                border.color: Theme.textDim
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    visible: parent.parent.isFaceButton
                    anchors.centerIn: parent
                    text: modelData.button
                    color: Theme.text
                    font.pixelSize: Theme.fontSmall
                    font.weight: Font.Bold
                }
                MIcon {
                    visible: !parent.parent.isFaceButton
                    anchors.centerIn: parent
                    name: modelData.button
                    size: Theme.fontBody
                    color: Theme.text
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
