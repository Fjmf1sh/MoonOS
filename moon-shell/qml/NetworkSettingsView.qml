import QtQuick 2.15
import QtQml.Models 2.15

import MoonOS 1.0

// Wi-Fi / Ethernet management backed by NetworkService (NetworkManager D-Bus).
FocusScope {
    id: page

    readonly property int columnGap: Theme.pad * 1.5
    readonly property var knownNetworks: buildKnownNetworks(NetworkService.networks,
                                                            NetworkService.savedNetworks)
    readonly property var scannedNetworks: buildScannedNetworks(NetworkService.networks)

    function signalIcon(strength) {
        if (strength > 75) return "▂▄▆█"
        if (strength > 50) return "▂▄▆"
        if (strength > 25) return "▂▄"
        return "▂"
    }

    function buildKnownNetworks(networks, savedSsids) {
        var out = []
        var seen = {}
        for (var i = 0; i < networks.length; i++) {
            var n = networks[i]
            if (n.active || n.saved) {
                out.push(n)
                seen[n.ssid] = true
            }
        }
        for (var s = 0; s < savedSsids.length; s++) {
            var ssid = savedSsids[s]
            if (!seen[ssid])
                out.push({ ssid: ssid, strength: 0, secured: true, saved: true, active: false })
        }
        return out
    }

    function buildScannedNetworks(networks) {
        var out = []
        for (var i = 0; i < networks.length; i++) {
            var n = networks[i]
            if (!n.active && !n.saved)
                out.push(n)
        }
        return out
    }

    function joinNetwork(ssid, secured, saved) {
        if (saved) {
            NetworkService.connectToSaved(ssid)
            busyDialog.showBusy(qsTr("Joining %1...").arg(ssid), "")
        } else if (secured) {
            window.textPrompt(qsTr("Password for %1").arg(ssid), "", true, function(pw) {
                if (pw === "") return
                NetworkService.connectToNetwork(ssid, pw)
                busyDialog.showBusy(qsTr("Joining %1...").arg(ssid), "")
            })
        } else {
            NetworkService.connectToNetwork(ssid, "")
            busyDialog.showBusy(qsTr("Joining %1...").arg(ssid), "")
        }
    }

    function forgetNetwork(ssid) {
        window.confirm(qsTr("Forget %1?").arg(ssid),
            qsTr("The password will be forgotten."),
            qsTr("Forget network"),
            function() { NetworkService.forgetNetwork(ssid) }, true)
    }

    Connections {
        target: NetworkService
        function onConnectFinished(ok, errorMessage) {
            busyDialog.close()
            if (!ok)
                window.showError(qsTr("Couldn't join the network"), errorMessage)
        }
    }

    MoonDialog { id: busyDialog }

    Component.onCompleted: NetworkService.scan()

    Column {
        anchors.fill: parent
        anchors.margins: Theme.screenMargin
        spacing: Theme.pad

        Row {
            width: parent.width
            spacing: Theme.pad

            Text {
                width: Math.max(0, parent.width - controls.width - Theme.pad)
                text: qsTr("Network")
                color: Theme.text
                font.pixelSize: Theme.fontTitle
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            Row {
                id: controls
                width: implicitWidth
                spacing: Theme.padSmall
                FocusButton {
                    id: wifiBtn
                    width: 230; height: 88
                    focus: true
                    icon: NetworkService.wifiEnabled ? "wifi" : "wifi_off"
                    label: qsTr("Wi-Fi")
                    sublabel: !NetworkService.wifiAvailable ? qsTr("No adapter")
                              : NetworkService.wifiEnabled ? qsTr("On") : qsTr("Off")
                    enabled: NetworkService.wifiAvailable
                    KeyNavigation.right: scanBtn
                    KeyNavigation.down: knownList.count > 0 ? knownList
                                        : scannedList.count > 0 ? scannedList : null
                    onActivated: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
                }
                FocusButton {
                    id: scanBtn
                    width: 230; height: 88
                    icon: "refresh"
                    label: qsTr("Scan")
                    sublabel: NetworkService.scanning ? qsTr("Scanning...") : qsTr("Refresh")
                    KeyNavigation.left: wifiBtn
                    KeyNavigation.down: scannedList.count > 0 ? scannedList
                                        : knownList.count > 0 ? knownList : null
                    onActivated: NetworkService.scan()
                }
            }
        }

        Row {
            width: parent.width
            height: parent.height - y - 72
            spacing: page.columnGap

            Column {
                width: (parent.width - page.columnGap) * 0.43
                height: parent.height
                spacing: Theme.padSmall

                Text {
                    text: qsTr("Known")
                    color: Theme.text
                    font.pixelSize: Theme.fontH2
                    font.weight: Font.DemiBold
                }

                Column {
                    width: parent.width
                    spacing: 6
                    Text {
                        text: NetworkService.ethernetConnected ? qsTr("Wired connection")
                            : NetworkService.currentSsid !== "" ? qsTr("Wi-Fi: %1").arg(NetworkService.currentSsid)
                            : qsTr("Not connected")
                        color: NetworkService.online ? Theme.success : Theme.danger
                        font.pixelSize: Theme.fontBody
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: qsTr("IP %1  Gateway %2").arg(NetworkService.ipAddress !== "" ? NetworkService.ipAddress : "-")
                                                        .arg(NetworkService.gateway !== "" ? NetworkService.gateway : "-")
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: qsTr("DNS %1").arg(NetworkService.dnsServers.length ? NetworkService.dnsServers.join(", ") : "-")
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        visible: NetworkService.macAddress !== ""
                        text: qsTr("MAC %1").arg(NetworkService.macAddress)
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                ListView {
                    id: knownList
                    width: parent.width
                    height: parent.height - y
                    topMargin: 8
                    bottomMargin: 8
                    spacing: Theme.pad
                    clip: true
                    keyNavigationEnabled: true
                    model: page.knownNetworks
                    KeyNavigation.up: wifiBtn
                    KeyNavigation.right: scannedList.count > 0 ? scannedList : null

                    delegate: FocusButton {
                        width: knownList.width - Theme.pad
                        x: Theme.padSmall
                        height: 100
                        focus: ListView.isCurrentItem
                        icon: modelData.active ? "wifi" : "lock"
                        label: modelData.ssid
                        sublabel: (modelData.active ? qsTr("Connected") : qsTr("Saved"))
                                  + (modelData.strength > 0 ? " · " + page.signalIcon(modelData.strength) : "")
                        onActivated: modelData.active ? page.forgetNetwork(modelData.ssid)
                                                       : page.joinNetwork(modelData.ssid, modelData.secured, true)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Menu) {
                                page.forgetNetwork(modelData.ssid)
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            Column {
                width: (parent.width - page.columnGap) * 0.57
                height: parent.height
                spacing: Theme.padSmall

                Row {
                    width: parent.width
                    spacing: Theme.padSmall
                    Text {
                        width: parent.width - (NetworkService.scanning ? 44 : 0)
                        text: qsTr("Nearby")
                        color: Theme.text
                        font.pixelSize: Theme.fontH2
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    MoonSpinner {
                        visible: NetworkService.scanning
                        width: 32; height: 32
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                ListView {
                    id: scannedList
                    width: parent.width
                    height: parent.height - y
                    topMargin: 8
                    bottomMargin: 8
                    spacing: Theme.pad
                    clip: true
                    keyNavigationEnabled: true
                    model: page.scannedNetworks
                    KeyNavigation.up: scanBtn
                    KeyNavigation.left: knownList.count > 0 ? knownList : null

                    delegate: FocusButton {
                        width: scannedList.width - Theme.pad
                        x: Theme.padSmall
                        height: 100
                        focus: ListView.isCurrentItem
                        icon: modelData.secured ? "lock" : "wifi"
                        label: modelData.ssid
                        sublabel: page.signalIcon(modelData.strength) + "  " + modelData.strength + "%"
                        onActivated: page.joinNetwork(modelData.ssid, modelData.secured, false)
                    }
                }
            }
        }
    }

    HintBar {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.pad
        anchors.horizontalCenter: parent.horizontalCenter
        hints: [
            { button: "A", label: qsTr("Join") },
            { button: "X", label: qsTr("Forget") },
            { button: "B", label: qsTr("Back") }
        ]
    }
}
