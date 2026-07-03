import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import MoonOS 1.0

// "Welcome to Moon OS" first-boot wizard. Each step is skippable; the heavy
// lifting (Wi-Fi, Bluetooth, pairing) reuses the exact settings screens so
// there is a single code path for every feature.
FocusScope {
    id: wizard

    // Back button must not dump the user out of an unfinished setup.
    readonly property bool backLocked: true

    property int step: 0
    readonly property var steps: [
        { key: "welcome",    title: qsTr("Welcome to Moon OS") },
        { key: "controller", title: qsTr("Connect a controller") },
        { key: "network",    title: qsTr("Get online") },
        { key: "display",    title: qsTr("Fit your TV") },
        { key: "audio",      title: qsTr("Sound") },
        { key: "pair",       title: qsTr("Pair your gaming PC") },
        { key: "done",       title: qsTr("All set") }
    ]

    function next() {
        if (step === steps.length - 1) {
            MoonSettings.setupComplete = true
            stackView.replace(null, "qrc:/moon/qml/HomeView.qml")
            return
        }
        step++
        // Ethernet users don't need the Wi-Fi step
        if (steps[step].key === "network" && NetworkService.ethernetConnected)
            step++
        nextBtn.forceActiveFocus()
    }

    function back() {
        if (step > 0)
            step--
        nextBtn.forceActiveFocus()
    }

    // Auto-onboard controllers for the entire wizard: from the very first
    // screen we power on Bluetooth, reconnect known pads, and auto-pair any
    // new controller held in pairing mode. This solves the chicken-and-egg
    // of needing input to set up input — the user just holds the pair button.
    // (USB controllers work immediately via SDL and need nothing here.)
    Component.onCompleted: BluetoothService.startControllerAutoConnect()
    Component.onDestruction: BluetoothService.stopControllerAutoConnect()

    Column {
        anchors.centerIn: parent
        width: parent.width * 0.62
        spacing: Theme.pad * 1.5

        // Step dots
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            Repeater {
                model: wizard.steps.length
                Rectangle {
                    width: index === wizard.step ? 30 : 12
                    height: 12; radius: 6
                    color: index <= wizard.step ? Theme.accent : Theme.panelHigh
                    Behavior on width { NumberAnimation { duration: Theme.animFast } }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: wizard.steps[wizard.step].title
            color: Theme.text
            font.pixelSize: Theme.fontTitle
            font.weight: Font.Bold
        }

        // ---- step body ----
        Item {
            width: parent.width
            height: 320

            // Welcome
            Column {
                visible: wizard.steps[wizard.step].key === "welcome"
                anchors.centerIn: parent
                width: parent.width
                spacing: Theme.pad
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🌕"
                    font.pixelSize: 110
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Your TV is about to become a game streaming console.\nA few quick steps and you'll be playing.")
                    color: Theme.textDim
                    font.pixelSize: Theme.fontBody
                    wrapMode: Text.Wrap
                }
            }

            // Controller
            Column {
                visible: wizard.steps[wizard.step].key === "controller"
                anchors.centerIn: parent
                width: parent.width
                spacing: Theme.pad

                readonly property bool haveController: BluetoothService.connectedControllerCount > 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.haveController ? "🎮" : "🔍"
                    font.pixelSize: 90
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: parent.haveController
                          ? qsTr("Controller connected — you're good to go!")
                          : qsTr("Hold your controller's pair button until it flashes.\nMoon OS is searching and will connect it automatically.")
                    color: parent.haveController ? Theme.success : Theme.text
                    font.pixelSize: Theme.fontBody
                    wrapMode: Text.Wrap
                }

                // Live search indicator + what's been found so far
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.padSmall
                    visible: !parent.haveController
                    MoonSpinner { width: 34; height: 34; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: BluetoothService.discovering ? qsTr("Searching for controllers…")
                                                           : qsTr("Starting Bluetooth…")
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSmall
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("A USB controller, keyboard, or your TV remote (HDMI-CEC) also works — no pairing needed.")
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSmall
                    wrapMode: Text.Wrap
                }

                FocusButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 440; height: 90
                    label: qsTr("Pair manually")
                    sublabel: qsTr("If it doesn't connect on its own")
                    onActivated: window.pushView("qrc:/moon/qml/BluetoothSettingsView.qml")
                    KeyNavigation.down: nextBtn
                }
            }

            // Network
            Column {
                visible: wizard.steps[wizard.step].key === "network"
                anchors.centerIn: parent
                width: parent.width
                spacing: Theme.pad
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "📡"
                    font.pixelSize: 90
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: NetworkService.online
                          ? qsTr("Connected — %1").arg(NetworkService.ethernetConnected
                                ? qsTr("wired network") : NetworkService.currentSsid)
                          : qsTr("Game streaming loves a wired connection, but 5 GHz Wi-Fi works great too.")
                    color: NetworkService.online ? Theme.success : Theme.textDim
                    font.pixelSize: Theme.fontBody
                    wrapMode: Text.Wrap
                }
                FocusButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 440; height: 90
                    label: qsTr("Set up Wi-Fi")
                    onActivated: window.pushView("qrc:/moon/qml/NetworkSettingsView.qml")
                    KeyNavigation.down: nextBtn
                }
            }

            // Display: safe area calibration
            Column {
                visible: wizard.steps[wizard.step].key === "display"
                anchors.centerIn: parent
                width: parent.width
                spacing: Theme.pad
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Shrink the picture until you can see all four corners of the frame, then continue.\nResolution can be changed later in Settings → Display.")
                    color: Theme.textDim
                    font.pixelSize: Theme.fontBody
                    wrapMode: Text.Wrap
                }
                SliderRow {
                    width: parent.width
                    label: qsTr("Safe area")
                    from: 80; to: 100; step: 1
                    suffix: "%"
                    value: MoonSettings.safeAreaPct
                    onChanged: function(v) { MoonSettings.safeAreaPct = v }
                    focus: true
                    KeyNavigation.down: nextBtn
                }
            }

            // Audio
            Column {
                visible: wizard.steps[wizard.step].key === "audio"
                anchors.centerIn: parent
                width: parent.width
                spacing: Theme.pad
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Where should game sound come out?")
                    color: Theme.textDim
                    font.pixelSize: Theme.fontBody
                }
                OptionRow {
                    width: parent.width
                    label: qsTr("Sound output")
                    options: {
                        var names = []
                        for (var i = 0; i < DisplayService.audioOutputs.length; i++)
                            names.push(DisplayService.audioOutputs[i].name)
                        return names.length ? names : [qsTr("Automatic")]
                    }
                    onChanged: function(i) {
                        if (DisplayService.audioOutputs.length > i)
                            DisplayService.setAudioOutput(DisplayService.audioOutputs[i].device)
                    }
                    KeyNavigation.down: nextBtn
                }
            }

            // Pair PC
            Column {
                visible: wizard.steps[wizard.step].key === "pair"
                anchors.centerIn: parent
                width: parent.width
                spacing: Theme.pad
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🖥"
                    font.pixelSize: 90
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Install Sunshine on your gaming PC (free, from the LizardByte project), then pair it here.")
                    color: Theme.textDim
                    font.pixelSize: Theme.fontBody
                    wrapMode: Text.Wrap
                }
                FocusButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 440; height: 90
                    label: qsTr("Pair my PC")
                    onActivated: window.pushView("qrc:/moon/qml/PairView.qml")
                    KeyNavigation.down: nextBtn
                }
            }

            // Done
            Column {
                visible: wizard.steps[wizard.step].key === "done"
                anchors.centerIn: parent
                width: parent.width
                spacing: Theme.pad
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "🚀"
                    font.pixelSize: 110
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Moon OS is ready. Have fun!")
                    color: Theme.textDim
                    font.pixelSize: Theme.fontBody
                }
            }
        }

        // ---- nav buttons ----
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.pad

            FocusButton {
                id: backBtn
                visible: wizard.step > 0
                width: 260; height: 90
                label: qsTr("Back")
                KeyNavigation.right: nextBtn
                onActivated: wizard.back()
            }
            FocusButton {
                id: nextBtn
                width: 320; height: 90
                label: wizard.step === wizard.steps.length - 1 ? qsTr("Start")
                     : wizard.step === 0 ? qsTr("Let's go")
                     : qsTr("Continue")
                focus: true
                KeyNavigation.left: backBtn.visible ? backBtn : null
                onActivated: wizard.next()
            }
        }
    }

    HintBar {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.pad
        anchors.horizontalCenter: parent.horizontalCenter
        hints: [
            { button: "A", label: qsTr("Select") },
            { button: "☰", label: qsTr("Navigate") }
        ]
    }
}
