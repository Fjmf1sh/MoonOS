import QtQuick 2.15

FocusScope {
    id: root

    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property string suffix: ""
    property bool enabled: true
    signal changed(real value)

    width: ListView.view ? ListView.view.width : 900
    height: 96
    focus: ListView.isCurrentItem
    opacity: enabled ? 1.0 : 0.4

    function adjust(delta) {
        if (!enabled) return
        var v = Math.max(from, Math.min(to, value + delta * step))
        if (v !== value) {
            value = v
            changed(v)
        }
    }

    Keys.onLeftPressed: adjust(-1)
    Keys.onRightPressed: adjust(1)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: root.activeFocus ? Theme.panelHigh : Theme.panel
        border.color: root.activeFocus ? Theme.accent : "transparent"
        border.width: 2
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.pad
            text: root.label
            color: Theme.text
            font.pixelSize: Theme.fontBody
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.pad
            spacing: Theme.pad

            Rectangle {
                width: 320; height: 10; radius: 5
                color: Theme.bgTop
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: parent.width * (root.to > root.from ? (root.value - root.from) / (root.to - root.from) : 0)
                    height: parent.height
                    radius: 5
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }

            Text {
                text: Math.round(root.value) + root.suffix
                color: Theme.text
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
                width: 130
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
