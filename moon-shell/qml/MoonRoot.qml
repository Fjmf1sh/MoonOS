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

    SpaceBackdrop { id: backdrop; anchors.fill: parent }

    // ---- safe area + content stack -----------------------------------------

    Item {
        id: safeArea
        anchors.fill: parent
        scale: MoonSettings.safeAreaPct / 100.0

        StackView {
            id: stackView
            anchors.fill: parent
            focus: true

            // Whenever a new view becomes current, give it active focus so
            // keyboard / gamepad key-events actually reach it. Without this,
            // Qt receives input but no control is focused, so nothing moves.
            // Also drift the moon to a new pose on every screen change.
            onCurrentItemChanged: {
                if (currentItem) currentItem.forceActiveFocus()
                backdrop.nextPose()
            }

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

    // ---- TV-follow standby (HDMI-CEC) ---------------------------------------
    // With "Standby with my TV" on, a TV power-off blanks the console; selecting
    // this input again (or any key/controller/tap) brings it back. This replaces
    // the old manual "Wake TV" button you couldn't press when the TV was off.
    Rectangle {
        id: standbyScreen
        anchors.fill: parent
        color: "black"
        visible: false
        z: 100000

        function sleep() { visible = true; forceActiveFocus() }
        function wake() {
            if (!visible) return
            visible = false
            stackView.forceActiveFocus()
        }

        focus: visible
        Keys.onPressed: function(event) { standbyScreen.wake(); event.accepted = true }
        MouseArea { anchors.fill: parent; onClicked: standbyScreen.wake() }
    }

    Connections {
        target: CecService
        function onTvWentToStandby() { standbyScreen.sleep() }
        function onTvSelectedThisInput() { standbyScreen.wake() }
    }

    // ---- gamepad focus gating -----------------------------------------------

    // The SDL gamepad->key-event pump in moonlight-qt only polls while the
    // window reports focus. On the EGLFS console our single window is always
    // the focused surface, so "visible" is the right signal. StreamView hides
    // the window during a session, which correctly pauses shell gamepad nav.
    onVisibleChanged: SdlGamepadKeyNavigation.notifyWindowFocus(visible)
    onActiveChanged: SdlGamepadKeyNavigation.notifyWindowFocus(visible)

    // ---- boot ----------------------------------------------------------------

    Component.onCompleted: {
        // Gamepad → key-event navigation for the entire shell (reused from
        // the upstream moonlight-qt UI layer). UiNavMode=false makes the
        // D-pad/stick emit arrow keys (spatial navigation) rather than
        // Tab/Backtab, which is what our grid/list layouts expect.
        SdlGamepadKeyNavigation.enable()
        SdlGamepadKeyNavigation.setUiNavMode(false)

        // Start the gamepad polling timer immediately. Without this the timer
        // stays idle until an (often never-arriving) window-activation event,
        // leaving controllers dead on the first screen.
        SdlGamepadKeyNavigation.notifyWindowFocus(true)

        // Keep host state fresh while the shell is visible; stream views
        // pause polling during a session.
        ComputerManager.startPolling()

        if (MoonSettings.recoveryMode)
            stackView.push("qrc:/moon/qml/RecoveryView.qml")
        else if (!MoonSettings.setupComplete)
            stackView.push("qrc:/moon/qml/SetupWizardView.qml")
        else
            stackView.push("qrc:/moon/qml/HomeView.qml")

        // Make sure the freshly pushed view owns keyboard/gamepad focus.
        stackView.forceActiveFocus()
    }
}
