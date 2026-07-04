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

    // 3+ choices stack vertically (power menu etc.); 1–2 sit side by side.
    readonly property bool stackButtons: buttons.length > 2

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width * 0.6 : 900, 980)
    // Never taller than the screen — the button area scrolls if it has to.
    height: Math.min(implicitHeight, parent ? parent.height * 0.9 : 700)
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

        // The buttons live in a clipped Flickable so a long menu (e.g. power
        // options) scrolls inside the dialog instead of spilling past its edge.
        Flickable {
            id: buttonScroll
            visible: !root.busy
            width: parent.width
            height: Math.min(buttonFlow.height,
                             (root.parent ? root.parent.height * 0.9 : 700) - 220)
            contentHeight: buttonFlow.height
            contentWidth: width
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            // Vertical stack for 3+ options, horizontal row for a yes/no.
            Grid {
                id: buttonFlow
                anchors.horizontalCenter: parent.horizontalCenter
                columns: root.stackButtons ? 1 : Math.max(1, root.buttons.length)
                spacing: Theme.padSmall

                Repeater {
                    id: buttonRepeater
                    model: root.buttons
                    FocusButton {
                        width: root.stackButtons ? buttonScroll.width : 260
                        height: 76
                        label: modelData.label
                        destructive: modelData.destructive === true
                        // Vertical menus navigate up/down; a row navigates left/right.
                        KeyNavigation.up: root.stackButtons && index > 0
                                          ? buttonRepeater.itemAt(index - 1) : null
                        KeyNavigation.down: root.stackButtons && index < root.buttons.length - 1
                                            ? buttonRepeater.itemAt(index + 1) : null
                        KeyNavigation.left: !root.stackButtons && index > 0
                                            ? buttonRepeater.itemAt(index - 1) : null
                        KeyNavigation.right: !root.stackButtons && index < root.buttons.length - 1
                                             ? buttonRepeater.itemAt(index + 1) : null
                        // Keep the focused button in view when the list scrolls.
                        onActiveFocusChanged: if (activeFocus) {
                            if (y < buttonScroll.contentY)
                                buttonScroll.contentY = y
                            else if (y + height > buttonScroll.contentY + buttonScroll.height)
                                buttonScroll.contentY = y + height - buttonScroll.height
                        }
                        onActivated: {
                            root.close()
                            if (modelData.action)
                                modelData.action()
                        }
                    }
                }
            }
        }
    }

    // Give the FIRST button active focus every time the dialog opens. Focusing
    // the content Column instead (the old behaviour) left the outline on a
    // button that had no active focus, so the second open looked "dead".
    onOpened: {
        var first = buttonRepeater.itemAt(0)
        if (first)
            first.forceActiveFocus()
        else
            contentItem.forceActiveFocus()
    }
}
