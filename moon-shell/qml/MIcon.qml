import QtQuick 2.15

// A single Material Design icon. Uses the Material Icons font (installed in the
// image and loaded by Icons.qml) with ligature names, so you write the icon by
// its human name:  MIcon { name: "wifi" }  →  📶-style glyph.
//
// Keeping every glyph in one font means no per-icon image assets and one
// consistent visual language across the whole shell (replacing the old emoji).
Text {
    id: root

    property string name: ""
    property int size: Theme.fontH2

    text: name
    font.family: Icons.family
    font.pixelSize: size
    // Material Icons renders its glyphs through ligatures; make sure common
    // shaping is on and the box is sized to the glyph.
    font.hintingPreference: Font.PreferNoHinting
    color: Theme.text
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.QtRendering
}
