import Quickshell
import Quickshell.Io
import QtQuick

// Settings > Dashboard: the panel that drops out of the middle of the bar.
Item {
    id: page
    property var ctl
    property var dc: ({ tabs: [], bar: {} })

    readonly property var allTabs: [
        { k: "dashboard", n: "Dashboard", d: "Weather, you, clock, calendar, usage and music" },
        { k: "wallpaper", n: "Wallpaper", d: "Every wallpaper, search, random and color schemes" },
        { k: "performance", n: "Performance", d: "CPU, GPU, storage, network, memory and battery" },
        { k: "about", n: "About", d: "This computer, your distro and Phantom Shell" }
    ]
    readonly property var looks: [
        { k: "shadow", n: "Shadow", d: "Black glass, colors from your wallpaper" },
        { k: "graphite", n: "Graphite", d: "Soft grey, your accent color" },
        { k: "aurora", n: "Aurora", d: "Deep, tinted by your wallpaper" },
        { k: "frost", n: "Frost", d: "Light frosted glass" }
    ]
    function v(k, d) { return dc[k] !== undefined ? dc[k] : d }
    function setv(k, val) {
        const n = Object.assign({}, dc); n[k] = val; dc = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" set \"$1\" \"$2\"", "_", k, String(val === true ? "on" : val === false ? "off" : val)])
        page.ctl.status = "Dashboard: saved"
        reload.restart()
    }
    function setTabs(list) {
        const n = Object.assign({}, dc); n.tabs = list; dc = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" tabs \"$1\"", "_", list.join(",")])
        reload.restart()
    }
    function tabRows() {
        const on = (dc.tabs || []).slice()
        return on.concat(allTabs.map(function(t) { return t.k }).filter(function(k) { return on.indexOf(k) < 0 }))
    }
    function info(k) { for (let i = 0; i < allTabs.length; i++) if (allTabs[i].k === k) return allTabs[i]; return { n: k, d: "" } }
    function editTab(tab) { Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" open \"$1\" --edit", "_", tab]); Qt.quit() }
    function openNow(tab) { Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" open \"$1\" --no-toggle", "_", tab || ""]) }

    Process {
        id: cfgProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" config"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.dc = JSON.parse(text) } catch (e) { } } }
    }
    Timer { id: reload; interval: 700; onTriggered: cfgProc.running = true }

    PageScroll {
        anchors.fill: parent

        // ---------- hero ----------
        Rectangle {
            width: parent.width
            height: 200
            radius: 16
            clip: true
            border.width: 1
            border.color: "#1f1f1f"
            gradient: Gradient {
                GradientStop { position: 0; color: "#2a2740" }
                GradientStop { position: 1; color: "#101117" }
            }
            // the bar and the panel hanging from its middle

            DashMini {
                id: hero
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - height + 6
                width: 300; height: 160
                look: page.v("style", "shadow")
                acc: page.v("accent", "#9ec9bd")
                Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
            }
            Column {
                x: 20; anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                T { text: "Dashboard"; font.pixelSize: 20; font.bold: true }
                T { kind: "reading"; width: 170; wrapMode: Text.WordWrap; text: "Touch the bottom edge of the screen or press SUPER + ALT + D. SUPER + W opens Wallpaper."; font.pixelSize: 11; color: "#a0a0aa" }
            }
            Column {
                anchors.right: parent.right; anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Btn { primary: true; icon: ""; text: "Open now"; onClicked: page.openNow("") }
                Btn { icon: ""; text: "Wallpapers"; onClicked: page.openNow("wallpaper") }
            }
        }

        // ---------- look ----------
        SectionTitle { text: "Theme"; sub: "How the dashboard looks. Shadow, Graphite and Aurora take their colors from your wallpaper, like the hot corner." }
        Row {
            width: parent.width
            spacing: 10
            Repeater {
                model: page.looks
                delegate: Rectangle {
                    readonly property bool on: page.v("style", "shadow") === modelData.k
                    width: (parent.width - 30) / 4
                    height: 26 + (width - 24) * 0.53 + 44
                    radius: 14
                    color: lm.containsMouse ? "#191919" : "#141414"
                    border.width: on ? 2 : 1
                    border.color: on ? "#F6F5F4" : (lm.containsMouse ? "#3a3a3a" : "#222222")
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    scale: lm.pressed ? 0.98 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    DashMini {
                        x: 12; y: 12
                        width: parent.width - 24; height: (parent.width - 24) * 0.53
                        look: modelData.k
                        acc: page.v("accent", "#9ec9bd")
                    }
                    Column {
                        x: 14
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                        spacing: 1
                        T { text: modelData.n; font.pixelSize: 13; font.bold: true }
                        T { kind: "reading"; text: modelData.d; font.pixelSize: 10; color: "#8a8a8a"; width: parent.parent.width - 50; elide: Text.ElideRight }
                    }
                    Rectangle {
                        visible: parent.on
                        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 14
                        width: 20; height: 20; radius: 10
                        color: "#F6F5F4"
                        T { anchors.centerIn: parent; text: "✓"; font.pixelSize: 11; font.bold: true; color: "#0d0d0d" }
                    }
                    MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.setv("style", modelData.k) }
                }
            }
        }

        // ---------- appearance ----------
        SectionTitle { text: "Look" }
        ToggleRow { label: "Grow out of the edge"; desc: "Flat against the bottom of the screen (or your bar) with curved corners where they meet. Off: a floating card"; checked: page.v("attach", true) === true; onToggled: function(x) { page.setv("attach", x) } }
        SliderRow {
            label: "Transparency"
            desc: "Lower is more see-through. Starts at the transparency of your bar"
            from: 0.35; to: 1.0; step: 0.01; decimals: 2
            value: page.v("opacity", 0.9)
            onCommitted: function(x) { page.setv("opacity", x.toFixed(2)) }
        }
        ToggleRow { label: "Blur"; desc: "Blur the desktop behind the dashboard"; checked: page.v("blur", true) === true; onToggled: function(x) { page.setv("blur", x) } }
        SegRow {
            label: "Animation"
            desc: "Slide comes up out of the bottom edge"
            options: [{ label: "Slide", value: "slide" }, { label: "Fade", value: "fade" }, { label: "Off", value: "none" }]
            current: page.v("animation", "slide") === "morph" ? "slide" : page.v("animation", "slide")
            onChosen: function(x) { page.setv("animation", x) }
        }

        // ---------- cards ----------
        SectionTitle { text: "Cards"; sub: "Remove, add, resize and move the cards of a tab. The editor opens in the dashboard (the pencil button there does the same)." }
        Row {
            spacing: 10
            Btn { icon: "\uf044"; text: "Edit Dashboard"; onClicked: page.editTab("dashboard") }
            Btn { icon: "\uf044"; text: "Edit Performance"; onClicked: page.editTab("performance") }
            Btn { icon: "\uf044"; text: "Edit About"; onClicked: page.editTab("about") }
        }

        // ---------- behaviour ----------
        SectionTitle { text: "Opening" }
        ToggleRow { label: "Dashboard"; desc: "Turn the whole dashboard on or off"; checked: page.v("enabled", true) === true; onToggled: function(x) { page.setv("enabled", x) } }
        ToggleRow { label: "Open from the bottom edge"; desc: "Push the pointer against the middle of the bottom edge of the screen to open it"; checked: page.v("edge", true) === true; onToggled: function(x) { page.setv("edge", x) } }
        ToggleRow { label: "SUPER + W opens Wallpaper"; desc: "Off: SUPER + W opens the old wallpaper picker"; checked: page.v("wallpaper_key", true) === true; onToggled: function(x) { page.setv("wallpaper_key", x) } }
        ToggleRow { label: "Close when the pointer leaves"; desc: "After you have been inside it. Otherwise click outside or press Esc"; checked: page.v("close_on_leave", true) === true; onToggled: function(x) { page.setv("close_on_leave", x) } }

        SectionTitle { text: "Size & motion" }
        SliderRow {
            label: "Width"
            from: 760; to: 1500; step: 20; unit: " px"
            value: page.v("width", 1000)
            onCommitted: function(x) { page.setv("width", Math.round(x)) }
        }
        SliderRow {
            label: "Scale"
            desc: "Everything bigger or smaller"
            from: 0.75; to: 1.4; step: 0.05; decimals: 2; unit: "x"
            value: page.v("scale", 1)
            onCommitted: function(x) { page.setv("scale", x.toFixed(2)) }
        }
        SliderRow {
            label: "Animation speed"
            from: 0.5; to: 2; step: 0.1; decimals: 1; unit: "x"
            value: page.v("speed", 1)
            onCommitted: function(x) { page.setv("speed", x.toFixed(1)) }
        }

        // ---------- tabs ----------
        SectionTitle { text: "Tabs"; sub: "Switch tabs on or off and change their order. In the dashboard: arrows or 1-4 switch tabs, Esc closes." }
        Repeater {
            model: page.tabRows()
            delegate: Rectangle {
                readonly property int pos: (page.dc.tabs || []).indexOf(modelData)
                readonly property bool on: pos >= 0
                width: parent.width
                height: 58
                radius: 12
                color: "#141414"
                border.width: 1
                border.color: "#1f1f1f"
                opacity: on ? 1 : 0.6
                Column {
                    x: 16; anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    T { text: page.info(modelData).n; font.pixelSize: 14; font.bold: true }
                    T { kind: "reading"; text: page.info(modelData).d; font.pixelSize: 11; color: "#8a8a8a" }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Arrow { visible: on; glyph: "‹"; active: pos > 0; onClicked: { const a = page.dc.tabs.slice(); a.splice(pos, 1); a.splice(pos - 1, 0, modelData); page.setTabs(a) } }
                    Arrow { visible: on; glyph: "›"; active: pos < page.dc.tabs.length - 1; onClicked: { const a = page.dc.tabs.slice(); a.splice(pos, 1); a.splice(pos + 1, 0, modelData); page.setTabs(a) } }
                    Arrow {
                        glyph: on ? "×" : "+"
                        active: !(on && page.dc.tabs.length <= 1)
                        onClicked: { const a = (page.dc.tabs || []).filter(function(x) { return x !== modelData }); if (!on) a.push(modelData); page.setTabs(a) }
                    }
                }
            }
        }
        SegRow {
            label: "Opens on"
            desc: "The tab you see first"
            options: (page.dc.tabs || []).map(function(k) { return { label: page.info(k).n, value: k } })
            current: page.v("default_tab", "dashboard")
            onChosen: function(x) { page.setv("default_tab", x) }
        }
    }

    component Arrow: Rectangle {
        id: ar
        property string glyph: ""
        property bool active: true
        signal clicked()
        width: 32; height: 32; radius: 9
        color: am.containsMouse && active ? "#262626" : "#1a1a1a"
        border.width: 1
        border.color: "#2a2a2a"
        opacity: active ? 1 : 0.35
        T { anchors.centerIn: parent; text: ar.glyph; font.pixelSize: 16 }
        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; enabled: ar.active; cursorShape: Qt.PointingHandCursor; onClicked: ar.clicked() }
    }
}
