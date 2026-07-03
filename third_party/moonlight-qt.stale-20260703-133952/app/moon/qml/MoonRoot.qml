import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0
import MoonOS 1.0

// Moon OS shell root. Owns the window, the navigation stack, the global
// error dialog and text entry, and routes the very first screen
// (recovery / setup wizard / home).
ApplicationWindow {
    id: window

    visible: true
    visibility: Window.FullScreen
    title: "Moon OS"
    color: "#000000"

    // ---- global helpers available to every view via context ----------------

    function pushView(url, props) {
        stackView.push(url, props || {})
    }

    // Friendly error surface. detail is only shown in developer mode.
    function showError(title, message, detail, retryAction) {
        var msg = message
        if (detail && MoonSettings.developerMode)
            msg += "\n\n" + qsTr("Details: %1").arg(detail)
        var buttons = []
        if (retryAction)
            buttons.push({ label: qsTr("Try again"), action: retryAction })
        buttons.push({ label: qsTr("Close"), action: function() {} })
        errorDialog.show(title, msg, buttons)
    }

    function confirm(title, message, yesLabel, action, destructive) {
        errorDialog.show(title, message, [
            { label: yesLabel, action: action, destructive: destructive === true },
            { label: qsTr("Cancel"), action: function() {} }
        ])
    }

    // Arbitrary button set (max ~4 for focus ergonomics)
    function confirmDialogButtons(title, message, buttons) {
        errorDialog.show(title, message, buttons)
    }

    function textPrompt(title, placeholder, isPassword, callback) {
        textEntry.prompt(title, placeholder, isPassword, callback)
    }

    function powerMenu() {
        errorDialog.show(qsTr("Power"), "", [
            { label: qsTr("Power off"), action: function() { MoonSystem.powerOff() }, destructive: true },
            { label: qsTr("Restart"), action: function() { MoonSystem.reboot() } },
            { label: qsTr("Cancel"), action: function() {} }
        ])
    }

    // ---- backdrop -----------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.bgTop }
            GradientStop { position: 1.0; color: Theme.bgBottom }
        }

        // Soft moon glow in the top-right corner
        Repeater {
            model: 4
            Rectangle {
                readonly property real r: 140 + index * 90
                x: parent.width * 0.86 - r / 2
                y: parent.height * 0.12 - r / 2
                width: r; height: r; radius: r / 2
                color: Theme.accent
                opacity: 0.05 - index * 0.01
            }
        }
        Rectangle {
            x: parent.width * 0.86 - 60
            y: parent.height * 0.12 - 60
            width: 120; height: 120; radius: 60
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#e8ecff" }
                GradientStop { position: 1.0; color: "#aab8e8" }
            }
            opacity: 0.9
        }
    }

    // ---- safe area + content stack -----------------------------------------

    Item {
        id: safeArea
        anchors.fill: parent
        scale: MoonSettings.safeAreaPct / 100.0

        StackView {
            id: stackView
            anchors.fill: parent

            pushEnter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animMed }
                NumberAnimation { property: "x"; from: 60; to: 0; duration: Theme.animMed; easing.type: Easing.OutCubic }
            }
            pushExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animFast }
            }
            popEnter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animMed }
                NumberAnimation { property: "x"; from: -60; to: 0; duration: Theme.animMed; easing.type: Easing.OutCubic }
            }
            popExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animFast }
            }
        }

        // Back (Escape / gamepad B) pops the stack when nothing else ate it.
        // The wizard and stream views set backLocked to keep users out of
        // half-configured states.
        Keys.onEscapePressed: function(event) {
            if (stackView.depth > 1 && !(stackView.currentItem && stackView.currentItem.backLocked === true))
                stackView.pop()
            else
                event.accepted = false
        }
    }

    // ---- global overlays ----------------------------------------------------

    MoonDialog { id: errorDialog }
    TextEntryDialog { id: textEntry }

    // ---- boot ----------------------------------------------------------------

    Component.onCompleted: {
        // Gamepad → key-event navigation for the entire shell (reused from
        // the upstream moonlight-qt UI layer).
        SdlGamepadKeyNavigation.enable()

        // Keep host state fresh while the shell is visible; stream views
        // pause polling during a session.
        ComputerManager.startPolling()

        if (MoonSettings.recoveryMode)
            stackView.push("qrc:/moon/qml/RecoveryView.qml")
        else if (!MoonSettings.setupComplete)
            stackView.push("qrc:/moon/qml/SetupWizardView.qml")
        else
            stackView.push("qrc:/moon/qml/HomeView.qml")
    }
}
