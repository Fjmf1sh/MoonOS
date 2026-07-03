import QtQuick 2.15
import QtQuick.Controls 2.15

import ComputerManager 1.0
import ComputerModel 1.0
import MoonOS 1.0

// Pair PC: mDNS auto-discovery (via the moonlight-qt backend), manual IP
// entry, PIN display, and pairing status.
FocusScope {
    id: pairView

    property int pendingPairIndex: -1

    ComputerModel {
        id: computerModel
        Component.onCompleted: initialize(ComputerManager)

        onPairingCompleted: function(error) {
            pinDialog.close()
            if (error) {
                window.showError(qsTr("Pairing didn't finish"),
                    qsTr("The PC rejected the pairing request or the PIN wasn't entered in time."),
                    error,
                    function() { pairView.startPairing(pairView.pendingPairIndex) })
            } else {
                window.showError(qsTr("Paired!"),
                    qsTr("You can now stream games from this PC."))
            }
        }

        onConnectionTestCompleted: function(result, blockedPorts) {
            testDialog.close()
            if (result === 0) {
                window.showError(qsTr("Connection looks good"),
                    qsTr("This network is not blocking game streaming."))
            } else {
                window.showError(qsTr("Connection problem"),
                    qsTr("Your network may be blocking game streaming."),
                    blockedPorts ? qsTr("Blocked ports: %1").arg(blockedPorts) : "")
            }
        }
    }

    Connections {
        target: ComputerManager
        function onComputerAddCompleted(success, detectedPortBlocking) {
            addDialog.close()
            if (!success) {
                window.showError(qsTr("PC not found"),
                    detectedPortBlocking
                        ? qsTr("A PC responded but the streaming ports look blocked. Check the firewall on your PC.")
                        : qsTr("No Sunshine PC answered at that address. Check the IP and that Sunshine is running."),
                    "",
                    function() { pairView.addManually() })
            }
        }
    }

    function startPairing(index) {
        if (index < 0)
            return
        pendingPairIndex = index
        var pin = computerModel.generatePinString()
        var name = computerModel.data(computerModel.index(index, 0), 256)
        pinDialog.show(name, pin)
        computerModel.pairComputer(index, pin)
    }

    function addManually() {
        window.textPrompt(qsTr("Enter the PC's IP address"), qsTr("e.g. 192.168.1.50"), false,
            function(text) {
                if (text.trim() === "")
                    return
                addDialog.showBusy(qsTr("Looking for %1…").arg(text.trim()),
                    qsTr("Make sure Sunshine is running on the PC."))
                ComputerManager.addNewHostManually(text.trim())
            })
    }

    MoonDialog { id: addDialog }
    MoonDialog { id: testDialog }
    PinDialog { id: pinDialog }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.screenMargin
        spacing: Theme.pad

        Text {
            text: qsTr("Pair PC")
            color: Theme.text
            font.pixelSize: Theme.fontTitle
            font.weight: Font.Bold
        }

        Row {
            spacing: Theme.padSmall
            MoonSpinner { width: 36; height: 36; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Searching for PCs running Sunshine on your network…")
                color: Theme.textDim
                font.pixelSize: Theme.fontBody
            }
        }

        ListView {
            id: hostList
            width: parent.width
            height: parent.height - y - manualRow.height - Theme.pad * 2
            spacing: Theme.padSmall
            clip: true
            keyNavigationEnabled: true
            focus: true
            model: computerModel
            KeyNavigation.down: manualRow

            delegate: FocusButton {
                width: hostList.width
                height: 110
                icon: "🖥"
                label: model.name
                sublabel: model.paired
                          ? qsTr("Already paired — select to test the connection")
                          : model.online
                            ? qsTr("Ready to pair")
                            : qsTr("Offline")
                focus: index === 0
                onActivated: {
                    if (model.paired) {
                        testDialog.showBusy(qsTr("Testing connection…"), "")
                        computerModel.testConnectionForComputer(index)
                    } else if (model.online) {
                        pairView.startPairing(index)
                    } else {
                        window.showError(qsTr("%1 is offline").arg(model.name),
                            qsTr("Wake the PC and make sure Sunshine is running."))
                    }
                }
            }
        }

        FocusButton {
            id: manualRow
            width: parent.width
            height: 110
            icon: "⌨"
            label: qsTr("Add PC by IP address")
            sublabel: qsTr("Use this if your PC doesn't appear automatically")
            KeyNavigation.up: hostList
            onActivated: pairView.addManually()
        }
    }

    HintBar {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.pad
        anchors.horizontalCenter: parent.horizontalCenter
        hints: [
            { button: "A", label: qsTr("Pair") },
            { button: "B", label: qsTr("Back") }
        ]
    }
}
