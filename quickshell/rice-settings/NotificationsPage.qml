import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: page
    property var ctl
    property var ns: ({})

    function v(k, d) { return ns[k] !== undefined ? ns[k] : d }
    function norm(value) { return value === "on" ? true : value === "off" ? false : value }
    function setv(key, value) {
        const n = Object.assign({}, ns)
        n[key] = page.norm(value)
        ns = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-notify\" set \"$1\" \"$2\"", "_", key, String(value)])
        page.ctl.status = "Applied"
        refresh.restart()
    }
    function famFor(k) {
        return k === "sans" ? "Inter" : k === "rounded" ? "Rubik" : k === "mono" ? "JetBrainsMono Nerd Font" : ""
    }
    function preview(name, vol) {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-sound\" play \"$1\" \"$2\"", "_", name, String(vol)])
    }
    function tool(arg) { Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-notify\" \"$1\"", "_", arg]) }

    Process {
        id: stateProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-notify\" state"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.ns = JSON.parse(text) } catch (e) { } } }
    }
    Timer { id: refresh; interval: 800; onTriggered: stateProc.running = true }

    PageScroll {
        anchors.fill: parent

        // ---------- live preview ----------
        Rectangle {
            id: stage
            width: parent.width
            height: 170
            radius: 16
            clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#1b1a22" }
                GradientStop { position: 1; color: "#0e0f12" }
            }
            border.width: 1
            border.color: "#1f1f1f"

            T {
                anchors.centerIn: parent
                text: "Preview"
                color: Qt.rgba(1, 1, 1, 0.06)
                font.pixelSize: 44
                font.bold: true
            }

            PopupMock {
                id: mock
                look: page.v("popup_style", "glass")
                acc: page.v("accent", true) ? page.v("accent_color", "#d4d4d4") : "#F6F5F4"
                accFg: page.v("accent", true) ? page.v("on_accent", "#0d0d0d") : "#0d0d0d"
                baseRadius: page.v("radius", 18) * 0.85
                pop: page.v("popup_opacity", 0.85)
                surface: page.v("colors", "graphite")
                edge: page.v("border", "subtle")
                shadowOn: page.v("shadow", false) === true
                fam: page.famFor(page.v("font", "sans"))
                fs: page.v("font_size", 13) / 13
                iconSize: Math.max(26, Math.min(46, page.v("icon_size", 40)))
                width: Math.min(stage.width - 28, page.v("popup_width", 360) * 0.85)
                height: (look === "pill" || look === "minimal") ? 56 : 78
                x: page.v("pos_x", "right") === "left" ? 14 : (page.v("pos_x", "right") === "center" ? (stage.width - width) / 2 : stage.width - width - 14)
                y: page.v("pos_y", "top") === "top" ? 14 : stage.height - height - 14
                Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 180 } }
            }
        }

        Row {
            spacing: 10
            Btn { primary: true; icon: ""; text: "Send test notification"; onClicked: page.tool("test") }
        }

        // ---------- position ----------
        SectionTitle { text: "Position"; sub: "Where popups appear." }
        SegRow {
            label: "Horizontal"
            desc: "Side of the screen"
            options: [{ label: "Left", value: "left" }, { label: "Middle", value: "center" }, { label: "Right", value: "right" }]
            current: page.v("pos_x", "right")
            onChosen: function(x) { page.setv("pos_x", x) }
        }
        SegRow {
            label: "Vertical"
            desc: "Top or bottom edge"
            options: [{ label: "Top", value: "top" }, { label: "Bottom", value: "bottom" }]
            current: page.v("pos_y", "top")
            onChosen: function(x) { page.setv("pos_y", x) }
        }
        // ---------- popups ----------
        SectionTitle { text: "Popups"; sub: "The small cards that appear when something arrives." }
        Flow {
            id: styles
            width: parent.width
            spacing: 10
            Repeater {
                model: [
                    { k: "glass", n: "Glass" }, { k: "solid", n: "Solid" },
                    { k: "minimal", n: "Minimal" }, { k: "pill", n: "Pill" }, { k: "accent", n: "Accent bar" },
                    { k: "glow", n: "Glow" }, { k: "island", n: "Island" }, { k: "light", n: "Light" }
                ]
                delegate: Rectangle {
                    readonly property bool on: page.v("popup_style", "glass") === modelData.k
                    width: (styles.width - 20) / 3
                    height: 96
                    radius: 14
                    color: "#141414"
                    border.width: on ? 2 : 1
                    border.color: on ? "#F6F5F4" : (sMouse.containsMouse ? "#3a3a3a" : "#2a2a2a")
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    Rectangle {
                        x: 8; y: 8
                        width: parent.width - 16; height: 56
                        radius: 9
                        clip: true
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#2a2836" }
                            GradientStop { position: 1; color: "#15161a" }
                        }
                        PopupMock {
                            anchors.centerIn: parent
                            width: parent.width - 16
                            height: (look === "pill" || look === "minimal") ? 30 : 38
                            look: modelData.k
                            acc: page.v("accent", true) ? page.v("accent_color", "#d4d4d4") : "#F6F5F4"
                            accFg: page.v("on_accent", "#0d0d0d")
                            baseRadius: Math.min(12, page.v("radius", 18) * 0.6)
                            pop: page.v("popup_opacity", 0.85)
                            surface: page.v("colors", "graphite")
                            edge: page.v("border", "subtle")
                            shadowOn: false
                            fam: page.famFor(page.v("font", "sans"))
                            iconSize: 22
                            showBody: false
                            fs: 0.8
                        }
                    }
                    T {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 70
                        text: modelData.n
                        font.pixelSize: 12
                        font.bold: on
                    }
                    MouseArea {
                        id: sMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.setv("popup_style", modelData.k)
                    }
                }
            }
        }
        SliderRow {
            label: "Width"
            from: 260; to: 600; step: 10; unit: " px"
            value: page.v("popup_width", 360)
            onCommitted: function(x) { page.setv("popup_width", Math.round(x)) }
        }
        SliderRow {
            label: "Time on screen"
            desc: "Seconds before a popup hides"
            from: 2; to: 30; step: 1; unit: " s"
            value: page.v("timeout", 6)
            onCommitted: function(x) { page.setv("timeout", Math.round(x)) }
        }
        ToggleRow { label: "Keep urgent ones"; desc: "Critical notifications stay until you close them"; checked: page.v("critical_sticky", true) === true; onToggled: function(x) { page.setv("critical_sticky", x ? "on" : "off") } }
        SliderRow {
            label: "Icon size"
            from: 20; to: 72; step: 2; unit: " px"
            value: page.v("icon_size", 40)
            onCommitted: function(x) { page.setv("icon_size", Math.round(x)) }
        }
        ToggleRow { label: "Show images"; desc: "Album covers, screenshots and avatars"; checked: page.v("images", true) === true; onToggled: function(x) { page.setv("images", x ? "on" : "off") } }

        // ---------- style ----------
        SectionTitle { text: "Colors"; sub: "Base color of popups. Popup styles Island and Light keep their own." }
        SegRow {
            label: "Surface"
            options: [{ label: "Black", value: "black" }, { label: "Graphite", value: "graphite" }, { label: "Slate", value: "slate" },
                      { label: "White", value: "white" }, { label: "Tinted", value: "tinted" }]
            current: page.v("colors", "graphite")
            onChosen: function(x) { page.setv("colors", x) }
        }
        ToggleRow { label: "Accent color"; desc: "Buttons, switches and icons follow your Theme"; checked: page.v("accent", true) === true; onToggled: function(x) { page.setv("accent", x ? "on" : "off") } }
        SegRow {
            label: "Border"
            desc: "Edge around popups"
            options: [{ label: "Subtle", value: "subtle" }, { label: "Accent", value: "accent" }, { label: "None", value: "none" }]
            current: page.v("border", "subtle")
            onChosen: function(x) { page.setv("border", x) }
        }
        ToggleRow { label: "Shadow"; desc: "Small shadow under popups (off looks cleaner)"; checked: page.v("shadow", false) === true; onToggled: function(x) { page.setv("shadow", x ? "on" : "off") } }

        SectionTitle { text: "Font" }
        SegRow {
            label: "Font"
            desc: "Sans uses Inter, Rounded uses Rubik (they fall back if missing)"
            options: [{ label: "Sans", value: "sans" }, { label: "Rounded", value: "rounded" }, { label: "Mono", value: "mono" }, { label: "System", value: "system" }]
            current: page.v("font", "sans")
            onChosen: function(x) { page.setv("font", x) }
        }
        SliderRow {
            label: "Text size"
            from: 10; to: 18; step: 1; unit: " px"
            value: page.v("font_size", 13)
            onCommitted: function(x) { page.setv("font_size", Math.round(x)) }
        }

        SectionTitle { text: "Transparency & blur"; sub: "Blur only shows where the surface is transparent." }
        SliderRow {
            label: "Popup opacity"
            desc: "Lower is more see-through"
            from: 0.3; to: 1.0; step: 0.02; decimals: 2
            value: page.v("popup_opacity", 0.85)
            onCommitted: function(x) { page.setv("popup_opacity", x.toFixed(2)) }
        }
        ToggleRow { label: "Blur popups"; desc: "Blur the desktop behind popups"; checked: page.v("blur_popups", true) === true; onToggled: function(x) { page.setv("blur_popups", x ? "on" : "off") } }

        Row {
            spacing: 10
            topPadding: 8
            Btn { text: "Reset"; onClicked: { page.tool("reset"); page.ctl.status = "Notifications reset"; refresh.restart() } }
        }
    }
}
