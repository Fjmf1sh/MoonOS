import QtQuick 2.15
import QtQuick.Controls 2.15

import MoonOS 1.0

// Full-screen text entry backed by the built-in on-screen keyboard, so no
// physical keyboard is ever required. If one *is* plugged in it works too
// (the keyboard component types physical characters directly).
//
//   entry.prompt(title, placeholder, isPassword, function(text) { ... })
//
// Password fields are masked with a reveal toggle. Clipboard paste is offered
// only in developer mode (per the Moon OS security model).
Popup {
    id: root

    property string title: ""
    property string placeholder: ""
    property bool isPassword: false
    property bool revealed: false
    property string value: ""
    property var callback: null

    function prompt(t, ph, password, cb) {
        title = t
        placeholder = ph || ""
        isPassword = password === true
        revealed = false
        value = ""
        callback = cb
        open()
    }

    function submit() {
        var cb = root.callback
        var v = root.value
        root.close()
        if (cb) cb(v)
    }

    readonly property bool masked: isPassword && !revealed
    readonly property bool hasTopControls: isPassword || MoonSettings.developerMode

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

    // Hidden input used only to pull text off the system clipboard for the
    // developer-mode Paste action (Qt Quick has no direct clipboard API).
    TextInput {
        id: clipboardProxy
        visible: false
        function grabClipboard() {
            clipboardProxy.text = ""
            clipboardProxy.paste()
            return clipboardProxy.text
        }
    }

    contentItem: Column {
        id: fieldColumn
        spacing: Theme.pad
        // Hold focus (and so receive the physical-keyboard fallback below) when
        // the on-screen keyboard is hidden.
        focus: true

        // Physical-keyboard fallback: bubbled keystrokes are typed into the
        // field no matter which sub-control holds focus. Synthetic controller
        // key-events carry no `text`, so this never disturbs gamepad nav.
        Keys.onPressed: function(event) {
            if (event.text.length !== 1)
                return
            var code = event.text.charCodeAt(0)
            if (code === 13 || code === 10) { root.submit(); event.accepted = true }
            else if (code === 8 || code === 127) { root.value = root.value.slice(0, -1); event.accepted = true }
            else if (code >= 32) {
                // Apply Shift ourselves — some console keymaps don't fold it into
                // event.text, so Shift+letter would otherwise stay lowercase.
                var ch = event.text
                if ((event.modifiers & Qt.ShiftModifier) && ch >= "a" && ch <= "z")
                    ch = ch.toUpperCase()
                root.value += ch; event.accepted = true
            }
        }

        Text {
            text: root.title
            color: Theme.text
            font.pixelSize: Theme.fontH2
            font.weight: Font.DemiBold
        }

        // ---- top controls: reveal + paste (focusable above the keyboard) ----
        Row {
            id: topControls
            spacing: Theme.padSmall
            visible: root.hasTopControls

            FocusButton {
                id: revealBtn
                visible: root.isPassword
                width: 220; height: 64
                icon: root.revealed ? "visibility_off" : "visibility"
                label: root.revealed ? qsTr("Hide") : qsTr("Show")
                KeyNavigation.right: pasteBtn.visible ? pasteBtn : null
                KeyNavigation.down: osk
                onActivated: root.revealed = !root.revealed
            }

            FocusButton {
                id: pasteBtn
                visible: MoonSettings.developerMode
                width: 220; height: 64
                icon: "content_paste"
                label: qsTr("Paste")
                KeyNavigation.left: revealBtn.visible ? revealBtn : null
                KeyNavigation.down: osk
                onActivated: {
                    var t = clipboardProxy.grabClipboard()
                    if (t)
                        root.value += t
                }
            }
        }

        // ---- value field ----
        Rectangle {
            width: parent.width
            height: 84
            radius: Theme.radiusSmall
            color: Theme.bgTop
            border.color: Theme.accent
            border.width: 2

            Text {
                id: valueText
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.pad
                anchors.right: parent.right
                anchors.rightMargin: Theme.pad
                text: root.value === "" ? root.placeholder
                                        : (root.masked ? "•".repeat(root.value.length) : root.value)
                color: root.value === "" ? Theme.textDim : Theme.text
                font.pixelSize: Theme.fontH2
                elide: Text.ElideLeft
            }

            // Blinking caret at the end of the entered text
            Rectangle {
                width: 3
                height: 46
                color: Theme.accent
                visible: root.value !== ""
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(parent.width - Theme.pad,
                            Theme.pad + Math.min(caretMetrics.advanceWidth, parent.width - Theme.pad * 2) + 2)
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0; duration: 500 }
                    NumberAnimation { from: 0; to: 1; duration: 500 }
                }
            }
            TextMetrics {
                id: caretMetrics
                font.pixelSize: Theme.fontH2
                text: root.value === "" ? ""
                      : (root.masked ? "•".repeat(root.value.length) : root.value)
            }
        }

        // Hint shown in place of the on-screen keyboard once a real keyboard is
        // in use — the field and Show/Hide controls stay live above.
        Text {
            visible: !osk.visible
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Keyboard detected — just type. Press a controller button for the on-screen keyboard.")
            color: Theme.textDim
            font.pixelSize: Theme.fontSmall
            horizontalAlignment: Text.AlignHCenter
        }

        OnScreenKeyboard {
            id: osk
            anchors.horizontalCenter: parent.horizontalCenter
            focus: true
            // Step aside for a physical keyboard; reappear on controller input.
            visible: !InputService.physicalKeyboard
            onVisibleChanged: {
                if (visible)
                    osk.forceActiveFocus()
                else
                    fieldColumn.forceActiveFocus()
            }
            onKeyPressed: function(text) { root.value += text }
            onBackspace: root.value = root.value.slice(0, -1)
            onAccepted: root.submit()
            onDismissed: root.close()
            onNavigateOut: function(direction) {
                // Leaving the top of the keyboard hops to the reveal/paste row.
                if (direction !== "up")
                    return
                if (root.isPassword)
                    revealBtn.forceActiveFocus()
                else if (MoonSettings.developerMode)
                    pasteBtn.forceActiveFocus()
            }
        }

        HintBar {
            anchors.horizontalCenter: parent.horizontalCenter
            hints: [
                { button: "A", label: qsTr("Type") },
                { button: "keyboard_arrow_up", label: qsTr("Options") },
                { button: "B", label: qsTr("Cancel") }
            ]
        }
    }

    onOpened: {
        if (osk.visible)
            osk.forceActiveFocus()
        else
            fieldColumn.forceActiveFocus()
    }
}
