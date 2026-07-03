import QtQuick 2.15
import QtQml.Models 2.15

import MoonOS 1.0

// Shown when the shell crashed repeatedly and systemd restarted it with
// MOONOS_RECOVERY=1 (safe defaults: no KMS override, no CEC). Offers the
// fixes that solve the common failure modes without exposing a terminal.
SettingsScaffold {
    id: recovery
    title: qsTr("Recovery")
    subtitle: qsTr("Moon OS had trouble starting. Pick a fix below — your paired PCs and games are safe.")

    readonly property bool backLocked: true

    ActionRow {
        label: qsTr("Restart Moon OS")
        sublabel: qsTr("Try again with normal settings")
        onActivated: MoonSystem.restartShell()
    }

    ActionRow {
        label: qsTr("Reset display settings")
        sublabel: qsTr("Clears the resolution override — fixes a blank or garbled screen")
        onActivated: {
            DisplayService.clearModeOverride()
            MoonSettings.safeAreaPct = 100
            MoonSystem.restartShell()
        }
    }

    ToggleRow {
        label: qsTr("TV remote control (HDMI-CEC)")
        sublabel: qsTr("Turn off if the shell hangs at startup on this TV")
        checked: MoonSettings.cecEnabled
        onToggled: function(v) { MoonSettings.cecEnabled = v }
    }

    ActionRow {
        label: qsTr("Restart the console")
        onActivated: MoonSystem.reboot()
    }

    ActionRow {
        label: qsTr("Factory reset")
        sublabel: qsTr("Erases paired PCs, networks and settings")
        destructive: true
        onActivated: window.confirm(qsTr("Factory reset?"),
            qsTr("This erases all paired PCs, saved networks and settings. Moon OS restarts like new."),
            qsTr("Erase everything"),
            function() { MoonSystem.factoryReset() }, true)
    }
}
