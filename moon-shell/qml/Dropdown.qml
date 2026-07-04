import QtQuick 2.15
import QtQuick.Controls 2.15

// A settings row that opens a proper drop-down list of choices. Drop-in
// compatible with OptionRow (label / sublabel / options / currentIndex /
// changed), but instead of a "< value >" cycler it pops a scrollable menu that
// works equally well with a controller (A to open, Up/Down, A to pick, B to
// close) and a mouse (click the row, click a choice).
FocusScope {
    id: root

    property string label: ""
    property string sublabel: ""
    property var options: []           // list of display strings
    property int currentIndex: 0
    property bool enabled: true
    signal changed(int index)

    width: ListView.view ? ListView.view.width : 900
    height: 96
    focus: ListView.isCurrentItem
    opacity: enabled ? 1.0 : 0.4

    readonly property string currentText:
        options.length ? String(options[Math.min(currentIndex, options.length - 1)]) : "—"

    function openMenu() { if (enabled && options.length) menu.open() }
    function step(delta) {
        if (!enabled || options.length === 0) return
        currentIndex = ((currentIndex + delta) % options.length + options.length) % options.length
        changed(currentIndex)
    }

    Keys.onReturnPressed: openMenu()
    Keys.onEnterPressed: openMenu()
    Keys.onSpacePressed: openMenu()
    // Left/Right still nudge the value without opening the list.
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)

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
                text: root.currentText
                color: Theme.text
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 420)
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }
            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "expand_more"
                size: Theme.fontH2
                color: root.activeFocus ? Theme.accent : Theme.textDim
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: { root.forceActiveFocus(); root.openMenu() }
        }
    }

    // ---- the pop-up choice list --------------------------------------------
    Popup {
        id: menu
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(root.parent ? root.parent.width * 0.5 : 700, 760)
        height: Math.min(contentColumn.implicitHeight + Theme.pad * 2,
                         (root.parent ? root.parent.height * 0.8 : 640))
        modal: true
        focus: true
        padding: Theme.pad
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Overlay.modal: Rectangle { color: "#c00a0d1c" }
        background: Rectangle {
            radius: Theme.radius
            color: Theme.panel
            border.color: Theme.panelHigh
            border.width: 1
        }

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animFast } }

        contentItem: Column {
            id: contentColumn
            spacing: Theme.padSmall

            Text {
                text: root.label
                color: Theme.textDim
                font.pixelSize: Theme.fontSmall
                width: parent.width
                elide: Text.ElideRight
            }

            ListView {
                id: choiceList
                width: parent.width
                // Sized from its own content (capped to most of the screen) so
                // the pop-up height derives from it without a binding loop.
                height: Math.min(contentHeight, (root.parent ? root.parent.height * 0.6 : 480))
                model: root.options
                clip: true
                focus: true
                spacing: 6
                keyNavigationEnabled: true
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: root.currentIndex

                delegate: Rectangle {
                    width: choiceList.width
                    height: 68
                    radius: Theme.radiusSmall
                    readonly property bool sel: ListView.isCurrentItem
                    color: sel ? Theme.panelHigh : "transparent"
                    border.color: sel ? Theme.accent : "transparent"
                    border.width: 2

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.pad
                        text: String(modelData)
                        color: Theme.text
                        font.pixelSize: Theme.fontBody
                        font.weight: index === root.currentIndex ? Font.DemiBold : Font.Normal
                    }
                    MIcon {
                        visible: index === root.currentIndex
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.pad
                        name: "check"
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: choiceList.currentIndex = index
                        onClicked: {
                            root.currentIndex = index
                            root.changed(index)
                            menu.close()
                        }
                    }
                }

                Keys.onReturnPressed: choose()
                Keys.onEnterPressed: choose()
                Keys.onSpacePressed: choose()
                function choose() {
                    root.currentIndex = currentIndex
                    root.changed(currentIndex)
                    menu.close()
                }
            }
        }

        onOpened: {
            choiceList.currentIndex = root.currentIndex
            choiceList.forceActiveFocus()
        }
        onClosed: root.forceActiveFocus()
    }
}
