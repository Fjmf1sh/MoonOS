pragma Singleton
import QtQuick 2.15

// Moon OS design tokens. Everything in the shell reads from here so the
// whole UI can be retuned in one place. Sizes are in device pixels for a
// 1080p 10-foot layout; the root item scales for other resolutions.
QtObject {
    // Palette — deep space navy with a cool moonlight accent
    readonly property color bgTop: "#0a0d1c"
    readonly property color bgBottom: "#131832"
    readonly property color panel: "#1a2038"
    readonly property color panelHigh: "#232b4d"
    readonly property color accent: "#8ea7ff"
    readonly property color accentGlow: "#4d8ea7ff"
    readonly property color text: "#f2f4ff"
    readonly property color textDim: "#9aa3c4"
    readonly property color danger: "#ff6b81"
    readonly property color success: "#54d6a8"
    readonly property color warning: "#ffcf6b"

    // Type scale
    readonly property int fontTitle: 46
    readonly property int fontH1: 34
    readonly property int fontH2: 27
    readonly property int fontBody: 22
    readonly property int fontSmall: 17

    // Shape & spacing
    readonly property int radius: 18
    readonly property int radiusSmall: 12
    readonly property int pad: 24
    readonly property int padSmall: 12
    readonly property int screenMargin: 72

    // Motion
    readonly property int animFast: 120
    readonly property int animMed: 220
    readonly property real focusScale: 1.025
}
