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

    Keys.onUpPressed: { if (curRow > 0) { curRow--; clampCol() } }
    Keys.onDownPressed: { if (curRow < layout.length - 1) { curRow++; clampCol() } }
    Keys.onLeftPressed: { if (curCol > 0) curCol-- }
    Keys.onRightPressed: { if (curCol < layout[curRow].length - 1) curCol++ }
    Keys.onReturnPressed: pressCurrent()
    Keys.onEnterPressed: pressCurrent()
    Keys.onSpacePressed: pressCurrent()
    Keys.onEscapePressed: dismissed()
    // X button (mapped to keyboard 'x'? no — SDL nav sends Menu key for X) —
    // backspace is also reachable directly on the bottom row.
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Backspace) { backspace(); event.accepted = true }
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
