import QtQuick 2.15

// Animated Moon OS backdrop: deep-space gradient, a field of twinkling stars,
// occasional shooting stars, and the moon — which drifts to a new pose each
// time you move to another screen (driven via nextPose()).
//
// Everything here is cheap, GPU-composited Qt Quick (plain Items + opacity /
// position animations), so it runs smoothly on a Pi 4's VideoCore.
Item {
    id: backdrop
    anchors.fill: parent

    // ---- moon pose ---------------------------------------------------------
    // Each pose is a fraction of the screen + a scale. nextPose() advances
    // through them so the moon "shifts around" as you navigate.
    readonly property var poses: [
        { x: 0.85, y: 0.15, s: 1.00 },
        { x: 0.16, y: 0.20, s: 0.72 },
        { x: 0.90, y: 0.55, s: 0.62 },
        { x: 0.13, y: 0.80, s: 0.85 },
        { x: 0.50, y: 0.12, s: 0.55 },
        { x: 0.82, y: 0.82, s: 0.70 }
    ]
    property int poseIndex: 0
    function nextPose() { poseIndex = (poseIndex + 1) % poses.length }

    readonly property real moonCenterX: width * poses[poseIndex].x
    readonly property real moonCenterY: height * poses[poseIndex].y
    readonly property real moonScale: poses[poseIndex].s

    // ---- gradient sky ------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.bgTop }
            GradientStop { position: 1.0; color: Theme.bgBottom }
        }
    }

    // ---- twinkling stars ---------------------------------------------------
    Repeater {
        model: 70
        delegate: Rectangle {
            // Random fractions are evaluated once (Math.random has no
            // dependencies), but position stays correct even if the backdrop
            // is sized after the delegate is created.
            readonly property real fx: Math.random()
            readonly property real fy: Math.random()
            property real baseOp: 0.25 + Math.random() * 0.65
            x: fx * backdrop.width
            y: fy * backdrop.height
            width: 1 + Math.random() * 2.4
            height: width
            radius: width / 2
            color: Math.random() > 0.85 ? Theme.accent : "#ffffff"
            opacity: baseOp

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: true
                PauseAnimation { duration: Math.round(Math.random() * 4000) }
                NumberAnimation { to: 0.08; duration: 700 + Math.round(Math.random() * 1600); easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.95; duration: 700 + Math.round(Math.random() * 1600); easing.type: Easing.InOutSine }
            }
        }
    }

    // ---- shooting stars ----------------------------------------------------
    Repeater {
        id: shootRepeater
        model: 2
        delegate: Item {
            id: shoot
            width: 0; height: 0
            opacity: 0
            z: 1

            // Tail streak (points back along -x; rotation aligns it to travel)
            Rectangle {
                x: -170; y: -1.5
                width: 170; height: 3
                radius: 1.5
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: "#ffffff" }
                }
            }
            // Bright head
            Rectangle {
                x: -2.5; y: -2.5
                width: 5; height: 5; radius: 2.5
                color: "#ffffff"
            }

            ParallelAnimation {
                id: anim
                NumberAnimation { id: xa; target: shoot; property: "x"; duration: 900; easing.type: Easing.InQuad }
                NumberAnimation { id: ya; target: shoot; property: "y"; duration: 900; easing.type: Easing.InQuad }
                SequentialAnimation {
                    NumberAnimation { target: shoot; property: "opacity"; from: 0.0; to: 1.0; duration: 180 }
                    NumberAnimation { target: shoot; property: "opacity"; to: 0.0; duration: 720 }
                }
            }

            function launch() {
                var startX = Math.random() * backdrop.width * 0.55
                var startY = -backdrop.height * 0.05
                var dx = backdrop.width * 0.45 + Math.random() * backdrop.width * 0.3
                var dy = dx * (0.45 + Math.random() * 0.2)
                shoot.rotation = Math.atan2(dy, dx) * 180 / Math.PI
                xa.from = startX; xa.to = startX + dx
                ya.from = startY; ya.to = startY + dy
                shoot.x = startX; shoot.y = startY
                anim.restart()
            }
        }
    }

    Timer {
        id: shootTimer
        interval: 3500
        running: true
        repeat: true
        onTriggered: {
            interval = 3000 + Math.round(Math.random() * 6000)
            var item = shootRepeater.itemAt(Math.floor(Math.random() * shootRepeater.count))
            if (item)
                item.launch()
        }
    }

    // ---- the moon ----------------------------------------------------------
    Item {
        id: moon
        width: 130 * backdrop.moonScale
        height: width
        x: backdrop.moonCenterX - width / 2
        y: backdrop.moonCenterY - height / 2
        z: 2

        Behavior on x { NumberAnimation { duration: 750; easing.type: Easing.InOutCubic } }
        Behavior on y { NumberAnimation { duration: 750; easing.type: Easing.InOutCubic } }
        Behavior on width { NumberAnimation { duration: 750; easing.type: Easing.InOutCubic } }

        // Soft glow (layered translucent circles — no GraphicalEffects dep)
        Repeater {
            model: 4
            delegate: Rectangle {
                readonly property real g: moon.width * (1.3 + index * 0.35)
                anchors.centerIn: disc
                width: g; height: g; radius: g / 2
                color: Theme.accent
                opacity: 0.06 - index * 0.012
            }
        }

        // Moon disc
        Rectangle {
            id: disc
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#eef1ff" }
                GradientStop { position: 1.0; color: "#9fb0e6" }
            }

            // Craters
            Rectangle {
                x: parent.width * 0.24; y: parent.height * 0.30
                width: parent.width * 0.17; height: width; radius: width / 2
                color: "#8595c9"; opacity: 0.55
            }
            Rectangle {
                x: parent.width * 0.55; y: parent.height * 0.52
                width: parent.width * 0.22; height: width; radius: width / 2
                color: "#8595c9"; opacity: 0.5
            }
            Rectangle {
                x: parent.width * 0.60; y: parent.height * 0.22
                width: parent.width * 0.10; height: width; radius: width / 2
                color: "#8595c9"; opacity: 0.45
            }

            // Gentle breathing shimmer so the moon feels alive when idle
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: true
                NumberAnimation { to: 0.9; duration: 2600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
            }
        }
    }
}
