import QtQuick 2.15
import QtQml.Models 2.15

import MoonOS 1.0

// Controller pairing backed by BluetoothService (BlueZ D-Bus).
FocusScope {
    id: page

    property string busyPath: ""
    readonly property int columnGap: Theme.pad * 1.5
    readonly property var knownDevices: filterDevices(BluetoothService.devices, true)
    readonly property var nearbyDevices: filterDevices(BluetoothService.devices, false)

    function filterDevices(devices, known) {
        var out = []
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i]
            var isKnown = d.connected || d.paired
            if (known === isKnown)
                out.push(d)
        }
        return out
    }

    function deviceSubtitle(device) {
        var bits = []
        if (device.connected) bits.push(qsTr("Connected"))
        else if (device.paired) bits.push(qsTr("Paired"))
        else bits.push(qsTr("Available"))
        if (device.battery >= 0) bits.push(qsTr("Battery %1%").arg(device.battery))
        return bits.join(" · ")
    }

    function operateDevice(device) {
        if (page.busyPath !== "")
            return
        if (device.connected) {
            window.confirm(device.name,
                qsTr("Disconnect this device?"),
                qsTr("Disconnect"),
                function() {
                    page.busyPath = device.path
                    BluetoothService.disconnectDevice(device.path)
                })
        } else if (device.paired) {
            page.busyPath = device.path
            BluetoothService.connectDevice(device.path)
        } else {
            page.busyPath = device.path
            BluetoothService.pairDevice(device.path)
        }
    }

    function forgetDevice(device) {
        window.confirm(qsTr("Forget %1?").arg(device.name),
            qsTr("You'll need to pair it again to use it."),
            qsTr("Forget device"),
            function() { BluetoothService.forgetDevice(device.path) }, true)
    }

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

        Row {
            width: parent.width
            spacing: Theme.pad

            Text {
                width: Math.max(0, parent.width - controls.width - Theme.pad)
                text: qsTr("Controllers & Bluetooth")
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
                    id: btBtn
                    width: 250; height: 88
                    focus: true
                    icon: BluetoothService.powered ? "bluetooth" : "bluetooth_disabled"
                    label: qsTr("Bluetooth")
                    sublabel: !BluetoothService.available ? qsTr("No adapter")
                              : BluetoothService.powered ? qsTr("On") : qsTr("Off")
                    enabled: BluetoothService.available
                    KeyNavigation.right: searchBtn
                    KeyNavigation.down: knownList.count > 0 ? knownList
                                        : nearbyList.count > 0 ? nearbyList : null
                    onActivated: BluetoothService.setPowered(!BluetoothService.powered)
                }
                FocusButton {
                    id: searchBtn
                    width: 280; height: 88
                    icon: "search"
                    label: BluetoothService.discovering ? qsTr("Stop search") : qsTr("Search")
                    sublabel: BluetoothService.discovering ? qsTr("Scanning...") : qsTr("Pairing mode")
                    KeyNavigation.left: btBtn
                    KeyNavigation.down: nearbyList.count > 0 ? nearbyList
                                        : knownList.count > 0 ? knownList : null
                    onActivated: BluetoothService.discovering ? BluetoothService.stopScan()
                                                              : BluetoothService.startScan()
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

                Text {
                    width: parent.width
                    text: BluetoothService.connectedControllerCount > 0
                          ? qsTr("%n controller(s) connected", "", BluetoothService.connectedControllerCount)
                          : qsTr("No controllers connected")
                    color: BluetoothService.connectedControllerCount > 0 ? Theme.success : Theme.textDim
                    font.pixelSize: Theme.fontBody
                    elide: Text.ElideRight
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
                    model: page.knownDevices
                    KeyNavigation.up: btBtn
                    KeyNavigation.right: nearbyList.count > 0 ? nearbyList : null

                    delegate: FocusButton {
                        width: knownList.width - Theme.pad
                        x: Theme.padSmall
                        height: 104
                        focus: ListView.isCurrentItem
                        icon: modelData.isController ? "sports_esports" : "smartphone"
                        label: modelData.name
                        sublabel: page.deviceSubtitle(modelData)
                        onActivated: page.operateDevice(modelData)

                        MoonSpinner {
                            visible: page.busyPath === modelData.path
                            width: 34; height: 34
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.pad
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Menu) {
                                page.forgetDevice(modelData)
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
                        width: parent.width - (BluetoothService.discovering ? 44 : 0)
                        text: qsTr("Nearby")
                        color: Theme.text
                        font.pixelSize: Theme.fontH2
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    MoonSpinner {
                        visible: BluetoothService.discovering
                        width: 32; height: 32
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    width: parent.width
                    text: BluetoothService.discovering
                          ? qsTr("Put your controller in pairing mode.")
                          : qsTr("Start search to find unpaired devices.")
                    color: Theme.textDim
                    font.pixelSize: Theme.fontBody
                    wrapMode: Text.Wrap
                }

                ListView {
                    id: nearbyList
                    width: parent.width
                    height: parent.height - y
                    topMargin: 8
                    bottomMargin: 8
                    spacing: Theme.pad
                    clip: true
                    keyNavigationEnabled: true
                    model: page.nearbyDevices
                    KeyNavigation.up: searchBtn
                    KeyNavigation.left: knownList.count > 0 ? knownList : null

                    delegate: FocusButton {
                        width: nearbyList.width - Theme.pad
                        x: Theme.padSmall
                        height: 104
                        focus: ListView.isCurrentItem
                        icon: modelData.isController ? "sports_esports" : "smartphone"
                        label: modelData.name
                        sublabel: page.deviceSubtitle(modelData)
                        onActivated: page.operateDevice(modelData)

                        MoonSpinner {
                            visible: page.busyPath === modelData.path
                            width: 34; height: 34
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.pad
                            anchors.verticalCenter: parent.verticalCenter
                        }
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
