import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: page
    property var ctl
    property var fonts: ({})

    readonly property var roles: [
        { key: "main", label: "Main font", desc: "Interface text, e.g. Rubik" },
        { key: "numbers", label: "Numbers family", desc: "Digits in clocks and stats, e.g. Rubik" },
        { key: "title", label: "Title family", desc: "Headings, e.g. Gabarito" },
        { key: "mono", label: "Monospace font", desc: "Terminal, e.g. JetBrains Mono NF" },
        { key: "icons", label: "Nerd font icons", desc: "Symbols, e.g. JetBrains Mono NF" },
        { key: "reading", label: "Reading font", desc: "Descriptions, e.g. Readex Pro" }
    ]

    // ---------- switches and system services (rice-services) ----------
    property var sv: ({ have: {}, units: [] })
    property string busy: ""
    readonly property var switches: [
        { k: "wifi", n: "Wi-Fi", g: "\uf1eb", need: "nmcli" },
        { k: "bluetooth", n: "Bluetooth", g: "\uf294", need: "bluetoothctl" },
        { k: "sound", n: "Sound", g: "\uf028", need: "wpctl", offText: "Muted" },
        { k: "mic", n: "Microphone", g: "\uf130", need: "wpctl", offText: "Muted" },
        { k: "network", n: "Networking", g: "\uf0e8", need: "nmcli" },
        { k: "airplane", n: "Airplane mode", g: "\uf072", need: "nmcli" },
        { k: "dnd", n: "Do Not Disturb", g: "\uf1f6", need: "swaync-client" },
        { k: "awake", n: "Keep awake", g: "\uf0f4", need: "" },
        { k: "nightlight", n: "Night light", g: "\uf186", need: "hyprsunset" }
    ]
    function svSet(k, on) {
        const n = Object.assign({}, sv); n[k] = on
        if (k === "airplane") { n.wifi = !on; n.bluetooth = !on }
        sv = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-services\" set \"$1\" \"$2\"", "_", k, on ? "on" : "off"])
        page.ctl.status = (on ? "On: " : "Off: ") + k
        svRefresh.restart()
    }
    function unit(name, action) {
        busy = name
        unitProc.command = ["bash", "-c", "\"$HOME/.local/bin/rice-services\" unit \"$1\" \"$2\" 2>&1", "_", name, action]
        unitProc.running = true
    }
    Process {
        id: svProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-services\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.sv = JSON.parse(text) } catch (e) { } } }
    }
    Timer { id: svRefresh; interval: 1200; onTriggered: svProc.running = true }
    Timer { interval: 5000; running: page.visible; repeat: true; onTriggered: if (!svProc.running) svProc.running = true }
    Process {
        id: unitProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.ctl.status = text.trim().length > 0 ? text.trim().split("\n").pop() : "Done"
                page.busy = ""
                svProc.running = true
            }
        }
    }

    // ---------- blur & transparency, gaming mode (rice-effects) ----------
    property var fx: ({ lite: false, gaming: false, flat: false, opts: {} })
    function fxOpt(k) { return !!(fx.opts && fx.opts[k] === true) }
    function fxRun(args, msg) {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-effects\" \"$@\"", "_"].concat(args))
        page.ctl.status = msg
        fxRefresh.restart()
    }
    function setLite(on) {
        const n = JSON.parse(JSON.stringify(fx)); n.lite = on; fx = n
        fxRun(["lite", on ? "on" : "off"], on ? "Light mode on" : "Light mode off")
    }
    function setGaming(on) {
        const n = JSON.parse(JSON.stringify(fx)); n.gaming = on; fx = n
        fxRun(["gaming", on ? "on" : "off"], "Gaming mode " + (on ? "on" : "off"))
    }
    function setOpt(k, on) {
        const n = JSON.parse(JSON.stringify(fx)); if (!n.opts) n.opts = {}; n.opts[k] = on; fx = n
        fxRun(["set", k, on ? "on" : "off"], "Gaming mode: saved")
    }
    Process {
        id: fxProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-effects\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.fx = JSON.parse(text) } catch (e) { } } }
    }
    Timer { id: fxRefresh; interval: 1500; onTriggered: if (!fxProc.running) fxProc.running = true }
    Timer { interval: 4000; running: page.visible; repeat: true; onTriggered: if (!fxProc.running) fxProc.running = true }

    function applyFont(key, value) {
        setProc.command = ["bash", "-c", "\"$HOME/.local/bin/font-set\" set \"$1\" \"$2\" 2>&1", "_", key, value]
        setProc.running = true
    }

    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/font-set\" state"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { page.fonts = JSON.parse(text) } catch (e) { } }
        }
    }
    Process {
        id: setProc
        stdout: StdioCollector {
            onStreamFinished: {
                page.ctl.status = text.trim()
                refresh.restart()
            }
        }
    }
    Process {
        id: resetProc
        command: ["bash", "-c", "\"$HOME/.local/bin/font-set\" reset 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.ctl.status = text.trim()
                refresh.restart()
            }
        }
    }
    Timer { id: refresh; interval: 500; onTriggered: stateProc.running = true }

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

            SectionTitle { topPadding: 0; text: "Switches"; sub: "Turn things on and off for this computer. Night light needs hyprsunset." }
            Grid {
                id: swGrid
                width: parent.width
                columns: 3
                spacing: 10
                Repeater {
                    model: page.switches
                    delegate: Rectangle {
                        id: tile
                        readonly property bool avail: modelData.need === "" || (page.sv.have && page.sv.have[modelData.need] === true)
                        readonly property bool on: page.sv[modelData.k] === true
                        width: (swGrid.width - 20) / 3
                        height: 74
                        radius: 14
                        opacity: avail ? 1 : 0.45
                        color: tm.containsMouse && avail ? "#1c1c1c" : "#141414"
                        border.width: 1
                        border.color: on ? "#4a4a4a" : "#1f1f1f"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            x: 14; anchors.verticalCenter: parent.verticalCenter
                            width: 40; height: 40; radius: 12
                            color: tile.on ? "#F6F5F4" : "#202020"
                            Behavior on color { ColorAnimation { duration: 200 } }
                            T { kind: "icon"; anchors.centerIn: parent; text: modelData.g; font.pixelSize: 16; color: tile.on ? "#0d0d0d" : "#F6F5F4" }
                        }
                        Column {
                            x: 66; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 66 - 60
                            spacing: 2
                            T { text: modelData.n; font.pixelSize: 13; font.bold: true; width: parent.width; elide: Text.ElideRight }
                            T {
                                kind: "reading"
                                text: !tile.avail ? "Not installed" : (tile.on ? "On" : (modelData.offText || "Off"))
                                font.pixelSize: 11
                                color: "#8a8a8a"
                            }
                        }
                        Sw {
                            anchors.right: parent.right; anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            checked: tile.on
                        }
                        MouseArea {
                            id: tm
                            anchors.fill: parent
                            enabled: tile.avail
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.svSet(modelData.k, !tile.on)
                        }
                    }
                }
            }
            SliderRow {
                visible: page.sv.have && page.sv.have.hyprsunset === true
                label: "Night light warmth"
                desc: "Lower is warmer (more orange)"
                from: 2500; to: 6500; step: 100; unit: " K"
                value: page.sv.night_temp || 4500
                onCommitted: function(x) {
                    Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-services\" night-temp \"$1\"", "_", String(Math.round(x))])
                    page.ctl.status = "Night light: " + Math.round(x) + " K"
                }
            }

            SectionTitle { text: "Gaming mode"; sub: "Also in the hot corner. Choose what stays on while you play." }
            Rectangle {
                width: col.width
                height: 74
                radius: 14
                color: gm.containsMouse ? "#1c1c1c" : "#141414"
                border.width: 1
                border.color: page.fx.gaming ? "#4a4a4a" : "#1f1f1f"
                Behavior on color { ColorAnimation { duration: 120 } }
                Rectangle {
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 44; height: 44; radius: 13
                    color: page.fx.gaming ? "#F6F5F4" : "#202020"
                    Behavior on color { ColorAnimation { duration: 200 } }
                    T { kind: "icon"; anchors.centerIn: parent; text: "\uf11b"; font.pixelSize: 18; color: page.fx.gaming ? "#0d0d0d" : "#F6F5F4" }
                }
                Column {
                    x: 72; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 72 - 70
                    spacing: 2
                    T { text: "Gaming mode"; font.pixelSize: 14; font.bold: true }
                    T {
                        kind: "reading"; font.pixelSize: 11; color: "#8a8a8a"; width: parent.width; elide: Text.ElideRight
                        text: page.fx.gaming ? "On: everything you did not keep below is off" : "Off. Turns off animations, blur, transparency, shadows and gaps"
                    }
                }
                Sw { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; checked: page.fx.gaming === true }
                MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.setGaming(!(page.fx.gaming === true)) }
            }
            ToggleRow { label: "Keep blur & transparency"; desc: "Off: everything is solid while you play (faster)"; checked: page.fxOpt("keep_blur"); onToggled: function(v) { page.setOpt("keep_blur", v) } }
            ToggleRow { label: "Keep animations"; desc: "Windows and workspaces still animate"; checked: page.fxOpt("keep_anim"); onToggled: function(v) { page.setOpt("keep_anim", v) } }
            ToggleRow { label: "Keep shadows"; desc: "Shadows under windows"; checked: page.fxOpt("keep_shadows"); onToggled: function(v) { page.setOpt("keep_shadows", v) } }
            ToggleRow { label: "Keep gaps"; desc: "Space between windows and around the screen"; checked: page.fxOpt("keep_gaps"); onToggled: function(v) { page.setOpt("keep_gaps", v) } }
            ToggleRow { label: "Do Not Disturb"; desc: "No notification popups while gaming mode is on"; checked: page.fxOpt("dnd"); onToggled: function(v) { page.setOpt("dnd", v) } }
            ToggleRow { label: "Dashboard at the bottom edge"; desc: "Off: the pointer at the bottom of the screen does not open the dashboard while you play"; checked: page.fxOpt("edge"); onToggled: function(v) { page.setOpt("edge", v) } }

            SectionTitle { text: "System services"; sub: "Background services. Start and stop ask for your password for system services." }
            Repeater {
                model: page.sv.units || []
                delegate: Rectangle {
                    width: col.width
                    height: 64
                    radius: 14
                    color: "#141414"
                    border.width: 1
                    border.color: "#1f1f1f"
                    Rectangle {
                        x: 18; anchors.verticalCenter: parent.verticalCenter
                        width: 9; height: 9; radius: 4.5
                        color: modelData.active ? "#7bd88f" : "#5a5a5a"
                    }
                    Column {
                        x: 38; anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Row {
                            spacing: 8
                            T { text: modelData.label; font.pixelSize: 14; font.bold: true }
                            T { kind: "mono"; text: modelData.name; font.pixelSize: 10; color: "#6a6a72"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        T { kind: "reading"; text: (modelData.active ? "Running" : "Stopped") + "  ·  " + modelData.desc; font.pixelSize: 11; color: "#8a8a8a" }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Btn {
                            text: page.busy === modelData.name ? "..." : (modelData.active ? "Stop" : "Start")
                            onClicked: page.unit(modelData.name, modelData.active ? "stop" : "start")
                        }
                        Btn {
                            visible: modelData.active
                            text: "Restart"
                            onClicked: page.unit(modelData.name, "restart")
                        }
                    }
                }
            }
            T {
                visible: (page.sv.units || []).length === 0
                text: "No services found (systemd is needed for this list)."
                font.pixelSize: 12
                color: "#7a7a84"
            }

            T { kind: "title"; text: "Fonts"; font.pixelSize: 16; font.bold: true; topPadding: 18 }
            T {
                width: parent.width
                kind: "reading"
                text: "Type the name of an installed font family and press Enter. Applies to the settings window, desktop widgets and kitty (monospace)."
                color: "#8a8a8a"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: page.roles
                delegate: SettingRow {
                    reserved: 270
                    label: modelData.label
                    desc: modelData.desc
                    Field {
                        id: fld
                        width: 240
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.fonts[modelData.key] !== undefined ? page.fonts[modelData.key] : ""
                        placeholder: "Font family"
                        onAccepted: page.applyFont(modelData.key, text)
                    }
                }
            }

            Row {
                spacing: 8
                Pill { label: "Reset fonts"; onClicked: resetProc.running = true }
            }

            T { kind: "title"; text: "Autostart"; font.pixelSize: 16; font.bold: true; topPadding: 18 }

            AutostartPage { width: parent.width; ctl: page.ctl }
        }
    }

    component Sw: Rectangle {
        property bool checked: false
        width: 40; height: 22; radius: 11
        color: checked ? "#F6F5F4" : "#2a2a2a"
        Behavior on color { ColorAnimation { duration: 160 } }
        Rectangle {
            width: 16; height: 16; radius: 8; y: 3
            x: parent.checked ? parent.width - width - 3 : 3
            color: parent.checked ? "#0d0d0d" : "#8a8a8a"
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }
}
