import QtQuick 2.15

// Portrait box-art card for a game/app.
FocusScope {
    id: root

    property string name: ""
    property url boxArt: ""
    property bool running: false

    signal activated()

    width: 260
    height: 380

    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()
    Keys.onSpacePressed: activated()

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
        id: card
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.panel
        clip: true

        Image {
            id: art
            anchors.fill: parent
            anchors.bottomMargin: 64
            source: root.boxArt
            fillMode: Image.PreserveAspectCrop
            asynchronous: true

            // Placeholder while box art loads (or when the host has none)
            Rectangle {
                anchors.fill: parent
                visible: art.status !== Image.Ready
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.panelHigh }
                    GradientStop { position: 1.0; color: Theme.panel }
                }
                MIcon {
                    anchors.centerIn: parent
                    name: "sports_esports"
                    size: 64
                    color: Theme.textDim
                    opacity: 0.6
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 64
            color: root.activeFocus ? Theme.panelHigh : Qt.darker(Theme.panel, 1.05)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.padSmall
                anchors.right: parent.right
                anchors.rightMargin: Theme.padSmall
                text: root.name
                color: Theme.text
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
        }

        // "Running" badge
        Rectangle {
            visible: root.running
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.padSmall
            radius: Theme.radiusSmall
            color: Theme.success
            width: badgeText.implicitWidth + 20
            height: badgeText.implicitHeight + 10
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: qsTr("Running")
                color: Theme.bgTop
                font.pixelSize: Theme.fontSmall
                font.weight: Font.Bold
            }
        }
    }

    scale: activeFocus ? Theme.focusScale : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.forceActiveFocus()
        onClicked: { root.forceActiveFocus(); root.activated() }
    }
}
