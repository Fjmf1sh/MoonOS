import QtQuick 2.15

// Controller-driven on-screen keyboard. Navigation is index-based (row/col)
// so the whole keyboard is one focus item — much snappier to drive with a
// D-pad than per-key focus chains.
FocusScope {
    id: root

    property bool shifted: false
    property bool symbols: false

    signal keyPressed(string text)
    signal backspace()
    signal accepted()
    signal dismissed()
    // Emitted when the user tries to move focus off the top edge of the
    // keyboard, so the hosting dialog can hand focus to controls above it.
    signal navigateOut(string direction)

    readonly property var lettersLayout: [
        ["1","2","3","4","5","6","7","8","9","0"],
        ["q","w","e","r","t","y","u","i","o","p"],
        ["a","s","d","f","g","h","j","k","l","-"],
        ["z","x","c","v","b","n","m",".","_","@"],
        ["⇧","SYM","SPACE","⌫","DONE"]
    ]
    readonly property var symbolsLayout: [
        ["1","2","3","4","5","6","7","8","9","0"],
        ["!","#","$","%","&","*","(",")","+","="],
        ["\"","'",":",";","/","?","~","^","[","]"],
        ["{","}","<",">","|","\\",",",".","-","_"],
        ["⇧","ABC","SPACE","⌫","DONE"]
    ]
    readonly property var layout: symbols ? symbolsLayout : lettersLayout

    property int curRow: 1
    property int curCol: 0

    width: 900
    height: col.height

    function clampCol() {
        curCol = Math.min(curCol, layout[curRow].length - 1)
    }

    function currentKey() { return layout[curRow][curCol] }

    function pressCurrent() {
        var key = currentKey()
        switch (key) {
        case "⇧": shifted = !shifted; break
        case "SYM": symbols = true; clampCol(); break
        case "ABC": symbols = false; clampCol(); break
        case "SPACE": keyPressed(" "); break
        case "⌫": backspace(); break
        case "DONE": accepted(); break
        default:
            keyPressed(shifted ? key.toUpperCase() : key)
            if (shifted) shifted = false
        }
    }

    // A single handler serves controller, TV remote AND a physical keyboard.
    // The distinction: key-events synthesized from the gamepad (by moonlight's
    // SdlGamepadKeyNavigation) and the CEC remote carry no `text`; real
    // keystrokes from a plugged-in keyboard do. So printable `text` is treated
    // as direct typing, while text-less Return/arrows drive the on-screen keys.
    Keys.onPressed: function(event) {
        // ---- physical keyboard: type the character directly ----
        if (event.text.length === 1) {
            var code = event.text.charCodeAt(0)
            if (code === 13 || code === 10) { accepted(); event.accepted = true; return }      // Enter
            if (code === 8 || code === 127) { backspace(); event.accepted = true; return }      // Backspace/Del
            if (code >= 32) { keyPressed(event.text); event.accepted = true; return }           // printable
        }

        // ---- controller / remote / arrow navigation ----
        switch (event.key) {
        case Qt.Key_Up:
            if (curRow > 0) { curRow--; clampCol() } else navigateOut("up")
            break
        case Qt.Key_Down:
            if (curRow < layout.length - 1) { curRow++; clampCol() }
            break
        case Qt.Key_Left:
            if (curCol > 0) curCol--; else navigateOut("left")
            break
        case Qt.Key_Right:
            if (curCol < layout[curRow].length - 1) curCol++
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            pressCurrent()
            break
        case Qt.Key_Backspace:
            backspace()
            break
        case Qt.Key_Escape:
            dismissed()
            break
        default:
            return
        }
        event.accepted = true
    }

    Column {
        id: col
        spacing: 10

        Repeater {
            model: root.layout.length
            Row {
                readonly property int rowIndex: index
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: root.layout[rowIndex]
                    Rectangle {
                        readonly property bool isCurrent: root.curRow === rowIndex && root.curCol === index
                        readonly property bool wide: modelData.length > 1
                        width: modelData === "SPACE" ? 330 : (wide ? 140 : 76)
                        height: 76
                        radius: Theme.radiusSmall
                        color: isCurrent && root.activeFocus ? Theme.accent : Theme.panelHigh
                        scale: isCurrent && root.activeFocus ? 1.08 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (modelData === "SPACE") return qsTr("Space")
                                if (modelData === "DONE") return qsTr("Done")
                                if (modelData.length === 1 && root.shifted) return modelData.toUpperCase()
                                return modelData
                            }
                            color: isCurrent && root.activeFocus ? Theme.bgTop : Theme.text
                            font.pixelSize: Theme.fontBody
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.forceActiveFocus()
                                root.curRow = rowIndex
                                root.curCol = index
                                root.pressCurrent()
                            }
                        }
                    }
                }
            }
        }
    }
}
