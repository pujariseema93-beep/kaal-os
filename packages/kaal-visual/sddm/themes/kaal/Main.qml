/* KAAL OS SDDM Login Theme — QML
 * A clean, dark-themed login screen for KDE Plasma.
 * Replace background.png with your final login wallpaper (1920x1080).
 */

import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    anchors.fill: parent
    color: "#0d0d0d"

    // Background image
    Image {
        id: background
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.4

        // Fallback to solid color if image not found
        Rectangle {
            anchors.fill: parent
            color: "#0d0d0d"
            z: -1
        }
    }

    // Dark gradient overlay
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: "#CC0d0d0d" }
        }
    }

    // KAAL OS logo text (top center)
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.08
        spacing: 8

        Text {
            text: "KAAL OS"
            font.pixelSize: 36
            font.weight: Font.Bold
            color: "#ffffff"
            anchors.horizontalCenter: parent.horizontalCenter
            letterSpacing: 6
        }

        Text {
            text: "Kaal Autonomous Artificial Intelligence Operating System"
            font.pixelSize: 11
            color: "#666666"
            anchors.horizontalCenter: parent.horizontalCenter
            letterSpacing: 2
        }
    }

    // Login panel (centered)
    Rectangle {
        id: loginPanel
        width: 360
        height: 260
        anchors.centerIn: parent
        color: "#1a1a1a"
        radius: 16
        border.color: "#333"
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 16

            // Avatar / icon
            Rectangle {
                width: 64; height: 64
                radius: 32
                color: "#4A90D9"
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "👤"
                    font.pixelSize: 28
                }
            }

            // Username
            TextField {
                id: username
                width: 280
                height: 40
                text: userModel.lastUser
                font.pixelSize: 14
                color: "#ffffff"
                echoMode: TextInput.Normal
                selectByMouse: true

                background: Rectangle {
                    color: "#0d0d0d"
                    border.color: "#444"
                    border.width: 1
                    radius: 6
                }

                placeholderText: "Username"
                onAccepted: password.focus = true
            }

            // Password
            TextField {
                id: password
                width: 280
                height: 40
                font.pixelSize: 14
                color: "#ffffff"
                echoMode: TextInput.Password
                selectByMouse: true

                background: Rectangle {
                    color: "#0d0d0d"
                    border.color: "#444"
                    border.width: 1
                    radius: 6
                }

                placeholderText: "Password"
                onAccepted: sddm.login(username.text, password.text)
            }

            // Login button
            Rectangle {
                width: 280
                height: 40
                radius: 6
                color: loginMouseArea.containsMouse ? "#5AA0E9" : "#4A90D9"
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "Login"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: loginMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: sddm.login(username.text, password.text)
                }
            }
        }
    }

    // Session selector (bottom left)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 20
        width: sessionCol.width + 24
        height: sessionCol.height + 16
        color: "#1a1a1a"
        radius: 8
        opacity: 0.8

        Column {
            id: sessionCol
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: "Session"
                font.pixelSize: 9
                color: "#666"
            }

            ComboBox {
                id: session
                model: sessionModel
                index: sessionModel.lastIndex
                color: "#0d0d0d"
                textColor: "#fff"
                borderColor: "#444"
            }
        }
    }

    // Clock (bottom right)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 20
        width: clockCol.width + 24
        height: clockCol.height + 16
        color: "#1a1a1a"
        radius: 8
        opacity: 0.8

        Column {
            id: clockCol
            anchors.centerIn: parent
            spacing: 2

            Text {
                id: timeText
                font.pixelSize: 22
                font.weight: Font.Bold
                color: "#ffffff"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                id: dateText
                font.pixelSize: 10
                color: "#888"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                timeText.text = Qt.formatTime(new Date(), "hh:mm")
                dateText.text = Qt.formatDate(new Date(), "dddd, MMMM d")
            }
            Component.onCompleted: triggered()
        }
    }

    // Keyboard layout indicator (top right)
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        width: 60
        height: 30
        color: "#1a1a1a"
        radius: 6
        opacity: 0.8

        Text {
            anchors.centerIn: parent
            text: "EN"
            color: "#888"
            font.pixelSize: 12
            font.weight: Font.Bold
        }
    }

    // System buttons (bottom center)
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        spacing: 12

        // Reboot
        Rectangle {
            width: 40; height: 40; radius: 20
            color: "#1a1a1a"
            border.color: "#333"
            border.width: 1

            Text { anchors.centerIn: parent; text: "↻"; font.pixelSize: 18; color: "#888" }
            MouseArea { anchors.fill: parent; hoverEnabled: true;
                onEntered: parent.color = "#2a2a2a"
                onExited: parent.color = "#1a1a1a"
                onClicked: sddm.reboot() }
        }

        // Shutdown
        Rectangle {
            width: 40; height: 40; radius: 20
            color: "#1a1a1a"
            border.color: "#333"
            border.width: 1

            Text { anchors.centerIn: parent; text: "⏻"; font.pixelSize: 18; color: "#888" }
            MouseArea { anchors.fill: parent; hoverEnabled: true;
                onEntered: parent.color = "#2a2a2a"
                onExited: parent.color = "#1a1a1a"
                onClicked: sddm.powerOff() }
        }
    }
}
