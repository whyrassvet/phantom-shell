import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
FloatingWindow {
    id: win
    title: "Rice Settings"
    // bigger on bigger screens (about 70 % of a 1080p screen), never more than fits
    readonly property var scr0: Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property int sw0: scr0 ? scr0.width : 1920
    readonly property int sh0: scr0 ? scr0.height : 1080
    implicitWidth: Math.max(Math.min(980, sw0 - 40), Math.min(1260, Math.round(sw0 * 0.68)))
    implicitHeight: Math.max(Math.min(720, sh0 - 60), Math.min(900, Math.round(sh0 * 0.82)))
    color: "transparent"
    visible: true
    onVisibleChanged: if (!visible) Qt.quit()

    readonly property string home: Quickshell.env("HOME")
    // the tour is on: the rest of the screen goes dark (dimWin below)
    property bool tourOn: false
    function startTour() { page = 0; tour.start() }

    // falling stars across the whole window (Home: Falling stars)
    property bool stars: true
    function setStars(on) {
        stars = on
        Quickshell.execDetached(["bash", "-c", "mkdir -p \"$HOME/.config/rice\" && printf '{\"stars\": %s}\\n' \"$1\" > \"$HOME/.config/rice/settings-app.json\"", "_", on ? "true" : "false"])
    }
    Process {
        command: ["bash", "-c", "cat \"$HOME/.config/rice/settings-app.json\" 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { win.stars = JSON.parse(text).stars !== false } catch (e) { } } }
    }
    function closeNow() { Qt.quit() }

    // ---------- search: every setting on every page, found by its name, its section, its page or its text ----------
    property var results: []
    property int searchSel: 0
    property var searchIndex: []
    readonly property var synonyms: ({
        bar: ["waybar", "bar"], colour: ["color"], colors: ["color", "theme", "scheme"],
        transparent: ["opacity", "transparency"], transparency: ["opacity", "transparency"], seethrough: ["opacity"],
        round: ["rounding", "radius", "round"], corners: ["rounding", "corner"], lock: ["lock", "idle"],
        sound: ["sound", "sfx", "volume"], sounds: ["sound", "sfx"], sfx: ["sound", "sfx"], music: ["music", "welcome"],
        volume: ["volume", "sound"], mouse: ["cursor", "pointer"], pointer: ["cursor", "pointer"], font: ["font", "text"],
        fonts: ["font"], gap: ["gaps", "gap"], anim: ["animation"], animations: ["animation"], notification: ["notification", "popup"],
        popup: ["popup", "notification"], popups: ["popup", "notification"], keyboard: ["keybind", "bind", "key"],
        shortcut: ["keybind", "bind", "shortcut"], shortcuts: ["keybind", "bind"], screen: ["screen", "monitor", "display"],
        monitor: ["monitor", "screen", "display"], dark: ["dark", "black", "theme"], wallpaper: ["wallpaper", "background"],
        background: ["background", "wallpaper"], top: ["top", "position"], bottom: ["bottom", "position"],
        place: ["position"], where: ["position"], size: ["size", "width", "height", "scale"], big: ["size", "scale"],
        speed: ["speed", "animation"], fast: ["speed"], slow: ["speed", "light", "performance"], lag: ["light", "performance"], laggy: ["light", "performance"], performance: ["light", "performance"], power: ["power", "battery"], wifi: ["wi-fi", "wifi", "network"],
        launcher: ["rofi", "launcher"], apps: ["apps", "rofi", "dock"], game: ["gaming"], games: ["gaming"]
    })
    function buildIndex() {
        const out = []
        const slots = pagesHolder.children
        for (let i = 0; i < slots.length; i++) {
            const sl = slots[i]
            if (sl.idx === undefined) continue
            const pg = win.pages[sl.idx]
            if (!pg || pg.hidden) continue
            out.push({ page: sl.idx, label: pg.name, section: "", desc: "Page", pageName: pg.name, item: null, kind: "page" })
            const ctx = { section: "" }
            const walk = function(it) {
                const kids = it.children || []
                for (let k = 0; k < kids.length; k++) {
                    const c = kids[k]
                    if (c.sub !== undefined && c.text !== undefined && c.topPadding !== undefined && typeof c.text === "string") {
                        ctx.section = c.text
                        if (c.text.length) out.push({ page: sl.idx, label: c.text, section: "", desc: c.sub || "", pageName: pg.name, item: c, kind: "section" })
                        continue
                    }
                    if (c.reserved !== undefined && c.label !== undefined && typeof c.label === "string" && c.label.length) {
                        out.push({ page: sl.idx, label: c.label, section: ctx.section, desc: c.desc || "", pageName: pg.name, item: c, kind: "row" })
                        continue
                    }
                    // a heading made with a plain title text: it names the section too
                    if (c.kind === "title" && typeof c.text === "string" && c.text.length > 1 && c.text.length < 40 && c.font && c.font.pixelSize >= 15) {
                        ctx.section = c.text
                        continue
                    }
                    // a setting with its own layout (like the clock fonts): its 14 px name counts too
                    if (c.kind === "body" && typeof c.text === "string" && c.font && c.font.pixelSize === 14 && !c.font.bold
                            && c.text.length > 2 && c.text.length < 40 && c.text.indexOf("<") < 0) {
                        out.push({ page: sl.idx, label: c.text, section: ctx.section, desc: "", pageName: pg.name, item: c.parent || c, kind: "row" })
                    }
                    walk(c)
                }
            }
            walk(sl)
        }
        // the same setting twice (a page that keeps two copies of a part): once is enough
        const seen = {}
        searchIndex = out.filter(e => { const k = e.page + "|" + e.label + "|" + e.section; if (seen[k]) return false; seen[k] = true; return true })
    }
    function runSearch(q) {
        q = q.trim().toLowerCase()
        searchSel = 0
        if (!q.length) { results = []; return }
        if (!searchIndex.length) buildIndex()
        const toks = q.split(/\s+/).filter(t => t.length)
        const scored = []
        for (const e of searchIndex) {
            const L = e.label.toLowerCase(), S = e.section.toLowerCase(), P = e.pageName.toLowerCase(), D = e.desc.toLowerCase()
            let score = 0, ok = true
            for (const t of toks) {
                const alts = [t].concat(win.synonyms[t] || [])
                let best = 0
                for (const a of alts) {
                    const w = a === t ? 1 : 0.8
                    if (L.startsWith(a) || L.indexOf(" " + a) >= 0) best = Math.max(best, 7 * w)
                    else if (L.indexOf(a) >= 0) best = Math.max(best, 5 * w)
                    if (S.indexOf(a) >= 0) best = Math.max(best, 3 * w)
                    if (P.indexOf(a) >= 0) best = Math.max(best, 3 * w)
                    if (D.indexOf(a) >= 0) best = Math.max(best, 1.5 * w)
                }
                if (best === 0) { ok = false; break }
                score += best
            }
            if (!ok) continue
            if (e.kind === "page") score += 1
            if (L === q) score += 6
            scored.push({ e: e, s: score })
        }
        scored.sort((a, b) => (b.s - a.s) || (a.e.label.length - b.e.label.length))
        results = scored.slice(0, 40).map(x => x.e)
    }
    function openResult(r) {
        if (!r) return
        Sfx.play("select")
        searchIn.text = ""
        card.forceActiveFocus()
        page = r.page
        if (r.item) { jumpTo.target = r.item; jumpTo.restart() }
    }
    // after the page has changed: scroll to the setting and light it up for a moment
    Timer {
        id: jumpTo
        property var target: null
        interval: 380
        onTriggered: {
            const it = target
            if (!it) return
            let f = it.parent
            while (f && f.contentY === undefined) f = f.parent
            if (f) {
                const y = it.mapToItem(f.contentItem, 0, 0).y
                f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, y - 30))
            }
            Qt.createQmlObject('import QtQuick; Rectangle { anchors.fill: parent; anchors.margins: -3; radius: (parent.radius !== undefined ? parent.radius : 8) + 3; color: "transparent"; border.width: 2; border.color: "#F6F5F4"; opacity: 0; z: 50;' +
                ' SequentialAnimation on opacity { running: true; NumberAnimation { to: 1; duration: 220 } PauseAnimation { duration: 500 } NumberAnimation { to: 0.35; duration: 260 } NumberAnimation { to: 1; duration: 260 } PauseAnimation { duration: 500 } NumberAnimation { to: 0; duration: 600 } ScriptAction { script: destroy() } } }', it, "searchFlash")
        }
    }
    property int page: 0
    property string status: ""
    property string colorMode: "auto"
    property var dst: ({ widgets: {}, clock: {}, dock: {}, lock: {} })
    property string osName: "Linux"
    property var osIds: ["linux"]
    // distro logo from the Nerd Font "font logos" set (NixOS logo on NixOS, Arch logo on Arch, ...)
    readonly property var osGlyphs: ({
        nixos: "\uf313", arch: "\uf303", archarm: "\uf303", cachyos: "\uf385", endeavouros: "\uf322", manjaro: "\uf312",
        garuda: "\uf303", ubuntu: "\uf31b", fedora: "\uf30a", nobara: "\uf380", bazzite: "\uf30a", ultramarine: "\uf30a", debian: "\uf306", opensuse: "\uf314", gentoo: "\uf30d",
        void: "\uf32e", alpine: "\uf300", linuxmint: "\uf30e", pop: "\uf32a"
    })
    function osGlyph() {
        for (let i = 0; i < osIds.length; i++) if (osGlyphs[osIds[i]] !== undefined) return osGlyphs[osIds[i]]
        return "\uf17c"
    }
    readonly property string userName: Quickshell.env("USER")
    // rice-effects: blur and transparency are off right now
    property bool flat: false
    Process {
        id: flatProc
        command: ["bash", "-c", "[ -e \"$HOME/.cache/rice/flat\" ] && echo 1 || echo 0"]
        running: true
        stdout: StdioCollector { onStreamFinished: win.flat = text.trim() === "1" }
    }
    Timer { interval: 1500; running: true; repeat: true; onTriggered: if (!flatProc.running) flatProc.running = true }

    function dset(group, key, value) {
        const d = JSON.parse(JSON.stringify(dst))
        if (group === "widget") {
            if (!d.widgets[key]) d.widgets[key] = {}
            d.widgets[key].enabled = (value === "on")
        } else {
            if (!d[group]) d[group] = {}
            d[group][key] = (value === "on" || value === "off") ? (value === "on") : value
        }
        dst = d
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" \"$@\"", "_", group, key, String(value)])
        status = "Applied"
        drefresh.restart()
    }

    function dreset() {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/desktop-set\" reset-pos"])
        status = "Widget positions reset"
        drefresh.restart()
    }

    Process {
        id: dstate
        command: ["bash", "-c", "\"$HOME/.local/bin/desktop-set\" state"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { win.dst = JSON.parse(text) } catch (e) { } }
        }
    }
    Timer { id: drefresh; interval: 900; onTriggered: dstate.running = true }

    Process {
        id: osProc
        command: ["bash", "-c", ". /etc/os-release 2>/dev/null; printf '%s\\n%s\\n%s\\n' \"${NAME:-Linux}\" \"${ID:-linux}\" \"${ID_LIKE:-}\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.split("\n")
                if (p[0] && p[0].trim().length > 0) win.osName = p[0].trim()
                win.osIds = ((p[1] || "") + " " + (p[2] || "")).trim().toLowerCase().split(/\s+/)
            }
        }
    }

    readonly property var pages: [
        { name: "Home", icon: "\uf015" },
        { name: "Sfx & sounds", icon: "\uf028" },
        { name: "Bar", icon: "\uf0c9" },
        { name: "Bar layout", icon: "\uf0db", hidden: true },
        { name: "Hyprland", icon: "\uf108" },
        { name: "Dashboard", icon: "\uf009" },
        { name: "Rofi", icon: "\uf002" },
        { name: "Theme", icon: "\udb80\udfd8" },
        { name: "Cursors", icon: "\uf245" },
        { name: "Notifications", icon: "\uf0f3" },
        { name: "Idle & Lockscreen", icon: "\uf023" },
        { name: "Desktop", icon: "\uf26c" },
        { name: "Hot corners", icon: "\udb82\ude0b" },
        { name: "Interface", icon: "\uf2d0" },
        { name: "Services", icon: "" },
        { name: "Monitors", icon: "\uf108" }
    ]

    readonly property string hyprTool: home + "/.local/bin/hypr-set"
    property var hv: ({})
    property var hb: ({ mode: "wallpaper", active: "#F6F5F4", inactive: "#444444" })
    property var ha: ({ enabled: true, speed: 100 })

    function hrun(args, msg) {
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/hypr-set\" \"$@\"", "_"].concat(args.map(a => String(a))))
        if (msg) status = msg
        hrefresh.restart()
    }

    function hset(key, value) {
        const v = Object.assign({}, hv)
        v[key] = value
        hv = v
        hrun(["set", key, String(value)], "Applied")
    }

    function setBorderMode(m) {
        const b = Object.assign({}, hb)
        b.mode = m
        hb = b
        hrun(["border-mode", m], "Borders: " + m)
    }

    function setBorderColor(which, hex) {
        const b = Object.assign({}, hb)
        b[which] = hex
        hb = b
        hrun(["border-color", which, hex], "Border color set")
    }

    function setAnim(k, v) {
        const a = Object.assign({}, ha)
        a[k] = v
        ha = a
        hrun([k === "enabled" ? "anim-enabled" : "anim-speed", k === "enabled" ? (v ? "on" : "off") : v], "Applied")
    }

    function setColorMode(m) {
        colorMode = m
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-colors\" mode \"$1\"", "_", m])
        let nm = m
        for (let i = 0; i < schemes.length; i++) if (schemes[i].key === m) nm = schemes[i].name
        status = "Colors: " + nm + " (applying...)"
    }

    property var schemes: []
    Process {
        id: schemeProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-colors\" list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { win.schemes = JSON.parse(text) } catch (e) { } }
        }
    }

    Process {
        id: modeProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-colors\" get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { const m = text.trim(); if (m.length > 0) win.colorMode = m }
        }
    }

    Process {
        id: hstate
        command: ["bash", "-c", "\"$HOME/.local/bin/hypr-set\" state"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    if (j.opts) win.hv = j.opts
                    if (j.borders) win.hb = j.borders
                    if (j.anim) win.ha = j.anim
                } catch (e) { }
            }
        }
    }

    Timer { id: hrefresh; interval: 800; onTriggered: hstate.running = true }

    Rectangle {
        id: card
        anchors.fill: parent
        // solid while blur and transparency are off (Settings > Services, or gaming mode); the stars stay
        color: Qt.rgba(0.05, 0.05, 0.05, win.flat ? 1 : 0.72)
        Behavior on color { ColorAnimation { duration: 300 } }
        focus: true
        Keys.onEscapePressed: win.closeNow()
        NumberAnimation on opacity { from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }

        // falling stars over the whole window, behind everything (they stay put while the pages change)
        StarField {
            anchors.fill: parent
            count: 20
            readonly property bool on: win.stars
            running: win.visible && on
            opacity: on ? (win.page === 0 ? 1 : 0.55) : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }

        // ---------- you: a bigger profile card on top of the sidebar ----------
        Rectangle {
            id: profile
            x: 16
            y: 12
            width: 206
            height: 74
            radius: 18
            color: pfm.containsMouse ? "#181818" : "#131313"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)
            Behavior on color { ColorAnimation { duration: 160 } }
            // soft light in the corner
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.045) }
                    GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
            // avatar with a ring (your initial when there is no ~/.face)
            Item {
                id: av
                z: 2            // above the card's click area, so the picture can be clicked on its own
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                height: 52
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#F6F5F4" }
                        GradientStop { position: 1; color: "#5a5a60" }
                    }
                    rotation: pfm.containsMouse ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: width / 2
                    color: "#1c1c1c"
                    T { anchors.centerIn: parent; text: win.userName.length ? win.userName[0].toUpperCase() : "?"; font.pixelSize: 20; font.bold: true }
                }
                RoundImage {
                    id: avImg
                    anchors.fill: parent
                    anchors.margins: 3
                    source: "file://" + win.home + "/.face"
                }
                // click the picture: choose a new one (it is also on the lock screen)
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.55)
                    opacity: avm.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    T { anchors.centerIn: parent; kind: "icon"; text: "\uf030"; font.pixelSize: 15 }
                }
                MouseArea {
                    id: avm
                    anchors.fill: parent
                    z: 5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: facePicker.running = true
                }
                scale: pfm.containsMouse || avm.containsMouse ? 1.05 : 1
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            }
            Process {
                id: facePicker
                command: ["zenity", "--file-selection", "--title=Choose a profile picture", "--file-filter=Images | *.png *.jpg *.jpeg *.webp"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const p = text.trim()
                        if (p.length === 0) return
                        Quickshell.execDetached(["bash", "-c", "cp -f \"$1\" \"$HOME/.face\"", "_", p])
                        faceReload.restart()
                    }
                }
            }
            Timer { id: faceReload; interval: 400; onTriggered: { avImg.source = ""; avImg.source = "file://" + win.home + "/.face" } }
            Column {
                anchors.left: av.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                T { kind: "title"; text: win.userName; font.pixelSize: 17; font.bold: true; width: parent.width; elide: Text.ElideRight }
                // distro chip
                Rectangle {
                    width: Math.min(parent.width, osRow.implicitWidth + 16)
                    height: 22
                    radius: 11
                    color: "#222224"
                    Row {
                        id: osRow
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        T { kind: "icon"; text: win.osGlyph(); font.pixelSize: 12; color: "#d8d8dc"; anchors.verticalCenter: parent.verticalCenter }
                        T { text: win.osName; font.pixelSize: 11; color: "#b8b8c0"; anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, profile.width - 110); elide: Text.ElideRight }
                    }
                }
            }
            MouseArea { id: pfm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.page = 0 }
        }

        Rectangle {
            id: closeBtn
            width: 30
            height: 30
            radius: 15
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: 14
            color: closeMouse.containsMouse ? "#2a2a2a" : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
            T { anchors.centerIn: parent; text: "\u00d7"; font.pixelSize: 20 }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.closeNow()
            }
        }

        // ---------- search anything ----------
        Rectangle {
            id: searchBox
            x: 16; y: 96
            width: 206; height: 40
            radius: 13
            color: searchIn.activeFocus ? "#171717" : "#121212"
            border.width: 1
            border.color: searchIn.activeFocus ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.06)
            Behavior on border.color { ColorAnimation { duration: 160 } }
            T { kind: "icon"; text: "\uf002"; x: 14; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 12; color: searchIn.activeFocus ? "#d8d8dc" : "#77777f" }
            TextInput {
                id: searchIn
                objectName: "searchIn"
                x: 36; width: parent.width - 66
                anchors.verticalCenter: parent.verticalCenter
                color: "#F6F5F4"
                font.family: Fonts.family("body")
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                onTextChanged: { if (activeFocus) Sfx.play("type"); win.runSearch(text) }
                Keys.onDownPressed: win.searchSel = Math.min(win.searchSel + 1, win.results.length - 1)
                Keys.onUpPressed: win.searchSel = Math.max(0, win.searchSel - 1)
                Keys.onReturnPressed: win.openResult(win.results[win.searchSel])
                Keys.onEnterPressed: win.openResult(win.results[win.searchSel])
                Keys.onEscapePressed: { text = ""; card.forceActiveFocus() }
            }
            T {
                x: 36; anchors.verticalCenter: parent.verticalCenter
                visible: searchIn.text.length === 0
                text: "Search anything!"
                color: "#6a6a72"; font.pixelSize: 13
            }
            Rectangle {
                visible: searchIn.text.length > 0
                width: 22; height: 22; radius: 11
                anchors.right: parent.right; anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                color: clrM.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                T { anchors.centerIn: parent; text: "\u00d7"; font.pixelSize: 15; color: "#a8a8b0" }
                MouseArea { id: clrM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: searchIn.text = "" }
            }
            MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.IBeamCursor; onClicked: searchIn.forceActiveFocus() }
        }
        // results: the setting, and where it is (page > section)
        ListView {
            id: resultList
            x: 12; y: 144
            width: 214
            height: parent.height - 144 - 34
            visible: searchIn.text.length > 0
            clip: true
            model: win.results
            currentIndex: win.searchSel
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Rectangle {
                width: resultList.width
                height: 50
                radius: 11
                color: index === win.searchSel ? Qt.rgba(1, 1, 1, 0.09) : (rm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                Column {
                    x: 12; width: parent.width - 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    T { text: modelData.label; font.pixelSize: 13; font.bold: index === win.searchSel; width: parent.width; elide: Text.ElideRight }
                    T {
                        text: modelData.kind === "page" ? "Page" : (modelData.pageName + (modelData.section && modelData.section !== modelData.label ? "  \u203a  " + modelData.section : ""))
                        font.pixelSize: 11; color: "#8a8a92"; width: parent.width; elide: Text.ElideRight
                    }
                }
                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: win.searchSel = index; onClicked: win.openResult(modelData) }
            }
            T {
                visible: win.results.length === 0
                y: 14; x: 8; width: parent.width - 16
                text: "Nothing found. Try other words, like \"blur\" or \"bar position\"."
                wrapMode: Text.WordWrap
                font.pixelSize: 12; color: "#8a8a92"
            }
        }

        // sidebar scrolls when the categories do not fit
        Flickable {
            id: navFlick
            x: 16
            y: 144
            width: 206
            height: parent.height - 144 - 34
            // while you search, the results take this place
            opacity: searchIn.text.length ? 0 : 1
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 160 } }
            contentWidth: width
            contentHeight: navCol.height + 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Behavior on contentY {
                enabled: !navFlick.dragging && !navFlick.flicking
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(e) {
                    const max = Math.max(0, navFlick.contentHeight - navFlick.height)
                    navFlick.contentY = Math.max(0, Math.min(max, navFlick.contentY - e.angleDelta.y * 0.9))
                }
            }
            // keep the selected category visible
            function reveal() {
                const top = (win.page > 3 ? win.page - 1 : win.page) * 56, bottom = top + 46
                if (top < contentY) contentY = top
                else if (bottom > contentY + height) contentY = Math.min(Math.max(0, contentHeight - height), bottom + 8 - height)
            }
            Connections { target: win; function onPageChanged() { navFlick.reveal() } }

            // the selection glides to the new category and stretches a little on the way (Material 3)
            Rectangle {
                id: navSel
                property real target: (win.page > 3 ? win.page - 1 : win.page) * 56
                y: target
                width: 206
                height: 46
                radius: 14
                color: "#262626"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.05)
                Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                Rectangle {
                    x: 0; anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: 18; radius: 1.5
                    color: "#F6F5F4"
                }
            }

            Column {
                id: navCol
                width: 206
                spacing: 10

                Repeater {
                    model: win.pages
                    delegate: Rectangle {
                        width: parent.width
                        height: 46
                        visible: !modelData.hidden
                        radius: 14
                        color: win.page !== index && navMouse.containsMouse ? "#1a1a1a" : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        T { kind: "icon"; x: 18; anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; font.pixelSize: 18
                            color: win.page === index ? "#F6F5F4" : "#a8a8b0"
                            scale: win.page === index ? 1.1 : 1
                            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 200 } } }
                        T { x: 50; width: parent.width - 58; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; font.pixelSize: 14
                            font.weight: win.page === index ? Font.DemiBold : Font.Normal
                            color: win.page === index ? "#F6F5F4" : "#b8b8c0"
                            Behavior on color { ColorAnimation { duration: 200 } } }
                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.page = index
                        }
                    }
                }
            }
        }


        Item {
            id: pagesHolder
            x: 238
            y: 60
            width: parent.width - 238
            height: parent.height - 60
            clip: true


            PageSlot { idx: 0; cur: win.page; HomePage { id: homePage; anchors.fill: parent; ctl: win } }
            PageSlot { idx: 1; cur: win.page; SoundsPage { anchors.fill: parent; ctl: win } }
            PageSlot { idx: 2; cur: win.page; T { anchors.centerIn: parent; text: "Work in progress"; font.pixelSize: 20 } }
            PageSlot { idx: 4; cur: win.page; HyprlandPage { anchors.fill: parent; ctl: win } }
            PageSlot { idx: 5; cur: win.page; DashboardPage { anchors.fill: parent; ctl: win } }
            PageSlot { idx: 6; cur: win.page; RofiPage { anchors.fill: parent; ctl: win } }
            PageSlot { idx: 7; cur: win.page; ThemePage { anchors.fill: parent; ctl: win } }
            PageSlot { idx: 8; cur: win.page; CursorsPage { anchors.fill: parent; ctl: win } }
            PageSlot { idx: 9; cur: win.page; NotificationsPage { anchors.fill: parent; ctl: win } }
            PageSlot { idx: 10; cur: win.page; IdlePage { anchors.fill: parent; ctl: win } }
            PageSlot { idx: 11; cur: win.page; DesktopPage { anchors.fill: parent; ctl: win } }
            PageSlot { idx: 12; cur: win.page; HotCornersPage { anchors.fill: parent; ctl: win } }
            PageSlot { idx: 13; cur: win.page; InterfacePage { anchors.fill: parent; ctl: win } }
            PageSlot { idx: 14; cur: win.page; ServicesPage { anchors.fill: parent; ctl: win } }
            PageSlot {
                idx: 15; cur: win.page
                Flickable {
                    anchors.fill: parent
                    clip: true
                    contentWidth: width
                    contentHeight: monitorPage.height + 48
                    boundsBehavior: Flickable.StopAtBounds
                    MonitorsPage { id: monitorPage; x: 24; y: 16; width: parent.width - 48; ctl: win }
                }
            }
        }

        // ---------- the tour (after the welcome intro, or rice-welcome tour) ----------
        Tour {
            id: tour
            objectName: "tour"
            onFinished: { card.forceActiveFocus(); win.tourOn = false }
            onActiveChanged: if (active) win.tourOn = true
            steps: [
                { title: "You can find anything here!", r: 15,
                  body: "Type what you want to change, like \"bar position\" or \"blur\", and jump right to it.",
                  rect: function() { return { x: searchBox.x - 5, y: searchBox.y - 5, w: searchBox.width + 10, h: searchBox.height + 10 } } },
                { title: "Every part has a page", r: 18,
                  body: "The bar, the theme, notifications, the lock screen, the dashboard and more. Click one to open it.",
                  rect: function() { return { x: navFlick.x - 6, y: navFlick.y - 6, w: navFlick.width + 12, h: Math.min(navFlick.height, navCol.height) + 12 } } },
                { title: "Sounds you can change", r: 14,
                  body: "The soft clicks and this quiet music live in Sfx & sounds. Pick another sound pack, make it quieter or turn it off.",
                  rect: function() { return { x: navFlick.x - 4, y: navFlick.y + 56 - navFlick.contentY - 4, w: navFlick.width + 8, h: 54 } } },
                { title: "Make it yours", r: 16,
                  body: "Start with the things people change first. Most changes show up right away, and every page has a live preview.",
                  rect: function() {
                      const q = homePage.quickArea, p = q.mapToItem(card, 0, 0)
                      return { x: p.x - 10, y: p.y - 44, w: q.width + 20, h: q.height + 54 }
                  } },
                { title: "This is you", r: 22,
                  body: "Click your picture to change it, it shows on the lock screen too. Click the card to come back here, to Home.",
                  rect: function() { return { x: profile.x - 5, y: profile.y - 5, w: profile.width + 10, h: profile.height + 10 } } },
                { title: "That's it!", r: 20,
                  body: "Close Settings here and open it again any time with SUPER + U. Have fun with your desktop.",
                  rect: function() { return { x: closeBtn.x - 6, y: closeBtn.y - 6, w: closeBtn.width + 12, h: closeBtn.height + 12 } } }
            ]
        }
        Process {
            // the welcome intro leaves this file behind when it opens Settings
            id: tourCheck
            running: true
            command: ["bash", "-c", "f=\"$HOME/.cache/rice/settings-tour\"; [ -e \"$f\" ] && rm -f \"$f\" && echo 1 || echo 0"]
            stdout: StdioCollector { onStreamFinished: if (text.trim() === "1") tourDelay.start() }
        }
        Timer { id: tourDelay; interval: 650; onTriggered: { win.page = 0; tour.start() } }

        // the click sound for everything clickable in Settings (Sfx & sounds)
        SfxTap {}

        T {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 24
            text: win.status
            color: "#8a8a8a"
            font.pixelSize: 12
        }
    }
}

