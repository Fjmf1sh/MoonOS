import QtQuick 2.15
import QtQuick.Controls 2.15

import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0
import Session 1.0
import SystemProperties 1.0
import MoonOS 1.0

// Runs a native streaming session (moonlight-qt Session object created by
// AppModel/ComputerModel). Adapted from the upstream StreamSegue flow:
// the Qt window hides while the SDL/KMS session owns the display, and this
// view resolves back to the shell when the session ends.
//
// All session errors surface as friendly text with a retry path; raw
// details are appended only in developer mode.
FocusScope {
    id: streamView

    property Session session
    property string appName: ""
    property bool isResume: false

    // Never let Back pop this view while a session is live — the session
    // teardown drives navigation instead.
    readonly property bool backLocked: true

    property string stageText: isResume ? qsTr("Resuming %1…").arg(appName)
                                        : qsTr("Starting %1…").arg(appName)
    property string errorText: ""
    property string errorDetail: ""

    function friendlyStageError(stage, errorCode, failingPorts) {
        errorDetail = qsTr("Stage \"%1\" failed with error %2").arg(stage).arg(errorCode)
        if (failingPorts)
            errorDetail += qsTr(" (ports: %1)").arg(failingPorts)

        if (failingPorts)
            return qsTr("Your network is blocking the stream. Check the firewall and port forwarding on your PC for: %1").arg(failingPorts)
        return qsTr("The stream couldn't start. Make sure Sunshine is running on the PC and try again.")
    }

    function stageStarting(stage) {
        stageText = qsTr("Starting %1…").arg(stage)
    }

    function stageFailed(stage, errorCode, failingPorts) {
        errorText = friendlyStageError(stage, errorCode, failingPorts)
    }

    function connectionStarted() {
        // Hide the shell window; SDL/KMS owns the display now.
        loadingUi.visible = false
        window.visible = false
    }

    function displayLaunchError(text) {
        errorText = qsTr("The PC refused to start the stream.")
        errorDetail = text
    }

    function quitStarting() {
        stageText = qsTr("Stopping %1…").arg(appName)
        loadingUi.visible = true
        window.visible = true
    }

    function sessionFinished(portTestResult) {
        SdlGamepadKeyNavigation.enable()
        ComputerManager.startPolling()
        window.visible = true

        if (errorText !== "") {
            // Swap to the error panel; user leaves via its buttons.
            loadingUi.visible = false
            errorUi.visible = true
            errorUi.forceActiveFocus()
        } else {
            stackView.pop()
        }
    }

    function sessionReadyForDeletion() {
        session = null
        gc()
    }

    StackView.onActivated: {
        session.stageStarting.connect(stageStarting)
        session.stageFailed.connect(stageFailed)
        session.connectionStarted.connect(connectionStarted)
        session.displayLaunchError.connect(displayLaunchError)
        session.quitStarting.connect(quitStarting)
        session.sessionFinished.connect(sessionFinished)
        session.readyForDeletion.connect(sessionReadyForDeletion)

        // The SystemProperties async loader may still hold the SDL video
        // subsystem — wait before the session claims it (upstream behavior).
        SystemProperties.waitForAsyncLoad()

        // Host polling would fight the stream for bandwidth.
        ComputerManager.stopPollingAsync()

        streamLoader.active = true
    }

    Timer {
        id: startSessionTimer
        interval: 150
        onTriggered: {
            gc()
            session.start()
        }
    }

    Loader {
        id: streamLoader
        active: false
        asynchronous: true
        sourceComponent: Item {}

        onLoaded: {
            // The in-stream gamepad belongs to the session, not UI nav.
            SdlGamepadKeyNavigation.disable()

            if (!session.initialize(window)) {
                sessionFinished(0)
                sessionReadyForDeletion()
                return
            }
            startSessionTimer.start()
        }
    }

    // ---- loading UI ----------------------------------------------------------

    Column {
        id: loadingUi
        anchors.centerIn: parent
        spacing: Theme.pad

        MoonSpinner { anchors.horizontalCenter: parent.horizontalCenter; width: 96; height: 96 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: streamView.stageText
            color: Theme.text
            font.pixelSize: Theme.fontH1
            font.weight: Font.DemiBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Hold Start + Select + L1 + R1 to leave the stream")
            color: Theme.textDim
            font.pixelSize: Theme.fontBody
        }
    }

    // ---- friendly error UI ----------------------------------------------------

    FocusScope {
        id: errorUi
        anchors.fill: parent
        visible: false

        Column {
            anchors.centerIn: parent
            spacing: Theme.pad
            width: parent.width * 0.6

            MIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "dark_mode"
                size: 80
                color: Theme.accent
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Couldn't stream %1").arg(streamView.appName)
                color: Theme.text
                font.pixelSize: Theme.fontH1
                font.weight: Font.Bold
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: streamView.errorText
                color: Theme.textDim
                font.pixelSize: Theme.fontBody
                wrapMode: Text.Wrap
            }

            Text {
                visible: MoonSettings.developerMode && streamView.errorDetail !== ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: streamView.errorDetail
                color: Theme.warning
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.Wrap
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.pad

                FocusButton {
                    id: backBtn
                    width: 300; height: 90
                    label: qsTr("Back to Home")
                    focus: true
                    KeyNavigation.right: netBtn
                    onActivated: stackView.pop()
                }
                FocusButton {
                    id: netBtn
                    width: 300; height: 90
                    label: qsTr("Network settings")
                    KeyNavigation.left: backBtn
                    onActivated: {
                        stackView.pop()
                        window.pushView("qrc:/moon/qml/NetworkSettingsView.qml")
                    }
                }
            }
        }

        Keys.onEscapePressed: stackView.pop()
    }
}
