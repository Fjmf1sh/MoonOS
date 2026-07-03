import QtQuick 2.15
import QtQml.Models 2.15

import MoonOS 1.0

SettingsScaffold {
    title: qsTr("Settings")

    ActionRow {
        label: qsTr("Streaming")
        sublabel: qsTr("Resolution, frame rate, bitrate, codec, HDR")
        onActivated: window.pushView("qrc:/moon/qml/StreamSettingsView.qml")
    }
    ActionRow {
        label: qsTr("Network")
        sublabel: qsTr("Wi-Fi, Ethernet, IP address")
        value: NetworkService.ethernetConnected ? qsTr("Wired")
             : NetworkService.currentSsid !== "" ? NetworkService.currentSsid
             : qsTr("Not connected")
        onActivated: window.pushView("qrc:/moon/qml/NetworkSettingsView.qml")
    }
    ActionRow {
        label: qsTr("Controllers & Bluetooth")
        sublabel: qsTr("Pair and manage controllers")
        value: BluetoothService.connectedControllerCount > 0
               ? qsTr("%n connected", "", BluetoothService.connectedControllerCount) : ""
        onActivated: window.pushView("qrc:/moon/qml/BluetoothSettingsView.qml")
    }
    ActionRow {
        label: qsTr("Display & sound")
        sublabel: qsTr("Resolution, safe area, HDMI audio, TV remote")
        onActivated: window.pushView("qrc:/moon/qml/DisplaySettingsView.qml")
    }
    ActionRow {
        label: qsTr("System")
        sublabel: qsTr("Updates, developer mode, factory reset")
        onActivated: window.pushView("qrc:/moon/qml/SystemSettingsView.qml")
    }
}
