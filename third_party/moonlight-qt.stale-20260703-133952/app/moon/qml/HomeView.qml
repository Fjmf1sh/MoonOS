import QtQuick 2.15
import QtQuick.Controls 2.15

import ComputerManager 1.0
import ComputerModel 1.0
import MoonOS 1.0

// Home: recent games, paired PCs, quick actions, live status strip.
FocusScope {
    id: home

    // ComputerModel role values (Qt::UserRole + n, fixed in the fork)
    readonly property int roleName: 256
    readonly property int roleOnline: 257
    readonly property int rolePaired: 258

    ComputerModel {
        id: computerModel
        Component.onCompleted: initialize(ComputerManager)
    }

    function findHostIndex(hostName) {
        for (var i = 0; i < computerModel.rowCount(); i++) {
            if (computerModel.data(computerModel.index(i, 0), roleName) === hostName)
                return i
        }
        return -1
    }

    function openHost(index, name, online, paired) {
        if (!online) {
            window.confirm(qsTr("%1 is offline").arg(name),
                qsTr("Make sure the PC is awake and Sunshine is running, then try again."),
                qsTr("Send Wake-on-LAN"),
                function() { computerModel.wakeComputer(index) })
        } else if (!paired) {
            window.pushView("qrc:/moon/qml/PairView.qml")
        } else {
            window.pushView("qrc:/moon/qml/LibraryView.qml",
                            { computerIndex: index, hostName: name })
        }
    }

    function hostOptions(index, name) {
        errorForgetIndex = index
        window.confirm(qsTr("Forget %1?").arg(name),
            qsTr("You will need to pair again to stream from this PC."),
            qsTr("Forget PC"),
            function() {
                MoonSettings.removeRecentGamesForHost(name)
                computerModel.deleteComputer(errorForgetIndex)
            }, true)
    }
    property int errorForgetIndex: -1

    // ---- header ------------------------------------------------------------

    Item {
        id: header
        anchors.top: parent.top
        anchors.topMargin: Theme.pad * 1.5
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.screenMargin
        anchors.rightMargin: Theme.screenMargin
        height: 72

        Row {
            spacing: Theme.padSmall
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                width: 44; height: 44; radius: 22
                anchors.verticalCenter: parent.verticalCenter
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#e8ecff" }
                    GradientStop { position: 1.0; color: "#8ea7ff" }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Moon OS"
                color: Theme.text
                font.pixelSize: Theme.fontH1
                font.weight: Font.Bold
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.pad

            // Controller status
            Row {
                spacing: 6
                visible: BluetoothService.connectedControllerCount > 0
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "🎮"; font.pixelSize: Theme.fontBody; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: BluetoothService.connectedControllerCount
                    color: Theme.textDim; font.pixelSize: Theme.fontBody
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Network status
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: NetworkService.ethernetConnected ? qsTr("Wired")
                    : NetworkService.currentSsid !== "" ? NetworkService.currentSsid
                    : qsTr("No network")
                color: NetworkService.online ? Theme.textDim : Theme.danger
                font.pixelSize: Theme.fontBody
            }

            Text {
                id: clock
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
                Timer {
                    interval: 10000; running: true; repeat: true; triggeredOnStart: true
                    onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm")
                }
            }
        }
    }

    // ---- content sections ----------------------------------------------------

    Flickable {
        anchors.top: header.bottom
        anchors.topMargin: Theme.pad
        anchors.bottom: hints.top
        anchors.left: parent.left
        anchors.right: parent.right
        contentHeight: sections.height
        clip: true

        Column {
            id: sections
            width: parent.width
            spacing: Theme.pad * 1.5

            // -- Recent games --
            Column {
                width: parent.width
                spacing: Theme.padSmall
                visible: MoonSettings.recentGames.length > 0

                Text {
                    x: Theme.screenMargin
                    text: qsTr("Jump back in")
                    color: Theme.text
                    font.pixelSize: Theme.fontH2
                    font.weight: Font.DemiBold
                }

                ListView {
                    id: recentList
                    width: parent.width
                    height: 240
                    orientation: ListView.Horizontal
                    spacing: Theme.pad
                    leftMargin: Theme.screenMargin
                    rightMargin: Theme.screenMargin
                    model: MoonSettings.recentGames
                    keyNavigationEnabled: true
                    focus: true
                    KeyNavigation.down: hostList.visible ? hostList : actionList

                    delegate: FocusButton {
                        width: 420; height: 200
                        icon: "🎮"
                        label: modelData.appName
                        sublabel: qsTr("on %1").arg(modelData.hostName)
                        focus: index === 0
                        onActivated: {
                            var idx = home.findHostIndex(modelData.hostName)
                            if (idx < 0) {
                                window.showError(qsTr("PC not found"),
                                    qsTr("%1 is not paired anymore.").arg(modelData.hostName))
                                return
                            }
                            var online = computerModel.data(computerModel.index(idx, 0), home.roleOnline)
                            var paired = computerModel.data(computerModel.index(idx, 0), home.rolePaired)
                            if (!online || !paired) {
                                home.openHost(idx, modelData.hostName, online, paired)
                                return
                            }
                            window.pushView("qrc:/moon/qml/LibraryView.qml", {
                                computerIndex: idx,
                                hostName: modelData.hostName,
                                autoLaunchAppId: modelData.appId
                            })
                        }
                    }
                }
            }

            // -- PCs --
            Column {
                width: parent.width
                spacing: Theme.padSmall

                Text {
                    x: Theme.screenMargin
                    text: qsTr("Your PCs")
                    color: Theme.text
                    font.pixelSize: Theme.fontH2
                    font.weight: Font.DemiBold
                }

                ListView {
                    id: hostList
                    width: parent.width
                    height: 250
                    visible: count > 0
                    orientation: ListView.Horizontal
                    spacing: Theme.pad
                    leftMargin: Theme.screenMargin
                    rightMargin: Theme.screenMargin
                    model: computerModel
                    keyNavigationEnabled: true
                    focus: !recentList.visible
                    KeyNavigation.up: recentList.visible ? recentList : null
                    KeyNavigation.down: actionList

                    delegate: HostCard {
                        name: model.name
                        online: model.online
                        paired: model.paired
                        busy: model.busy
                        statusUnknown: model.statusUnknown
                        focus: index === 0
                        onActivated: home.openHost(index, model.name, model.online, model.paired)
                        onOptionsRequested: home.hostOptions(index, model.name)
                    }
                }

                // Empty state
                Rectangle {
                    visible: hostList.count === 0
                    x: Theme.screenMargin
                    width: parent.width - Theme.screenMargin * 2
                    height: 200
                    radius: Theme.radius
                    color: Theme.panel
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.padSmall
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("No PCs yet")
                            color: Theme.text
                            font.pixelSize: Theme.fontH2
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Install Sunshine on your gaming PC, then choose Pair PC below.")
                            color: Theme.textDim
                            font.pixelSize: Theme.fontBody
                        }
                    }
                }
            }

            // -- Quick actions --
            ListView {
                id: actionList
                width: parent.width
                height: 116
                orientation: ListView.Horizontal
                spacing: Theme.pad
                leftMargin: Theme.screenMargin
                rightMargin: Theme.screenMargin
                keyNavigationEnabled: true
                KeyNavigation.up: hostList.visible ? hostList : (recentList.visible ? recentList : null)
                interactive: false

                model: [
                    { icon: "🔗", label: qsTr("Pair PC"), action: "pair" },
                    { icon: "⚙", label: qsTr("Settings"), action: "settings" },
                    { icon: "⏻", label: qsTr("Power"), action: "power" }
                ]

                delegate: FocusButton {
                    width: 320; height: 100
                    icon: modelData.icon
                    label: modelData.label
                    focus: index === 0
                    onActivated: {
                        if (modelData.action === "pair")
                            window.pushView("qrc:/moon/qml/PairView.qml")
                        else if (modelData.action === "settings")
                            window.pushView("qrc:/moon/qml/SettingsHubView.qml")
                        else
                            window.powerMenu()
                    }
                }
            }
        }
    }

    HintBar {
        id: hints
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.pad
        anchors.horizontalCenter: parent.horizontalCenter
        hints: [
            { button: "A", label: qsTr("Select") },
            { button: "X", label: qsTr("PC options") },
            { button: "☰", label: qsTr("Navigate") }
        ]
    }
}
