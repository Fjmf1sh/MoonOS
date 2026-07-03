import QtQuick 2.15
import QtQuick.Controls 2.15

// Full-screen text entry with the on-screen keyboard.
//   entry.prompt(title, placeholder, isPassword, function(text) { ... })
Popup {
    id: root

    property string title: ""
    property string placeholder: ""
    property bool isPassword: false
    property string value: ""
    property var callback: null

    function prompt(t, ph, password, cb) {
        title = t
        placeholder = ph || ""
        isPassword = password === true
        value = ""
        callback = cb
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width * 0.75 : 1100, 1200)
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    padding: Theme.pad * 1.5

    Overlay.modal: Rectangle { color: "#d00a0d1c" }

    background: Rectangle {
        radius: Theme.radius
        color: Theme.panel
        border.color: Theme.panelHigh
        border.width: 1
    }

    contentItem: Column {
        spacing: Theme.pad

        Text {
            text: root.title
            color: Theme.text
            font.pixelSize: Theme.fontH2
            font.weight: Font.DemiBold
        }

        Rectangle {
            width: parent.width
            height: 84
            radius: Theme.radiusSmall
            color: Theme.bgTop
            border.color: Theme.accent
            border.width: 2

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.pad
                anchors.right: parent.right
                anchors.rightMargin: Theme.pad
                text: root.value === "" ? root.placeholder
                                        : (root.isPassword ? "•".repeat(root.value.length) : root.value)
                color: root.value === "" ? Theme.textDim : Theme.text
                font.pixelSize: Theme.fontH2
                elide: Text.ElideLeft
            }

            // Blinking caret
            Rectangle {
                width: 3
                height: 46
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(parent.width - Theme.pad, Theme.pad + caretMetrics.advanceWidth + 2)
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0; duration: 500 }
                    NumberAnimation { from: 0; to: 1; duration: 500 }
                }
            }
            TextMetrics {
                id: caretMetrics
                font.pixelSize: Theme.fontH2
                text: root.isPassword ? "•".repeat(root.value.length)
                                      : (root.value === "" ? "" : root.value)
            }
        }

        OnScreenKeyboard {
            id: osk
            anchors.horizontalCenter: parent.horizontalCenter
            focus: true
            onKeyPressed: function(text) { root.value += text }
            onBackspace: root.value = root.value.slice(0, -1)
            onAccepted: {
                var cb = root.callback
                var v = root.value
                root.close()
                if (cb) cb(v)
            }
            onDismissed: root.close()
        }

        HintBar {
            anchors.horizontalCenter: parent.horizontalCenter
            hints: [
                { button: "A", label: qsTr("Type") },
                { button: "B", label: qsTr("Cancel") }
            ]
        }
    }

    // Physical keyboard passthrough for people who plugged one in
    onOpened: osk.forceActiveFocus()
}
