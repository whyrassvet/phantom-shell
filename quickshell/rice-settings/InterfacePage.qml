import QtQuick

Item {
    id: page
    property var ctl

    function dv(k, d) {
        const c = page.ctl.dst.dock
        return c && c[k] !== undefined ? c[k] : d
    }
    function lv(k) {
        const c = page.ctl.dst.lock
        return !!(c && c[k] === true)
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 24
        anchors.topMargin: 6
        contentWidth: width
        contentHeight: col.implicitHeight + 24
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
            width: flick.width
            spacing: 10

            T { kind: "title"; text: "Dock"; font.pixelSize: 16; font.bold: true }

            // live preview of the dock
            Rectangle {
                width: parent.width
                height: 150
                radius: 16
                clip: true
                border.width: 1
                border.color: "#1f1f1f"
                gradient: Gradient {
                    GradientStop { position: 0; color: "#2b2840" }
                    GradientStop { position: 1; color: "#14141c" }
                }
                Rectangle { x: 40; y: 26; width: 180; height: 60; radius: 10; color: Qt.rgba(1, 1, 1, 0.07) }
                Rectangle { x: parent.width - 260; y: 18; width: 200; height: 76; radius: 10; color: Qt.rgba(1, 1, 1, 0.05) }
                Rectangle {
                    id: mockDock
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    readonly property real sizeScale: Math.max(1, Math.min(2, Number(page.dv("scale", 1)) || 1))
                    width: icons.width + 20 * sizeScale
                    height: 52 * sizeScale
                    radius: 20 * sizeScale
                    visible: page.dv("enabled", false) === true
                    color: page.dv("background", true) === false ? "transparent"
                         : Qt.rgba(0.1, 0.1, 0.11, Number(page.dv("opacity", 0.78)))
                    border.width: page.dv("background", true) === false ? 0 : 1
                    border.color: Qt.rgba(1, 1, 1, 0.07)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Row {
                        id: icons
                        anchors.centerIn: parent
                        spacing: 8 * mockDock.sizeScale
                        Repeater {
                            model: ["#e06c75", "#61afef", "#e5c07b", "#98c379", "#c678dd", "#56b6c2"]
                            delegate: Rectangle {
                                width: 34 * mockDock.sizeScale; height: width; radius: 10 * mockDock.sizeScale
                                color: page.dv("tint", false) === true ? "#9a9aa4" : modelData
                                opacity: 0.9
                            }
                        }
                    }
                }
                T {
                    anchors.centerIn: parent
                    visible: page.dv("enabled", false) !== true
                    text: "Dock is off"
                    color: "#8a8a94"
                    font.pixelSize: 13
                }
                T {
                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
                    visible: page.dv("enabled", false) === true && page.dv("blur", true) === true && page.dv("background", true) !== false
                    text: "blur on"
                    color: "#8a8a94"
                    font.pixelSize: 10
                }
            }

            ToggleRow {
                label: "Enable"
                desc: "A minimal dock with your apps at the bottom of the screen"
                checked: page.dv("enabled", false) === true
                onToggled: function(v) { page.ctl.dset("dock", "enabled", v ? "on" : "off") }
            }
            ToggleRow {
                label: "Background"
                desc: "Draw a panel behind the icons"
                checked: page.dv("background", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "background", v ? "on" : "off") }
            }
            SliderRow {
                label: "Size"
                desc: "Scale the dock and its icons"
                from: 1; to: 2; step: 0.1; decimals: 1
                value: Number(page.dv("scale", 1))
                onCommitted: function(x) { page.ctl.dset("dock", "scale", x.toFixed(1)) }
            }
            SliderRow {
                label: "Opacity"
                desc: "Lower is more see-through"
                from: 0.2; to: 1.0; step: 0.02; decimals: 2
                value: Number(page.dv("opacity", 0.78))
                onCommitted: function(x) { page.ctl.dset("dock", "opacity", x.toFixed(2)) }
            }
            ToggleRow {
                label: "Blur"
                desc: "Blur the desktop behind the dock"
                checked: page.dv("blur", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "blur", v ? "on" : "off") }
            }
            ToggleRow {
                label: "Hover to reveal"
                desc: "Hide the dock and slide it in when the pointer touches the bottom edge"
                checked: page.dv("hover", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "hover", v ? "on" : "off") }
            }
            ToggleRow {
                label: "Pinned on startup"
                desc: "Start with the dock held open"
                checked: page.dv("pinnedStartup", false) === true
                onToggled: function(v) { page.ctl.dset("dock", "pinnedStartup", v ? "on" : "off") }
            }

            T { kind: "title"; text: "Buttons"; font.pixelSize: 16; font.bold: true; topPadding: 8 }

            ToggleRow {
                label: "Media player"
                desc: "Show the current track in the dock"
                checked: page.dv("media", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "media", v ? "on" : "off") }
            }
            ToggleRow {
                label: "Show pin button"
                desc: "Button that holds the dock open"
                checked: page.dv("pinButton", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "pinButton", v ? "on" : "off") }
            }
            ToggleRow {
                label: "Show apps button"
                desc: "Button that opens the app launcher"
                checked: page.dv("appsButton", true) === true
                onToggled: function(v) { page.ctl.dset("dock", "appsButton", v ? "on" : "off") }
            }
            ToggleRow {
                label: "Tint app icons"
                desc: "Paint icons in a single neutral tone"
                checked: page.dv("tint", false) === true
                onToggled: function(v) { page.ctl.dset("dock", "tint", v ? "on" : "off") }
            }

            T {
                width: parent.width
                topPadding: 14
                text: "Lock screen options moved to Idle & Lockscreen."
                color: "#8a8a8a"
                font.pixelSize: 12
            }
        }
    }
}
