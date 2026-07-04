import QtQuick 2.15
import QtQml.Models 2.15

// Standard settings screen: big title, description, and a focusable list of
// setting rows (Toggle/Option/Slider/ActionRow children).
//
//   SettingsScaffold {
//       title: qsTr("Display")
//       ToggleRow { ... }
//       OptionRow { ... }
//   }
FocusScope {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias rows: rowModel.children
    property alias listView: list

    Column {
        anchors.fill: parent
        anchors.margins: Theme.screenMargin
        spacing: Theme.pad

        Text {
            text: root.title
            color: Theme.text
            font.pixelSize: Theme.fontTitle
            font.weight: Font.Bold
        }
        Text {
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Theme.textDim
            font.pixelSize: Theme.fontBody
            width: parent.width
            wrapMode: Text.Wrap
        }

        ListView {
            id: list
            width: parent.width
            // Leave room at the bottom for the HintBar so rows never tuck
            // underneath it, and a little left/right breathing space so a
            // focused row's border/glow isn't clipped by the list bounds.
            height: parent.height - y - 72
            leftMargin: 4
            rightMargin: 4
            model: ObjectModel { id: rowModel }
            focus: true
            clip: true
            spacing: Theme.padSmall
            keyNavigationEnabled: true
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Theme.animFast
            preferredHighlightBegin: 0
            preferredHighlightEnd: height - 140
            highlightRangeMode: ListView.ApplyRange
        }
    }

    HintBar {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.pad
        anchors.horizontalCenter: parent.horizontalCenter
        hints: [
            { button: "A", label: qsTr("Change") },
            { button: "swap_horiz", label: qsTr("Adjust") },
            { button: "B", label: qsTr("Back") }
        ]
    }
}
