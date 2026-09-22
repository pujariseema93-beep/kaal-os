/* KAAL OS Calamares Installation Slideshow (QML)
 * Slides shown during installation. Each slide displays for ~15 seconds.
 * Replace slide images with final artwork.
 */

import QtQuick 2.3

Item {
    id: slideshow
    anchors.fill: parent

    // Slide definitions
    property var slides: [
        {
            title: "Welcome to KAAL OS",
            subtitle: "Kaal Autonomous Artificial Intelligence Operating System",
            description: "A Fedora-based Linux distribution designed for gamers, developers, power users, and everyday computing.",
            color: "#4A90D9"
        },
        {
            title: "Kaal Spaces",
            subtitle: "One System, Many Faces",
            description: "Switch between Gaming, Development, Power User, and Normal spaces instantly. Each space adapts your CPU, GPU, audio, and desktop to the task at hand.",
            color: "#9B59B6"
        },
        {
            title: "Built for Gaming",
            subtitle: "Maximum Performance",
            description: "GameMode, MangoHud, Steam, Lutris, Bottles — all pre-configured. Low-latency audio, GPU acceleration, and network QoS for competitive gaming.",
            color: "#FF6B35"
        },
        {
            title: "Developer Ready",
            subtitle: "Code, Build, Deploy",
            description: "Docker, Podman, Distrobox, VS Code, and terminal tools out of the box. Balanced power profile for long compile sessions.",
            color: "#2ECC71"
        },
        {
            title: "Hardware Support",
            subtitle: "NVIDIA, AMD, Intel",
            description: "Automatic GPU detection and configuration. NVIDIA RTX 40-series and above, AMD GPUs, and Intel CPUs from 2015 onwards fully supported.",
            color: "#4A90D9"
        },
        {
            title: "Auto-Update",
            subtitle: "Always Up to Date",
            description: "KAAL OS checks for updates at every boot. Your system stays secure and current without manual intervention.",
            color: "#FF6B35"
        },
        {
            title: "Secure & Private",
            subtitle: "Your System, Your Rules",
            description: "Built on Fedora's hardened security foundation. Firewalld, SELinux enforcing, and privacy-respecting by design.",
            color: "#2ECC71"
        },
        {
            title: "Installation Complete",
            subtitle: "Welcome to KAAL OS",
            description: "Your system is ready. Choose your first KAAL Space and start your journey.",
            color: "#4A90D9"
        }
    ]

    property int currentSlide: 0

    // Background
    Rectangle {
        anchors.fill: parent
        color: "#0d0d0d"
    }

    // Slide content
    Column {
        anchors.centerIn: parent
        spacing: 16
        width: parent.width * 0.7

        // Accent line
        Rectangle {
            width: 60
            height: 4
            radius: 2
            color: slides[currentSlide].color
        }

        // Title
        Text {
            text: slides[currentSlide].title
            font.pixelSize: 32
            font.weight: Font.Bold
            color: "#ffffff"
            width: parent.width
            wrapMode: Text.WordWrap
        }

        // Subtitle
        Text {
            text: slides[currentSlide].subtitle
            font.pixelSize: 18
            color: slides[currentSlide].color
            width: parent.width
            wrapMode: Text.WordWrap
        }

        // Spacer
        Item { height: 12; width: 1 }

        // Description
        Text {
            text: slides[currentSlide].description
            font.pixelSize: 14
            color: "#888888"
            width: parent.width
            wrapMode: Text.WordWrap
            lineHeight: 1.5
        }
    }

    // Progress dots
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 40
        spacing: 10

        Repeater {
            model: slides.length
            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: index === currentSlide ? "#4A90D9" : "#333"
            }
        }
    }

    // Auto-advance timer
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: {
            if (currentSlide < slides.length - 1) {
                currentSlide++
            } else {
                currentSlide = 0
            }
        }
    }

    // KAAL OS logo text (top)
    Text {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 30
        text: "KAAL OS"
        font.pixelSize: 14
        font.weight: Font.Bold
        color: "#333333"
        letterSpacing: 4
    }
}
