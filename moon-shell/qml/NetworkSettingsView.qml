import QtQuick 2.15
import QtQml.Models 2.15

import MoonOS 1.0

// Wi-Fi / Ethernet management backed by NetworkService (NetworkManager D-Bus).
FocusScope {
    id: page

    function signalIcon(strength) {
        if (strength > 75) return "▂▄▆█"
        if (strength > 50) return "▂▄▆"
        if (strength > 25) return "▂▄"
        return "▂"
    }

    function joinNetwork(ssid, secured, saved) {
        if (saved) {
            NetworkService.connectToSaved(ssid)
            busyDialog.showBusy(qsTr("Joining %1…").arg(ssid), "")
        } else if (secured) {
            window.textPrompt(qsTr("Password for %1").arg(ssid), "", true, function(pw) {
                if (pw === "") return
                NetworkService.connectToNetwork(ssid, pw)
                busyDialog.showBusy(qsTr("Joining %1…").arg(ssid), "")
            })
        } else {
            NetworkService.connectToNetwork(ssid, "")
            busyDialog.showBusy(qsTr("Joining %1…").arg(ssid), "")
        }
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

        Text {
            text: qsTr("Network")
            color: Theme.text
            font.pixelSize: Theme.fontTitle
            font.weight: Font.Bold
        }

        // Status strip
        Row {
            spacing: Theme.pad * 2

            Column {
                Text { text: qsTr("Status"); color: Theme.textDim; font.pixelSize: Theme.fontSmall }
                Text {
                    text: NetworkService.ethernetConnected ? qsTr("Wired connection")
                        : NetworkService.currentSsid !== "" ? qsTr("Wi-Fi: %1").arg(NetworkService.currentSsid)
                        : qsTr("Not connected")
                    color: NetworkService.online ? Theme.success : Theme.danger
                    font.pixelSize: Theme.fontBody
                }
            }
            Column {
                Text { text: qsTr("IP address"); color: Theme.textDim; font.pixelSize: Theme.fontSmall }
                Text {
                    text: NetworkService.ipAddress !== "" ? NetworkService.ipAddress : "—"
                    color: Theme.text
                    font.pixelSize: Theme.fontBody
                }
            }
            Column {
                Text { text: qsTr("Gateway"); color: Theme.textDim; font.pixelSize: Theme.fontSmall }
                Text {
                    text: NetworkService.gateway !== "" ? NetworkService.gateway : "—"
                    color: Theme.text
                    font.pixelSize: Theme.fontBody
                }
            }
            Column {
                Text { text: qsTr("DNS"); color: Theme.textDim; font.pixelSize: Theme.fontSmall }
                Text {
                    text: NetworkService.dnsServers.length ? NetworkService.dnsServers.join(", ") : "—"
                    color: Theme.text
                    font.pixelSize: Theme.fontBody
                }
            }
            Column {
                visible: NetworkService.currentSsid !== ""
                Text { text: qsTr("Signal"); color: Theme.textDim; font.pixelSize: Theme.fontSmall }
                Text {
                    text: page.signalIcon(NetworkService.signalStrength) + "  " + NetworkService.signalStrength + "%"
                    color: Theme.text
                    font.pixelSize: Theme.fontBody
                }
            }
        }

        // Network hardware address, useful for router reservations / diagnostics.
        Row {
            visible: NetworkService.macAddress !== ""
            spacing: Theme.padSmall
            Text { text: qsTr("MAC address"); color: Theme.textDim; font.pixelSize: Theme.fontSmall
                   anchors.verticalCenter: parent.verticalCenter }
            Text { text: NetworkService.macAddress; color: Theme.text; font.pixelSize: Theme.fontSmall
                   anchors.verticalCenter: parent.verticalCenter }
        }

        Row {
            spacing: Theme.padSmall
            visible: NetworkService.scanning
            MoonSpinner { width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Scanning for networks…")
                color: Theme.textDim
                font.pixelSize: Theme.fontBody
            }
        }

        // Top controls live ABOVE the list as real focusable buttons (a
        // ListView header is not reachable by arrow-key/controller nav).
        Row {
            id: topControls
            width: parent.width
            spacing: Theme.padSmall

            FocusButton {
                id: wifiBtn
                width: (parent.width - Theme.padSmall) / 2
                height: 96
                focus: true
                icon: NetworkService.wifiEnabled ? "wifi" : "wifi_off"
                label: qsTr("Wi-Fi")
                sublabel: !NetworkService.wifiAvailable ? qsTr("No adapter")
                          : NetworkService.wifiEnabled ? qsTr("On — select to turn off")
                          : qsTr("Off — select to turn on")
                enabled: NetworkService.wifiAvailable
                KeyNavigation.right: scanBtn
                KeyNavigation.down: netList.count > 0 ? netList : null
                onActivated: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
            }
            FocusButton {
                id: scanBtn
                width: (parent.width - Theme.padSmall) / 2
                height: 96
                icon: "refresh"
                label: qsTr("Scan again")
                sublabel: NetworkService.scanning ? qsTr("Scanning…") : qsTr("Look for networks")
                KeyNavigation.left: wifiBtn
                KeyNavigation.down: netList.count > 0 ? netList : null
                onActivated: NetworkService.scan()
            }
        }

        ListView {
            id: netList
            width: parent.width
            // Reserve space for the HintBar and pad the top/bottom so a focused
            // row's scale-up and glow aren't clipped at the list edges.
            height: parent.height - y - 72
            topMargin: 8
            bottomMargin: 8
            spacing: Theme.padSmall
            clip: true
            keyNavigationEnabled: true
            model: NetworkService.networks

            // Bridge the top edge back up to the Wi-Fi / Scan buttons.
            Keys.onUpPressed: function(event) {
                if (currentIndex <= 0) {
                    wifiBtn.forceActiveFocus()
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }

            delegate: FocusButton {
                // Inset so the 1.045 focus scale + glow stay inside the list.
                width: netList.width - Theme.pad * 4
                x: Theme.pad * 2
                height: 100
                focus: ListView.isCurrentItem
                icon: modelData.secured ? "lock" : "wifi"
                label: modelData.ssid
                sublabel: (modelData.active ? qsTr("Connected") + " · "
                          : modelData.saved ? qsTr("Saved") + " · " : "")
                          + page.signalIcon(modelData.strength)
                onActivated: {
                    if (modelData.active) {
                        window.confirm(qsTr("Forget %1?").arg(modelData.ssid),
                            qsTr("The password will be forgotten."),
                            qsTr("Forget network"),
                            function() { NetworkService.forgetNetwork(modelData.ssid) }, true)
                    } else {
                        page.joinNetwork(modelData.ssid, modelData.secured, modelData.saved)
                    }
                }
                Keys.onPressed: function(event) {
                    // X = forget saved network
                    if (event.key === Qt.Key_Menu && (modelData.saved || modelData.active)) {
                        window.confirm(qsTr("Forget %1?").arg(modelData.ssid),
                            qsTr("The password will be forgotten."),
                            qsTr("Forget network"),
                            function() { NetworkService.forgetNetwork(modelData.ssid) }, true)
                        event.accepted = true
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
