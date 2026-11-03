import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Item {
    id: page
    property var ctl
    // the "Make it yours" cards (the Settings tour points at them)
    property alias quickArea: quick

    readonly property string home: Quickshell.env("HOME")
    readonly property string user: Quickshell.env("USER")
    readonly property string faceUrl: "file://" + home + "/.face"
    property date now: new Date()
    property string uptime: ""
    property int tip: 0
    readonly property var tips: [
        "Press SUPER + U anywhere to open these settings.",
        "SUPER + W opens the wallpaper menu. The Auto theme follows your new wallpaper.",
        "Drag the desktop widgets anywhere, their position is saved.",
        "Pick a scheme in Theme to recolor the bar, borders, notifications and lock screen.",
        "Choose the bar style in Bar settings.",
        "Idle & Lockscreen decides when the screen locks and when the computer sleeps.",
        "Click your picture in the sidebar to change it. It is also shown on the lock screen.",
        "Touch the bottom-right corner of the screen for quick toggles, apps and wallpapers.",
        "Type right away in the hot corner's Apps search and press Enter to launch.",
        "Keep Awake in the hot corner stops the screen from locking during a movie.",
        "Gaming mode turns off animations, blur and gaps. Click it again to bring them back.",
        "Notifications has nine popup styles. Try Island or Accent bar.",
        "Theme has 21 color schemes, from pure Mono to Ocean and Rose.",
        "Lock screen clocks come in Big, Stacked and Minimal. Preview them in Idle & Lockscreen.",
        "Run rice-notify test in a terminal to see a sample notification.",
        "Many settings are also commands: rice-hotcorner, rice-lock, rice-notify."
    ]
    function greeting() {
        const h = now.getHours()
        return h < 5 ? "Good night" : (h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening"))
    }
    function themeName() {
        const l = page.ctl.schemes || []
        for (let i = 0; i < l.length; i++) if (l[i].key === page.ctl.colorMode) return l[i].name
        return page.ctl.colorMode
    }

    // Light mode (rice-effects lite): for slower computers
    property bool lite: false
    function setLite(on) {
        lite = on
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-effects\" lite \"$1\"", "_", on ? "on" : "off"])
        page.ctl.status = "Light mode " + (on ? "on" : "off")
    }
    Process {
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-effects\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.lite = JSON.parse(text).lite === true } catch (e) { } } }
    }

    Timer { interval: 15000; running: true; repeat: true; onTriggered: page.now = new Date() }
    Timer { interval: 7000; running: true; repeat: true; onTriggered: tipFade.restart() }
    Process {
        id: upProc
        command: ["bash", "-c", "cut -d. -f1 /proc/uptime"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const t = parseInt(text.trim())
                if (isNaN(t)) return
                const d = Math.floor(t / 86400), h = Math.floor(t % 86400 / 3600), m = Math.floor(t % 3600 / 60)
                page.uptime = (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + m + "m"
            }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: upProc.running = true }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentY {
            enabled: !flick.dragging && !flick.flicking
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(e) {
                const max = Math.max(0, flick.contentHeight - flick.height)
                flick.contentY = Math.max(0, Math.min(max, flick.contentY - e.angleDelta.y * 0.6))
            }
        }

        Column {
            id: col
            x: 24
            y: 28
            width: flick.width - 48
            spacing: 12

            // the logo, moving: the moon floats and sways, the stars twinkle (your picture is in the sidebar)
            MoonLogo {
                id: homeLogo
                objectName: "homeLogo"
                anchors.horizontalCenter: parent.horizontalCenter
                size: 136
                running: page.visible
            }

            T {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.greeting() + ", " + page.user
                font.pixelSize: 26
                font.bold: true
            }
            T {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.now.toLocaleDateString(Qt.locale("en_US"), "dddd, d MMMM") + "  \u00b7  " + page.now.toLocaleTimeString(Qt.locale("en_US"), "HH:mm")
                color: "#8a8a8a"
                font.pixelSize: 13
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                topPadding: 2
                bottomPadding: 6
                Repeater {
                    model: [
                        { i: "\udb80\udfd8", t: "Theme \u00b7 " + page.themeName() },
                        { i: "\uf017", t: "Up " + page.uptime },
                        { i: page.ctl.osGlyph(), t: page.ctl.osName }
                    ]
                    delegate: Rectangle {
                        visible: modelData.t.length > 3
                        height: 30
                        width: chip.implicitWidth + 26
                        radius: 15
                        color: "#141414"
                        border.width: 1
                        border.color: "#222222"
                        Row {
                            id: chip
                            anchors.centerIn: parent
                            spacing: 7
                            T { kind: "icon"; text: modelData.i; font.pixelSize: 12; color: "#c8c8cc"; anchors.verticalCenter: parent.verticalCenter }
                            T { text: modelData.t; font.pixelSize: 12; color: "#c8c8cc"; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 84
                radius: 16
                border.width: 1
                border.color: "#222222"
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#1a1922" }
                    GradientStop { position: 1; color: "#121214" }
                }
                Rectangle {
                    id: bulb
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46; height: 46; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.06)
                    T { kind: "icon"; anchors.centerIn: parent; text: "\uf0eb"; font.pixelSize: 20 }
                }
                Column {
                    id: tipCol
                    anchors.left: bulb.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    T { text: "Make yourself at home"; font.pixelSize: 14; font.bold: true }
                    T { kind: "reading"; width: parent.width; text: page.tips[page.tip]; color: "#9a9aa4"; font.pixelSize: 12; wrapMode: Text.WordWrap }
                }
                SequentialAnimation {
                    id: tipFade
                    NumberAnimation { target: tipCol; property: "opacity"; to: 0; duration: 220 }
                    ScriptAction { script: page.tip = (page.tip + 1) % page.tips.length }
                    NumberAnimation { target: tipCol; property: "opacity"; to: 1; duration: 320 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tipFade.restart() }
            }

            // Light mode: one switch for slower computers, right on Home
            Rectangle {
                // found by the search in the sidebar
                property string label: "Light mode"
                property string desc: "Running slow? Turn off blur, transparency and shadows, animations stay; performance"
                property real reserved: 80
                width: parent.width
                height: 76
                radius: 14
                color: "#141414"
                border.width: 1
                border.color: page.lite ? "#4a4a4f" : "#1f1f1f"
                Behavior on border.color { ColorAnimation { duration: 160 } }
                Rectangle {
                    id: litei
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40; radius: 12
                    color: Qt.rgba(1, 1, 1, page.lite ? 0.14 : 0.06)
                    T { kind: "icon"; anchors.centerIn: parent; text: "\uf0e7"; font.pixelSize: 17 }
                }
                Column {
                    anchors.left: litei.right
                    anchors.leftMargin: 12
                    anchors.right: litetog.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    T { text: "Light mode"; font.pixelSize: 13; font.bold: true }
                    T { kind: "reading"; text: "Running slow? No blur or shadows, widgets rest when a window covers them. Animations stay"; color: "#8a8a8a"; font.pixelSize: 11; width: parent.width; wrapMode: Text.WordWrap }
                }
                Tog {
                    id: litetog
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    checked: page.lite
                    onToggled: function(v) { page.setLite(v) }
                }
            }

            // the falling stars across this window
            Rectangle {
                property string label: "Falling stars"
                property string desc: "Comets falling across this window; turn them off for a calm look"
                property real reserved: 80
                width: parent.width
                height: 64
                radius: 14
                color: "#141414"
                border.width: 1
                border.color: "#1f1f1f"
                Rectangle {
                    id: starsi
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36; radius: 11
                    color: Qt.rgba(1, 1, 1, page.ctl.stars ? 0.12 : 0.06)
                    T { kind: "icon"; anchors.centerIn: parent; text: "\uf005"; font.pixelSize: 15 }
                }
                Column {
                    anchors.left: starsi.right
                    anchors.leftMargin: 12
                    anchors.right: starstog.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    T { text: "Falling stars"; font.pixelSize: 13; font.bold: true }
                    T { kind: "reading"; text: "Comets falling across this window"; color: "#8a8a8a"; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight }
                }
                Tog {
                    id: starstog
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    checked: page.ctl.stars
                    onToggled: function(v) { page.ctl.setStars(v) }
                }
            }

            T { kind: "title"; text: "Make it yours"; font.pixelSize: 16; font.bold: true; topPadding: 10 }

            Flow {
                id: quick
                width: parent.width
                spacing: 10
                Repeater {
                    model: [
                        { i: "\udb80\udfd8", t: "Theme", d: "Colors & schemes", p: 6 },
                        { i: "\uf03e", t: "Wallpaper", d: "Pick a new one", p: -1 },
                        { i: "\uf0f3", t: "Notifications", d: "Popups & panel", p: 8 },
                        { i: "\uf023", t: "Lock screen", d: "Idle & lock", p: 9 },
                        { i: "\uf0c9", t: "Bar", d: "Choose the bar style", p: 2 }
                    ]
                    delegate: Rectangle {
                        width: (quick.width - 20) / 3
                        height: 76
                        radius: 14
                        color: qMouse.containsMouse ? "#1b1b1d" : "#141414"
                        border.width: 1
                        border.color: qMouse.containsMouse ? "#333333" : "#1f1f1f"
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Rectangle {
                            id: qi
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40; height: 40; radius: 12
                            color: Qt.rgba(1, 1, 1, 0.06)
                            T { kind: "icon"; anchors.centerIn: parent; text: modelData.i; font.pixelSize: 17 }
                        }
                        Column {
                            anchors.left: qi.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            T { text: modelData.t; font.pixelSize: 13; font.bold: true; width: parent.width; elide: Text.ElideRight }
                            T { kind: "reading"; text: modelData.d; font.pixelSize: 11; color: "#8a8a8a"; width: parent.width; elide: Text.ElideRight }
                        }
                        MouseArea {
                            id: qMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.p >= 0) page.ctl.page = modelData.p
                                else Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-wallpaper\""])
                            }
                        }
                    }
                }
            }

        }
    }
}
