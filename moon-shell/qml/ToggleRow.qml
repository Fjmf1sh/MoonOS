import QtQuick 2.15

FocusScope {
    id: root

    property string label: ""
    property string sublabel: ""
    property bool checked: false
    property bool enabled: true
    signal toggled(bool checked)

    width: ListView.view ? ListView.view.width : 900
    height: 96
    focus: ListView.isCurrentItem
    opacity: enabled ? 1.0 : 0.4

    function flip() {
        if (!enabled) return
        checked = !checked
        toggled(checked)
    }

    Keys.onReturnPressed: flip()
    Keys.onEnterPressed: flip()
    Keys.onSpacePressed: flip()
    Keys.onLeftPressed: if (checked) flip()
    Keys.onRightPressed: if (!checked) flip()

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.activeFocus ? Theme.panelHigh : Theme.panel
        border.color: root.activeFocus ? Theme.accent : "transparent"
        border.width: 2
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.pad
            width: parent.width * 0.65
            spacing: 2
            Text { text: root.label; color: Theme.text; font.pixelSize: Theme.fontBody; elide: Text.ElideRight; width: parent.width }
            Text { visible: root.sublabel !== ""; text: root.sublabel; color: Theme.textDim; font.pixelSize: Theme.fontSmall; elide: Text.ElideRight; width: parent.width }
        }

        // Switch track
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.pad
            width: 88; height: 44; radius: 22
            color: root.checked ? Theme.accent : Theme.bgTop
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
            Rectangle {
                width: 36; height: 36; radius: 18
                anchors.verticalCenter: parent.verticalCenter
                x: root.checked ? parent.width - width - 4 : 4
                color: Theme.text
                Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
            }
        }

        MouseArea { anchors.fill: parent; onClicked: { root.forceActiveFocus(); root.flip() } }
    }
}
