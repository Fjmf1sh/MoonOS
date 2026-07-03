import QtQuick 2.15
import QtQml.Models 2.15

import MoonOS 1.0

// HDMI display + sound + TV remote settings backed by DisplayService.
SettingsScaffold {
    id: page
    title: qsTr("Display & sound")

    Component.onCompleted: DisplayService.refresh()

    OptionRow {
        id: modeRow
        label: qsTr("Screen resolution")
        sublabel: DisplayService.pendingMode !== ""
                  ? qsTr("Restart the interface to apply %1").arg(DisplayService.pendingMode)
                  : qsTr("Currently %1").arg(DisplayService.currentMode)
        options: DisplayService.modes
        currentIndex: {
            var target = DisplayService.pendingMode !== "" ? DisplayService.pendingMode
                                                           : DisplayService.currentMode
            var i = DisplayService.modes.indexOf(target)
            return i >= 0 ? i : 0
        }
        onChanged: function(i) {
            if (!DisplayService.setMode(DisplayService.modes[i]))
                window.showError(qsTr("Couldn't save the display setting"),
                    qsTr("The display configuration could not be written."))
        }
    }

    ActionRow {
        label: qsTr("Apply resolution now")
        sublabel: qsTr("Restarts the Moon OS interface (takes a few seconds)")
        enabled: DisplayService.pendingMode !== ""
        onActivated: window.confirm(qsTr("Restart interface?"),
            qsTr("The screen goes dark for a few seconds, then comes back at %1.").arg(DisplayService.pendingMode),
            qsTr("Restart now"),
            function() { MoonSystem.restartShell() })
    }

    ActionRow {
        label: qsTr("Reset resolution to automatic")
        enabled: DisplayService.pendingMode !== "" || true
        onActivated: {
            DisplayService.clearModeOverride()
            window.confirm(qsTr("Use automatic resolution?"),
                qsTr("Restart the interface to go back to the TV's preferred mode."),
                qsTr("Restart now"),
                function() { MoonSystem.restartShell() })
        }
    }

    SliderRow {
        label: qsTr("Safe area")
        from: 80; to: 100; step: 1
        suffix: "%"
        value: MoonSettings.safeAreaPct
        onChanged: function(v) { MoonSettings.safeAreaPct = v }
    }

    OptionRow {
        label: qsTr("Sound output")
        options: {
            var names = []
            for (var i = 0; i < DisplayService.audioOutputs.length; i++)
                names.push(DisplayService.audioOutputs[i].name)
            return names.length ? names : [qsTr("Automatic")]
        }
        currentIndex: {
            for (var i = 0; i < DisplayService.audioOutputs.length; i++) {
                if (DisplayService.audioOutputs[i].device === MoonSettings.audioDevice)
                    return i
            }
            return 0
        }
        onChanged: function(i) {
            if (DisplayService.audioOutputs.length > i)
                DisplayService.setAudioOutput(DisplayService.audioOutputs[i].device)
        }
    }

    ToggleRow {
        label: qsTr("TV remote control (HDMI-CEC)")
        sublabel: CecService.available || !MoonSettings.cecEnabled
                  ? qsTr("Use your TV remote to drive Moon OS")
                  : qsTr("Turning on… (or this TV doesn't support CEC)")
        checked: MoonSettings.cecEnabled
        onToggled: function(v) { MoonSettings.cecEnabled = v }
    }

    ActionRow {
        label: qsTr("Wake TV and switch input")
        sublabel: qsTr("Sends an HDMI-CEC power-on to the TV")
        enabled: MoonSettings.cecEnabled
        onActivated: CecService.powerOnTv()
    }
}
