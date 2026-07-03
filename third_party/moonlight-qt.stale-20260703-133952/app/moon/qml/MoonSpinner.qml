import QtQuick 2.15

// Minimal loading indicator: an orbiting moon dot. Deliberately subtle —
// loading states should feel calm, not busy.
Item {
    id: root
    property bool running: visible
    width: 64; height: 64

    Rectangle {
        anchors.centerIn: parent
        width: 6; height: 6; radius: 3
        color: Theme.textDim
    }

    Item {
        id: orbit
        anchors.fill: parent
        Rectangle {
            width: 14; height: 14; radius: 7
            color: Theme.accent
            anchors.horizontalCenter: parent.horizontalCenter
        }
        RotationAnimation on rotation {
            running: root.running
            loops: Animation.Infinite
            from: 0; to: 360
            duration: 900
        }
    }
}
