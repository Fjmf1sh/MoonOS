import QtQuick 2.15

// The core interactive element of the shell: a large rounded panel that
// scales up and glows when it has controller focus. Everything clickable
// in Moon OS is built from this.
FocusScope {
    id: root

    property string label: ""
    property string sublabel: ""
    property string icon: ""       // Material Icons ligature name (see MIcon)
    property bool destructive: false
    property bool enabled: true
    property alias contentItem: extraContent.data

    signal activated()

    width: 300
    height: 96
    opacity: enabled ? 1.0 : 0.4

    Keys.onReturnPressed: if (enabled) activated()
    Keys.onEnterPressed: if (enabled) activated()
    Keys.onSpacePressed: if (enabled) activated()

    Rectangle {
        id: glow
        anchors.fill: bg
        anchors.margins: -4
        radius: Theme.radius + 4
        color: "transparent"
        border.width: 3
        border.color: root.destructive ? Theme.danger : Theme.accent
        opacity: root.activeFocus ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radius
        color: root.activeFocus ? Theme.panelHigh : Theme.panel
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        gradient: Gradient {
            GradientStop { position: 0.0; color: root.activeFocus ? Qt.lighter(Theme.panelHigh, 1.12) : Theme.panel }
            GradientStop { position: 1.0; color: root.activeFocus ? Theme.panelHigh : Qt.darker(Theme.panel, 1.08) }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.pad
            anchors.right: parent.right
            anchors.rightMargin: Theme.pad
            spacing: Theme.pad

            MIcon {
                visible: root.icon !== ""
                name: root.icon
                size: Theme.fontH1
                color: root.destructive ? Theme.danger : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (root.icon !== "" ? Theme.fontH1 + Theme.pad : 0)
                spacing: 4

                Text {
                    text: root.label
                    color: root.destructive ? Theme.danger : Theme.text
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    visible: root.sublabel !== ""
                    text: root.sublabel
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }

        Item { id: extraContent; anchors.fill: parent }
    }

    scale: activeFocus ? Theme.focusScale : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: if (root.enabled) root.forceActiveFocus()
        onClicked: { root.forceActiveFocus(); if (root.enabled) root.activated() }
    }
}
