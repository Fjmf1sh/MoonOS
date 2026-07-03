import QtQuick 2.15
import QtQml.Models 2.15

import MoonOS 1.0

// Controller pairing backed by BluetoothService (BlueZ D-Bus). The service's
// NoInputNoOutput agent auto-accepts "Just Works" pairing, so the flow is:
// put controller in pairing mode → it appears → select → done.
FocusScope {
    id: page

    property string busyPath: ""

    Connections {
        target: BluetoothService
        function onDeviceOperationFinished(path, ok, errorMessage) {
            if (path === page.busyPath)
                page.busyPath = ""
            if (!ok)
                window.showError(qsTr("Controller trouble"), errorMessage)
        }
    }

    Component.onCompleted: BluetoothService.startScan()
    Component.onDestruction: BluetoothService.stopScan()

    Column {
        anchors.fill: parent
        anchors.margins: Theme.screenMargin
        spacing: Theme.pad

        Text {
            text: qsTr("Controllers & Bluetooth")
            color: Theme.text
            font.pixelSize: Theme.fontTitle
            font.weight: Font.Bold
        }

        Row {
            spacing: Theme.padSmall
            MoonSpinner {
                visible: BluetoothService.discovering
                width: 32; height: 32
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: BluetoothService.discovering
                      ? qsTr("Searching… put your controller in pairing mode (usually hold the pair button until it flashes)")
                      : qsTr("Not searching")
                color: Theme.textDim
                font.pixelSize: Theme.fontBody
            }
        }

        ListView {
            id: devList
            width: parent.width
            height: parent.height - y
            spacing: Theme.padSmall
            clip: true
            focus: true
            keyNavigationEnabled: true
            model: BluetoothService.devices

            header: Column {
                width: devList.width
                spacing: Theme.padSmall
                bottomPadding: Theme.padSmall

                ToggleRow {
                    width: devList.width
                    label: qsTr("Bluetooth")
                    checked: BluetoothService.powered
                    enabled: BluetoothService.available
                    onToggled: function(v) { BluetoothService.setPowered(v) }
                }
                ActionRow {
                    width: devList.width
                    label: BluetoothService.discovering ? qsTr("Stop searching") : qsTr("Search for controllers")
                    onActivated: BluetoothService.discovering ? BluetoothService.stopScan()
                                                              : BluetoothService.startScan()
                }
            }

            delegate: FocusButton {
                width: devList.width
                height: 104
                icon: modelData.isController ? "🎮" : "📱"
                label: modelData.name
                sublabel: {
                    var bits = []
                    if (modelData.connected) bits.push(qsTr("Connected"))
                    else if (modelData.paired) bits.push(qsTr("Paired"))
                    else bits.push(qsTr("Available"))
                    if (modelData.battery >= 0) bits.push(qsTr("Battery %1%").arg(modelData.battery))
                    return bits.join(" · ")
                }

                MoonSpinner {
                    visible: page.busyPath === modelData.path
                    width: 36; height: 36
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.pad
                    anchors.verticalCenter: parent.verticalCenter
                }

                onActivated: {
                    if (page.busyPath !== "")
                        return
                    if (modelData.connected) {
                        window.confirm(modelData.name,
                            qsTr("Disconnect this device?"),
                            qsTr("Disconnect"),
                            function() {
                                page.busyPath = modelData.path
                                BluetoothService.disconnectDevice(modelData.path)
                            })
                    } else if (modelData.paired) {
                        page.busyPath = modelData.path
                        BluetoothService.connectDevice(modelData.path)
                    } else {
                        page.busyPath = modelData.path
                        BluetoothService.pairDevice(modelData.path)
                    }
                }

                Keys.onPressed: function(event) {
                    // X = forget device
                    if (event.key === Qt.Key_Menu && modelData.paired) {
                        window.confirm(qsTr("Forget %1?").arg(modelData.name),
                            qsTr("You'll need to pair it again to use it."),
                            qsTr("Forget device"),
                            function() { BluetoothService.forgetDevice(modelData.path) }, true)
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
            { button: "A", label: qsTr("Pair / Connect") },
            { button: "X", label: qsTr("Forget") },
            { button: "B", label: qsTr("Back") }
        ]
    }
}
