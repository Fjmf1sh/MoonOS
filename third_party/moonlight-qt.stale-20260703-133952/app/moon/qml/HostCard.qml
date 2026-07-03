import QtQuick 2.15

// Large horizontal card for a paired/discovered PC.
FocusScope {
    id: root

    property string name: ""
    property bool online: false
    property bool paired: false
    property bool busy: false
    property bool statusUnknown: false

    signal activated()
    signal optionsRequested()

    width: 440
    height: 220

    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()
    Keys.onSpacePressed: activated()
    Keys.onPressed: function(event) {
        // Menu/X opens host options
        if (event.key === Qt.Key_Menu || event.key === Qt.Key_F10) {
            optionsRequested()
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Theme.radius + 4
        color: "transparent"
        border.width: 3
        border.color: Theme.accent
        opacity: root.activeFocus ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.activeFocus ? Qt.lighter(Theme.panelHigh, 1.1) : Theme.panel }
            GradientStop { position: 1.0; color: root.activeFocus ? Theme.panelHigh : Qt.darker(Theme.panel, 1.1) }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.pad
            spacing: 8

            Text { text: "🖥"; font.pixelSize: 56 }

            Text {
                text: root.name
                color: Theme.text
                font.pixelSize: Theme.fontH2
                font.weight: Font.DemiBold
                width: parent.width
                elide: Text.ElideRight
            }

            Row {
                spacing: 10
                Rectangle {
                    width: 14; height: 14; radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.statusUnknown ? Theme.textDim
                         : !root.online ? Theme.textDim
                         : !root.paired ? Theme.warning
                         : Theme.success
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.busy ? qsTr("Working…")
                        : root.statusUnknown ? qsTr("Looking for PC…")
                        : !root.online ? qsTr("Offline")
                        : !root.paired ? qsTr("Ready to pair")
                        : qsTr("Online")
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }

    scale: activeFocus ? Theme.focusScale : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }

    MouseArea { anchors.fill: parent; onClicked: { root.forceActiveFocus(); root.activated() } }
}
