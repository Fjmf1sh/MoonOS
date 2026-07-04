pragma Singleton
import QtQuick 2.15

// Central handle for the icon font used by MIcon. Moon OS embeds Material
// Symbols Rounded and addresses glyphs by codepoint, because the variable
// font does not reliably expose the old Material Icons ligatures to Qt.
QtObject {
    id: root

    readonly property string family: symbolFont.status === FontLoader.Ready
                                     ? symbolFont.name : "Material Symbols Rounded"
    readonly property string fallbackGlyph: String.fromCharCode(0xe88e) // info
    property var warnedMissing: ({})
    readonly property var codepoints: ({
        "bluetooth": 0xe1a7,
        "bluetooth_disabled": 0xe1a9,
        "check": 0xe5ca,
        "content_paste": 0xe14f,
        "dark_mode": 0xe51c,
        "desktop_windows": 0xe30c,
        "expand_more": 0xe5cf,
        "gamepad": 0xe021,
        "keyboard": 0xe312,
        "keyboard_arrow_up": 0xe316,
        "link": 0xe157,
        "lock": 0xe88d,
        "power_settings_new": 0xe8ac,
        "refresh": 0xe5d5,
        "rocket_launch": 0xeb9b,
        "search": 0xe8b6,
        "settings": 0xe8b8,
        "smartphone": 0xe0d4,
        "sports_esports": 0xe6ec,
        "swap_horiz": 0xe8d4,
        "wifi": 0xe63e,
        "wifi_off": 0xe648
    })

    function hasIcon(name) {
        return name !== "" && codepoints[name] !== undefined
    }

    function glyph(name) {
        if (hasIcon(name))
            return String.fromCharCode(codepoints[name])

        if (name !== "" && warnedMissing[name] !== true) {
            warnedMissing[name] = true
            console.warn("Missing Material Symbols Rounded icon codepoint:", name)
        }
        return fallbackGlyph
    }

    FontLoader {
        id: symbolFont
        source: "qrc:/moon/assets/fonts/MaterialSymbolsRounded.ttf"
    }
}
