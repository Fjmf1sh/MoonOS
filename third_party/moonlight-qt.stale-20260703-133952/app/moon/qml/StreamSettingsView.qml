import QtQuick 2.15
import QtQml.Models 2.15

import StreamingPreferences 1.0
import SystemProperties 1.0
import ComputerModel 1.0
import ComputerManager 1.0
import MoonOS 1.0

// Streaming quality settings, written straight into the upstream
// StreamingPreferences singleton (the same object Session reads).
SettingsScaffold {
    id: page
    title: qsTr("Streaming")
    subtitle: qsTr("These settings apply to every PC unless you save a per-PC profile below.")

    readonly property var resolutions: [
        { label: "1280 × 720", w: 1280, h: 720 },
        { label: "1920 × 1080", w: 1920, h: 1080 },
        { label: "2560 × 1440", w: 2560, h: 1440 },
        { label: "3840 × 2160 (4K)", w: 3840, h: 2160 }
    ]
    readonly property var fpsOptions: [30, 60, 90, 120]

    function resolutionIndex() {
        for (var i = 0; i < resolutions.length; i++) {
            if (resolutions[i].w === StreamingPreferences.width &&
                resolutions[i].h === StreamingPreferences.height)
                return i
        }
        return 1
    }

    Component.onDestruction: StreamingPreferences.save()

    OptionRow {
        label: qsTr("Resolution")
        options: page.resolutions.map(function(r) { return r.label })
        currentIndex: page.resolutionIndex()
        onChanged: function(i) {
            StreamingPreferences.width = page.resolutions[i].w
            StreamingPreferences.height = page.resolutions[i].h
        }
    }

    OptionRow {
        label: qsTr("Frame rate")
        options: page.fpsOptions.map(function(f) { return f + " fps" })
        currentIndex: Math.max(0, page.fpsOptions.indexOf(StreamingPreferences.fps))
        onChanged: function(i) { StreamingPreferences.fps = page.fpsOptions[i] }
    }

    SliderRow {
        label: qsTr("Bitrate")
        from: 5000; to: 150000; step: 5000
        suffix: qsTr(" kbps")
        value: StreamingPreferences.bitrateKbps
        onChanged: function(v) { StreamingPreferences.bitrateKbps = v }
    }

    OptionRow {
        label: qsTr("Video codec")
        sublabel: qsTr("Auto picks the best codec both sides support")
        options: [qsTr("Auto"), "H.264", "HEVC", "AV1"]
        currentIndex: {
            switch (StreamingPreferences.videoCodecConfig) {
            case StreamingPreferences.VCC_FORCE_H264: return 1
            case StreamingPreferences.VCC_FORCE_HEVC: return 2
            case StreamingPreferences.VCC_FORCE_AV1: return 3
            default: return 0
            }
        }
        onChanged: function(i) {
            StreamingPreferences.videoCodecConfig =
                i === 1 ? StreamingPreferences.VCC_FORCE_H264 :
                i === 2 ? StreamingPreferences.VCC_FORCE_HEVC :
                i === 3 ? StreamingPreferences.VCC_FORCE_AV1 :
                          StreamingPreferences.VCC_AUTO
        }
    }

    ToggleRow {
        label: qsTr("HDR")
        sublabel: SystemProperties.supportsHdr ? qsTr("Stream in HDR when the game supports it")
                                               : qsTr("This display/decoder combination doesn't support HDR")
        enabled: SystemProperties.supportsHdr
        checked: StreamingPreferences.enableHdr
        onToggled: function(v) { StreamingPreferences.enableHdr = v }
    }

    ToggleRow {
        label: qsTr("VSync")
        checked: StreamingPreferences.enableVsync
        onToggled: function(v) { StreamingPreferences.enableVsync = v }
    }

    ToggleRow {
        label: qsTr("Frame pacing")
        sublabel: qsTr("Smoother motion at slightly higher latency")
        checked: StreamingPreferences.framePacing
        onToggled: function(v) { StreamingPreferences.framePacing = v }
    }

    OptionRow {
        label: qsTr("Audio")
        options: [qsTr("Stereo"), qsTr("5.1 surround"), qsTr("7.1 surround")]
        currentIndex: StreamingPreferences.audioConfig === StreamingPreferences.AC_51_SURROUND ? 1
                    : StreamingPreferences.audioConfig === StreamingPreferences.AC_71_SURROUND ? 2 : 0
        onChanged: function(i) {
            StreamingPreferences.audioConfig =
                i === 1 ? StreamingPreferences.AC_51_SURROUND :
                i === 2 ? StreamingPreferences.AC_71_SURROUND :
                          StreamingPreferences.AC_STEREO
        }
    }

    ToggleRow {
        label: qsTr("Play sound on the PC too")
        checked: StreamingPreferences.playAudioOnHost
        onToggled: function(v) { StreamingPreferences.playAudioOnHost = v }
    }

    ToggleRow {
        label: qsTr("Multiple controllers")
        sublabel: qsTr("Pass every connected controller to the PC")
        checked: StreamingPreferences.multiController
        onToggled: function(v) { StreamingPreferences.multiController = v }
    }

    ToggleRow {
        label: qsTr("Optimize game settings")
        sublabel: qsTr("Let the host tune game graphics for streaming")
        checked: StreamingPreferences.gameOptimizations
        onToggled: function(v) { StreamingPreferences.gameOptimizations = v }
    }

    // ---- per-host profiles ----

    ActionRow {
        id: profileRow
        label: qsTr("Save as profile for a PC")
        sublabel: qsTr("The saved profile loads automatically when you stream from that PC")

        ComputerModel {
            id: profileHosts
            Component.onCompleted: initialize(ComputerManager)
        }

        onActivated: {
            StreamingPreferences.save()
            if (profileHosts.rowCount() === 0) {
                window.showError(qsTr("No PCs"), qsTr("Pair a PC first, then save a profile for it."))
                return
            }
            var buttons = []
            var count = Math.min(profileHosts.rowCount(), 3)
            for (var i = 0; i < count; i++) {
                (function(idx) {
                    var name = profileHosts.data(profileHosts.index(idx, 0), 256)
                    buttons.push({ label: name, action: function() {
                        MoonSettings.saveStreamProfileForHost(name)
                    }})
                })(i)
            }
            buttons.push({ label: qsTr("Cancel"), action: function() {} })
            window.confirmDialogButtons(qsTr("Save profile for which PC?"), "", buttons)
        }
    }
}