// ---------- during the tour: the whole screen goes dark (wallpaper, Waybar, widgets), only Settings stays lit ----------
PanelWindow {
    id: dimWin
    readonly property bool want: win.tourOn
    // where the Settings window is on this monitor (hyprctl), plus a little room for its border
    property real hx: 0
    property real hy: 0
    property real hw: 0
    property real hh: 0
    property real k: 0
    visible: k > 0.01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-tour-dim"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // clicks on the dark part go nowhere, clicks on Settings go to Settings
    mask: Region { item: dimAll; Region { item: dimHole; intersection: Intersection.Subtract } }
    Item { id: dimAll; anchors.fill: parent }
    Item { id: dimHole; x: dimWin.hx; y: dimWin.hy; width: dimWin.hw; height: dimWin.hh }

    onWantChanged: { dimK.to = want ? 1 : 0; dimK.restart(); if (want) dimWhere.running = true }
    NumberAnimation { id: dimK; target: dimWin; property: "k"; duration: 420; easing.type: Easing.OutCubic }
    Process {
        id: dimWhere
        command: ["bash", "-c", "hyprctl -j clients 2>/dev/null | python3 -c 'import sys,json\nfor c in json.load(sys.stdin):\n    if c.get(\"title\")==\"Rice Settings\": print(c[\"monitor\"], c[\"at\"][0], c[\"at\"][1], c[\"size\"][0], c[\"size\"][1]); break'; hyprctl -j monitors 2>/dev/null | python3 -c 'import sys,json\nfor m in json.load(sys.stdin): print(\"M\", m[\"id\"], m[\"name\"], m[\"x\"], m[\"y\"])'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                if (lines.length === 0 || lines[0].startsWith("M")) return
                const w = lines[0].split(" ").map(Number)
                for (let i = 1; i < lines.length; i++) {
                    const m = lines[i].split(" ")
                    if (Number(m[1]) !== w[0]) continue
                    for (let j = 0; j < Quickshell.screens.length; j++)
                        if (Quickshell.screens[j].name === m[2]) dimWin.screen = Quickshell.screens[j]
                    dimWin.hx = w[1] - Number(m[3]) - 3; dimWin.hy = w[2] - Number(m[4]) - 3
                    dimWin.hw = w[3] + 6; dimWin.hh = w[4] + 6
                }
            }
        }
    }
    // follow the window if it is moved during the tour
    Timer { interval: 500; repeat: true; running: dimWin.want; onTriggered: if (!dimWhere.running) dimWhere.running = true }

    Item {
        anchors.fill: parent
        clip: true
        opacity: dimWin.k
        Rectangle {
            readonly property real b: 4000
            x: dimWin.hx - b; y: dimWin.hy - b
            width: dimWin.hw + 2 * b; height: dimWin.hh + 2 * b
            radius: 14 + b
            color: "transparent"
            border.width: b
            border.color: Qt.rgba(0, 0, 0, 0.88)
        }
    }
}
}
