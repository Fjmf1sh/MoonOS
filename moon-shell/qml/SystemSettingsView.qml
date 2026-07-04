import QtQuick 2.15
import QtQml.Models 2.15

import MoonOS 1.0

SettingsScaffold {
    id: page
    title: qsTr("System")
    subtitle: qsTr("Moon OS %1").arg(MoonSystem.osVersion)

    ActionRow {
        label: qsTr("Update Moon OS")
        sublabel: qsTr("Pulls the installed git checkout and reruns install.sh")
        busy: MoonSystem.updateStatus === "running"
        value: MoonSystem.updateStatus === "success" ? qsTr("Up to date")
             : MoonSystem.updateStatus.indexOf("failed") === 0 ? qsTr("Last update failed")
             : ""
        onActivated: window.confirm(qsTr("Update Moon OS?"),
            qsTr("The console stays usable while downloading. Some updates finish with a restart."),
            qsTr("Update now"),
            function() { MoonSystem.startUpdate() })
    }

    ActionRow {
        label: qsTr("Uninstall Moon OS")
        sublabel: qsTr("Stops Moon OS and restores the normal Raspberry Pi OS login")
        destructive: true
        onActivated: window.confirm(qsTr("Uninstall Moon OS?"),
            qsTr("Moon OS will stop, remove its services and files, and restore the normal tty1 login. Your cloned repo is left alone."),
            qsTr("Uninstall"),
            function() { MoonSystem.startUninstall() }, true)
    }

    ActionRow {
        label: qsTr("Restart")
        onActivated: window.confirm(qsTr("Restart the console?"), "",
            qsTr("Restart"), function() { MoonSystem.reboot() })
    }

    ActionRow {
        label: qsTr("Power off")
        onActivated: window.confirm(qsTr("Power off the console?"), "",
            qsTr("Power off"), function() { MoonSystem.powerOff() })
    }

    ActionRow {
        label: qsTr("Export settings to USB drive")
        sublabel: qsTr("Copies paired PCs and settings to a plugged-in USB drive")
        onActivated: {
            MoonSystem.exportConfigToUsb()
            exportPoll.restart()
        }
        Timer {
            id: exportPoll
            interval: 2000; repeat: true
            property int tries: 0
            onTriggered: {
                var s = MoonSystem.configIoStatus()
                if (s === "running" && ++tries < 30) return
                stop(); tries = 0
                if (s.indexOf("success") === 0)
                    window.showError(qsTr("Settings exported"), qsTr("Saved to the USB drive as moonos-config.tar.gz."))
                else if (s.indexOf("failed") === 0)
                    window.showError(qsTr("Export didn't work"), qsTr("Plug in a USB drive and try again."), s)
            }
        }
    }

    ActionRow {
        label: qsTr("Import settings from USB drive")
        onActivated: window.confirm(qsTr("Import settings?"),
            qsTr("Replaces the current settings with moonos-config.tar.gz from the USB drive, then restarts."),
            qsTr("Import"),
            function() { MoonSystem.importConfigFromUsb(); importPoll.restart() })
        Timer {
            id: importPoll
            interval: 2000; repeat: true
            property int tries: 0
            onTriggered: {
                var s = MoonSystem.configIoStatus()
                if (s === "running" && ++tries < 30) return
                stop(); tries = 0
                if (s.indexOf("success") === 0)
                    MoonSystem.restartShell()
                else if (s.indexOf("failed") === 0)
                    window.showError(qsTr("Import didn't work"), qsTr("Couldn't find moonos-config.tar.gz on a USB drive."), s)
            }
        }
    }

    ToggleRow {
        label: qsTr("Developer mode")
        sublabel: qsTr("Enables SSH access and shows technical logs")
        checked: MoonSettings.developerMode
        onToggled: function(v) {
            if (v) {
                window.confirm(qsTr("Turn on developer mode?"),
                    qsTr("SSH turns on with user \"moon\". Change the password over SSH before exposing this console to an untrusted network."),
                    qsTr("Turn on"),
                    function() { MoonSystem.setDeveloperMode(true) })
                checked = false // reflects real state only after the service ran
            } else {
                MoonSystem.setDeveloperMode(false)
            }
        }
    }

    ActionRow {
        label: qsTr("View logs")
        visible: MoonSettings.developerMode
        onActivated: window.pushView("qrc:/moon/qml/DeveloperView.qml")
    }

    ActionRow {
        label: qsTr("Factory reset")
        sublabel: qsTr("Erases paired PCs, saved networks and all settings")
        destructive: true
        onActivated: window.confirm(qsTr("Factory reset?"),
            qsTr("Everything is erased and Moon OS restarts like new. This can't be undone."),
            qsTr("Erase everything"),
            function() { MoonSystem.factoryReset() }, true)
    }
}
