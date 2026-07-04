import QtQuick 2.15

// A single Material Symbols Rounded icon. Callers use stable icon names;
// Icons.qml maps them to verified font codepoints.
Text {
    id: root

    property string name: ""
    property int size: Theme.fontH2

    text: Icons.glyph(name)
    font.family: Icons.family
    font.pixelSize: size
    font.hintingPreference: Font.PreferNoHinting
    color: Theme.text
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.QtRendering
}
