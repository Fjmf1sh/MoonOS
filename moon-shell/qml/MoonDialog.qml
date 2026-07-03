import QtQuick 2.15
import QtQuick.Controls 2.15

// Modal dialog with big focusable buttons and full focus trapping.
// Usage:
//   dialog.show(title, message, [{ label, action, destructive }, ...])
// A default "OK" button is added when no buttons are given. Escape/B closes.
Popup {
    id: root

    property string title: ""
    property string message: ""
    property var buttons: []
    property bool busy: false

    function show(t, m, btns) {
        title = t
        message = m || ""
        buttons = btns && btns.length ? btns : [{ label: qsTr("OK"), action: function() {} }]
        busy = false
        open()
    }

    function showBusy(t, m) {
        title = t
        message = m || ""
        buttons = []
        busy = true
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width * 0.6 : 900, 980)
    modal: true
    focus: true
    closePolicy: busy ? Popup.NoAutoClose : Popup.CloseOnEscape
    padding: Theme.pad * 1.5

    Overlay.modal: Rectangle { color: "#c00a0d1c" }

    background: Rectangle {
        radius: Theme.radius
        color: Theme.panel
        border.color: Theme.panelHigh
        border.width: 1
    }

    enter: Transition {
        NumberAnimation { property: "scale"; from: 0.92; to: 1.0; duration: Theme.animMed; easing.type: Easing.OutCubic }
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animMed }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animFast }
    }

    contentItem: Column {
        spacing: Theme.pad

        Text {
            text: root.title
            color: Theme.text
            font.pixelSize: Theme.fontH2
            font.weight: Font.DemiBold
            width: parent.width
            wrapMode: Text.Wrap
        }

        Text {
            visible: root.message !== ""
            text: root.message
            color: Theme.textDim
            font.pixelSize: Theme.fontBody
            width: parent.width
            wrapMode: Text.Wrap
        }

        MoonSpinner {
            visible: root.busy
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            spacing: Theme.padSmall
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.busy

            Repeater {
                id: buttonRepeater
                model: root.buttons
                FocusButton {
                    width: 260
                    height: 76
                    label: modelData.label
                    destructive: modelData.destructive === true
                    focus: index === 0
                    KeyNavigation.left: index > 0 ? buttonRepeater.itemAt(index - 1) : null
                    KeyNavigation.right: index < root.buttons.length - 1 ? buttonRepeater.itemAt(index + 1) : null
                    onActivated: {
                        root.close()
                        if (modelData.action)
                            modelData.action()
                    }
                }
            }
        }
    }

    onOpened: contentItem.forceActiveFocus()
}
