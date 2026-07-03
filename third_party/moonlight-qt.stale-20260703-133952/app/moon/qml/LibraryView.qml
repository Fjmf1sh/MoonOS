import QtQuick 2.15
import QtQuick.Controls 2.15

import ComputerManager 1.0
import AppModel 1.0
import MoonOS 1.0

// Library: the selected PC's games/apps, straight from the moonlight-qt
// AppModel (box art included). Launching pushes StreamView with a native
// Session object.
FocusScope {
    id: library

    property int computerIndex: -1
    property string hostName: ""
    // When set (>0), launch this app as soon as the model has it — used by
    // the Home screen's "Jump back in" row.
    property int autoLaunchAppId: 0
    property bool autoLaunched: false

    // AppModel role values (Qt::UserRole + n, fixed in the fork)
    readonly property int roleAppId: 260

    AppModel {
        id: appModel
        Component.onCompleted: initialize(ComputerManager, library.computerIndex, false)
        onComputerLost: {
            // Host went away mid-browse: bail out gracefully.
            if (stackView.currentItem === library) {
                stackView.pop()
                window.showError(qsTr("Lost contact with %1").arg(library.hostName),
                    qsTr("The PC went offline. Check that it is awake and Sunshine is running."))
            }
        }
    }

    Connections {
        target: ComputerManager
        function onQuitAppCompleted(error) {
            quitDialog.close()
            if (error) {
                window.showError(qsTr("Couldn't stop the running game"), error)
                library.pendingLaunchIndex = -1
            } else if (library.pendingLaunchIndex >= 0) {
                var idx = library.pendingLaunchIndex
                library.pendingLaunchIndex = -1
                library.launch(idx)
            }
        }
    }

    property int pendingLaunchIndex: -1
    MoonDialog { id: quitDialog }

    function launch(appIndex) {
        var appName = appModel.data(appModel.index(appIndex, 0), 256)
        var runningId = appModel.getRunningAppId()
        var appId = appModel.data(appModel.index(appIndex, 0), roleAppId)

        if (runningId !== 0 && runningId !== appId) {
            pendingLaunchIndex = appIndex
            window.confirm(qsTr("%1 is already running").arg(appModel.getRunningAppName()),
                qsTr("It has to stop before starting %1.").arg(appName),
                qsTr("Stop it and play"),
                function() {
                    quitDialog.showBusy(qsTr("Stopping %1…").arg(appModel.getRunningAppName()), "")
                    appModel.quitRunningApp()
                })
            return
        }

        var session = appModel.createSessionForApp(appIndex)
        MoonSettings.addRecentGame(library.hostName, library.hostName, appId, appName)
        window.pushView("qrc:/moon/qml/StreamView.qml", {
            session: session,
            appName: appName,
            isResume: runningId === appId
        })
    }

    function filteredIndexIsVisible(name) {
        return searchText === "" || name.toLowerCase().indexOf(searchText.toLowerCase()) >= 0
    }
    property string searchText: ""

    Column {
        anchors.fill: parent
        anchors.margins: Theme.screenMargin
        spacing: Theme.pad

        Row {
            width: parent.width
            spacing: Theme.pad

            Text {
                text: library.hostName
                color: Theme.text
                font.pixelSize: Theme.fontTitle
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: library.searchText !== ""
                text: qsTr("filter: %1").arg(library.searchText)
                color: Theme.accent
                font.pixelSize: Theme.fontBody
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        GridView {
            id: grid
            width: parent.width
            height: parent.height - y
            clip: true
            cellWidth: 290
            cellHeight: 420
            keyNavigationEnabled: true
            focus: true
            model: appModel

            delegate: Item {
                width: grid.cellWidth
                height: grid.cellHeight
                visible: library.filteredIndexIsVisible(model.name)

                GameCard {
                    anchors.centerIn: parent
                    name: model.name
                    boxArt: model.boxart
                    running: model.running
                    focus: index === 0
                    onActivated: library.launch(index)
                }

                // Auto-launch hook for "Jump back in"
                Component.onCompleted: {
                    if (!library.autoLaunched &&
                        library.autoLaunchAppId > 0 &&
                        model.appid === library.autoLaunchAppId) {
                        library.autoLaunched = true
                        Qt.callLater(function() { library.launch(index) })
                    }
                }
            }

            Keys.onPressed: function(event) {
                // Y/Start (Qt::Key_Hangup via SdlGamepadKeyNavigation) opens the filter
                if (event.key === Qt.Key_Hangup || event.key === Qt.Key_Slash) {
                    window.textPrompt(qsTr("Filter games"), qsTr("Type part of a name"), false,
                        function(text) { library.searchText = text })
                    event.accepted = true
                }
            }
        }
    }

    // Loading / empty states
    Column {
        anchors.centerIn: parent
        spacing: Theme.pad
        visible: grid.count === 0

        MoonSpinner { anchors.horizontalCenter: parent.horizontalCenter }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Fetching games from %1…").arg(library.hostName)
            color: Theme.textDim
            font.pixelSize: Theme.fontBody
        }
    }

    HintBar {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.pad
        anchors.horizontalCenter: parent.horizontalCenter
        hints: [
            { button: "A", label: qsTr("Play") },
            { button: "Y", label: qsTr("Filter") },
            { button: "B", label: qsTr("Back") }
        ]
    }
}
