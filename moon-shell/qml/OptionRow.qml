import QtQuick 2.15

// "< value >" cycle selector — the TV-native alternative to a combo box.
FocusScope {
    id: root

    property string label: ""
    property string sublabel: ""
    property var options: []       // list of display strings
    property int currentIndex: 0
    property bool enabled: true
    signal changed(int index)

    width: ListView.view ? ListView.view.width : 900
    height: 96
    focus: ListView.isCurrentItem
    opacity: enabled ? 1.0 : 0.4

    function step(delta) {
        if (!enabled || options.length === 0) return
        currentIndex = ((currentIndex + delta) % options.length + options.length) % options.length
        changed(currentIndex)
    }

    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onReturnPressed: step(1)
    Keys.onEnterPressed: step(1)
    Keys.onSpacePressed: step(1)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.activeFocus ? Theme.panelHigh : Theme.panel
        border.color: root.activeFocus ? Theme.accent : "transparent"
        border.width: 2
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        // Clicking anywhere on the row focuses it (and a click on the value area
        // steps forward), so the picker responds to a mouse as well as a pad.
        // The ‹ › arrows have their own MouseAreas layered on top of this.
        MouseArea {
            anchors.fill: parent
            onClicked: { root.forceActiveFocus(); root.step(1) }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.pad
            width: parent.width * 0.5
            spacing: 2
            Text { text: root.label; color: Theme.text; font.pixelSize: Theme.fontBody; elide: Text.ElideRight; width: parent.width }
            Text { visible: root.sublabel !== ""; text: root.sublabel; color: Theme.textDim; font.pixelSize: Theme.fontSmall; elide: Text.ElideRight; width: parent.width }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.pad
            spacing: Theme.padSmall

            Text {
                text: "‹"
                color: root.activeFocus ? Theme.accent : Theme.textDim
                font.pixelSize: Theme.fontH2
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; onClicked: root.step(-1) }
            }
            Text {
                text: root.options.length ? String(root.options[Math.min(root.currentIndex, root.options.length - 1)]) : "—"
                color: Theme.text
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 420)
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }
            Text {
                text: "›"
                color: root.activeFocus ? Theme.accent : Theme.textDim
                font.pixelSize: Theme.fontH2
                anchors.verticalCenter: parent.verticalCenter
                MouseArea { anchors.fill: parent; onClicked: root.step(1) }
            }
        }
    }
}
