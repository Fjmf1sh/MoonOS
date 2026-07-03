import QtQuick 2.15

// A settings row that performs an action (or navigates) when selected.
FocusScope {
    id: root

    property string label: ""
    property string sublabel: ""
    property string value: ""      // status text on the right
    property bool destructive: false
    property bool enabled: true
    property bool busy: false
    signal activated()

    width: ListView.view ? ListView.view.width : 900
    height: 96
    focus: ListView.isCurrentItem
    opacity: enabled ? 1.0 : 0.4

    Keys.onReturnPressed: if (enabled && !busy) activated()
    Keys.onEnterPressed: if (enabled && !busy) activated()
    Keys.onSpacePressed: if (enabled && !busy) activated()

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.activeFocus ? Theme.panelHigh : Theme.panel
        border.color: root.activeFocus ? (root.destructive ? Theme.danger : Theme.accent) : "transparent"
        border.width: 2
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.pad
            width: parent.width * 0.6
            spacing: 2
            Text {
                text: root.label
                color: root.destructive ? Theme.danger : Theme.text
                font.pixelSize: Theme.fontBody
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

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.pad
            spacing: Theme.padSmall

            MoonSpinner { visible: root.busy; width: 36; height: 36; anchors.verticalCenter: parent.verticalCenter }
            Text {
                visible: root.value !== ""
                text: root.value
                color: Theme.textDim
                font.pixelSize: Theme.fontBody
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 420)
                elide: Text.ElideRight
            }
            Text {
                text: "›"
                color: root.activeFocus ? Theme.accent : Theme.textDim
                font.pixelSize: Theme.fontH2
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea { anchors.fill: parent; onClicked: { root.forceActiveFocus(); if (root.enabled && !root.busy) root.activated() } }
    }
}
