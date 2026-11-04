import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// The dashboard. It slides up out of the bottom edge (SUPER + D, or SUPER + W for wallpapers).
// Tabs: Dashboard, Wallpaper, Performance, About. Settings > Dashboard.
PanelWindow {
    id: db
    property var cfg: ({ enabled: false })
    property string cfgText: ""
    property bool open: false
    property string tab: "dashboard"
    property real t: 0
    property bool entered: false
    property bool byHover: false
    property bool armed: true
    property bool editing: false
    property bool typing: false
    property string lastCmd: ""
    property bool cmdSeen: false
    property var visited: ({})
    property var stats: ({})
    property var disks: []
    readonly property var disk: disks.length > 0 ? disks[0] : null
    property var about: ({})
    property var layouts: ({})
    property var grids: ({})
    property string toastText: ""

    readonly property var tabs: cfg.tabs && cfg.tabs.length ? cfg.tabs : ["dashboard", "wallpaper", "performance", "about"]
    readonly property int curIdx: Math.max(0, tabs.indexOf(tab))
    readonly property bool atTop: false   // always at the bottom
    readonly property real sc: cfg.scale ? cfg.scale : 1
    readonly property real spd: cfg.speed ? cfg.speed : 1
    readonly property string anim: cfg.animation === "fade" || cfg.animation === "none" ? cfg.animation : "slide"
    readonly property bool attach: cfg.attach !== false
    readonly property bool barHere: !!cfg.bar && cfg.bar.position === "bottom" && !cfg.bar.autohide
    readonly property real barOff: barHere ? cfg.bar.height : 0
    readonly property real earR: attach ? 24 : 0
    readonly property real headH: 64
    readonly property real pad: 18
    readonly property real trayH: 0
    readonly property real baseW: cfg.width ? cfg.width : 1000
    // one size for every tab (the size of Performance), so switching tabs never resizes the panel
    function tabW(t) { return Math.min((db.width - 40) / sc - 2 * earR, baseW * 1.04) }
    function tabH(t) { return 330 }
    readonly property real wantW: tabW(tab)
    readonly property real wantH: headH + tabH(tab) + pad
    property real curW: wantW
    property real curH: wantH
    Behavior on curW { NumberAnimation { duration: 460 / db.spd; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] } }
    Behavior on curH { NumberAnimation { duration: 460 / db.spd; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] } }

    // ---------------- helpers for the tabs ----------------
    function md(cp) { return String.fromCodePoint(cp) }
    readonly property var glyphs: ({
        nixos: "", arch: "", archarm: "", cachyos: "", endeavouros: "", manjaro: "",
        garuda: "", ubuntu: "", fedora: "", nobara: "", bazzite: "", ultramarine: "", debian: "", opensuse: "", gentoo: "",
        void: "", alpine: "", linuxmint: "", pop: ""
    })
    function distroGlyph() {
        const di = about.distro || {}
        const ids = ((di.id || "") + " " + (di.like || "")).toLowerCase().split(/\s+/)
        for (let i = 0; i < ids.length; i++) if (glyphs[ids[i]] !== undefined) return glyphs[ids[i]]
        return ""
    }
    function greeting(d) {
        const h = d.getHours()
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }
    function uptimeText(s) {
        s = Math.floor(s || 0)
        const dd = Math.floor(s / 86400), hh = Math.floor(s % 86400 / 3600), mm = Math.floor(s % 3600 / 60)
        return (dd ? dd + "d " : "") + (hh ? hh + "h " : "") + mm + "m"
    }
    function close() { open = false; editing = false }
    function show(which, hover) {
        tab = which && tabs.indexOf(which) >= 0 ? which : (cfg.default_tab && tabs.indexOf(cfg.default_tab) >= 0 ? cfg.default_tab : tabs[0])
        byHover = hover === true
        entered = false
        open = true
    }
    function loadAbout() { if (!aboutProc.running) aboutProc.running = true }
    function registerGrid(tabId, g) { const n = Object.assign({}, grids); n[tabId] = g; grids = n }
    function saveLayout(tabId, l) {
        const n = Object.assign({}, layouts); n[tabId] = l; layouts = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" layout \"$1\" \"$2\"", "_", tabId, JSON.stringify(l)])
    }
    function resetLayout(tabId) {
        const n = Object.assign({}, layouts); delete n[tabId]; layouts = n
        Quickshell.execDetached(["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" reset-layout \"$1\"", "_", tabId])
    }
    function toast(m) { toastText = m; toastTimer.restart() }
    Timer { id: toastTimer; interval: 2400; onTriggered: db.toastText = "" }

    // ---------------- looks ----------------
    function hx(c) {
        const s = String(c).replace("#", "")
        return [parseInt(s.substr(0, 2), 16) / 255, parseInt(s.substr(2, 2), 16) / 255, parseInt(s.substr(4, 2), 16) / 255]
    }
    function mix(a, b, k, al) {
        const x = hx(a), y = hx(b)
        return Qt.rgba(x[0] * (1 - k) + y[0] * k, x[1] * (1 - k) + y[1] * k, x[2] * (1 - k) + y[2] * k, al === undefined ? 1 : al)
    }
    readonly property string acc: cfg.accent ? cfg.accent : "#9ec9bd"
    readonly property real op: cfg.opacity !== undefined ? cfg.opacity : 0.9
    // dark or light text on top of the wallpaper color
    function lum(c) { const x = hx(c); return 0.299 * x[0] + 0.587 * x[1] + 0.114 * x[2] }
    readonly property string accFg: lum(acc) > 0.55 ? "#0d0d0d" : "#F6F5F4"
    readonly property var barRgb: cfg.bar && cfg.bar.rgb && (cfg.bar.rgb[0] + cfg.bar.rgb[1] + cfg.bar.rgb[2]) < 200 ? cfg.bar.rgb : [12, 12, 14]
    readonly property string style: cfg.style ? cfg.style : "shadow"
    readonly property var p: style === "graphite" ? ({
        // warm grey, soft and solid, your color as the accent
        bg: Qt.rgba(0.11, 0.11, 0.122, op), solidBg: "#1c1c1f", card: Qt.rgba(1, 1, 1, 0.055), card2: Qt.rgba(1, 1, 1, 0.085),
        text: "#ECECEE", sub: "#9a9aa3", primary: mix(acc, "#ffffff", 0.42), onPrimary: "#141416",
        container: mix(acc, "#2a2a2e", 0.74), onContainer: mix(acc, "#ffffff", 0.62),
        line: "transparent", track: Qt.rgba(1, 1, 1, 0.09), radius: 30, cardRadius: 22, tabStyle: "underline", dark: true, glow: false
    }) : style === "aurora" ? ({
        // deep and dark, tinted by your wallpaper colors, with a soft glow
        bg: mix(acc, "#06060a", 0.88, op), solidBg: mix(acc, "#06060a", 0.88), card: mix(acc, "#16161c", 0.8, 0.72), card2: mix(acc, "#1e1e26", 0.72, 0.8),
        text: "#EEEAF2", sub: "#a9a4b0", primary: mix(acc, "#ffffff", 0.2), onPrimary: mix(acc, "#000000", 0.85),
        container: mix(acc, "#16161c", 0.55), onContainer: mix(acc, "#ffffff", 0.78),
        line: Qt.rgba(1, 1, 1, 0.05), track: Qt.rgba(1, 1, 1, 0.09), radius: 34, cardRadius: 26, tabStyle: "pill", dark: true, glow: true
    }) : style === "frost" ? ({
        // light frosted glass
        bg: Qt.rgba(0.965, 0.965, 0.972, op), solidBg: "#f6f6f8", card: Qt.rgba(0, 0, 0, 0.045), card2: Qt.rgba(0, 0, 0, 0.07),
        text: "#18181b", sub: "#6b6b74", primary: "#18181b", onPrimary: "#ffffff",
        container: Qt.rgba(0, 0, 0, 0.07), onContainer: "#18181b",
        line: Qt.rgba(0, 0, 0, 0.05), track: Qt.rgba(0, 0, 0, 0.08), radius: 30, cardRadius: 22, tabStyle: "segment", dark: false, glow: false
    }) : ({
        // Shadow: the color of your bar (black glass), details in your wallpaper color (like the hot corner)
        bg: Qt.rgba(barRgb[0] / 255, barRgb[1] / 255, barRgb[2] / 255, op), solidBg: "#0c0c0e", card: Qt.rgba(1, 1, 1, 0.05), card2: Qt.rgba(1, 1, 1, 0.08),
        text: "#F6F5F4", sub: "#8f8f98", primary: acc, onPrimary: accFg,
        container: mix(acc, "#141416", 0.8), onContainer: mix(acc, "#ffffff", 0.55),
        line: Qt.rgba(1, 1, 1, 0.07), track: Qt.rgba(1, 1, 1, 0.1), radius: 28, cardRadius: 20, tabStyle: "segment", dark: true, glow: false
    })

    // ---------------- window ----------------
    visible: cfg.enabled === true
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-dashboard"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // closed: only a thin strip at the bottom edge takes the pointer (it opens the dashboard)
    mask: Region { item: (db.open || db.t > 0.02) ? whole : (db.edgeOn ? edge : nothing) }
    Item { id: whole; anchors.fill: parent }
    Item { id: nothing; width: 0; height: 0 }

    // ---------------- open by dragging up from the bottom edge ----------------
    readonly property bool edgeOn: cfg.edge !== false
    Item {
        id: edge
        // The middle two quarters of the current screen, independent of dashboard width.
        width: db.width / 2
        height: 2
        x: (db.width - width) / 2
        y: db.height - height
        HoverHandler {
            id: edgeHover
            enabled: db.edgeOn
            onHoveredChanged: db.pointerMoved()
        }
        MouseArea {
            id: edgeDrag
            anchors.fill: parent
            enabled: db.edgeOn && !db.open
            acceptedButtons: Qt.LeftButton
            property real startY: 0
            onPressed: function(mouse) { startY = mouse.y }
            onPositionChanged: function(mouse) {
                if (pressed && startY - mouse.y >= 30) db.show("", true)
            }
        }
    }

    // wallpaper preview (Wallpaper tab): shown behind the desktop while you pick, dropped when you leave
    property string previewPath: ""
    property var wallsTab: null
    Timer { id: previewDone; interval: 1600; onTriggered: db.previewPath = "" }
    function keepPreview() { previewDone.restart() }

    NumberAnimation { id: tAnim; target: db; property: "t" }
    onOpenChanged: {
        tAnim.stop()
        tAnim.to = open ? 1 : 0
        tAnim.duration = db.anim === "none" ? 1 : (open ? 560 : 300) / spd
        tAnim.easing.type = Easing.BezierSpline
        tAnim.easing.bezierCurve = open ? [0.05, 0.7, 0.1, 1.0, 1, 1] : [0.3, 0.0, 0.8, 0.15, 1, 1]
        tAnim.start()
        if (open) {
            if (!fullProc.running) fullProc.running = true
            const v = Object.assign({}, visited); v[tab] = true; visited = v
            loadAbout()
            keys.forceActiveFocus()
        } else { leaveTimer.stop(); typing = false; if (!previewDone.running) previewPath = "" }
    }
    onTabChanged: { const v = Object.assign({}, visited); v[tab] = true; visited = v; if (tab === "wallpaper") editing = false }

    // ---------------- settings + open requests ----------------
    // a cheap look at two small files every 0.3 s; the full settings (with bar size and colors)
    // are read when the file changes and every time the dashboard opens
    property string rawCfg: "?"
    Process {
        id: fullProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" config 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const c = text.trim()
                if (c.length > 0 && c !== db.cfgText) {
                    try { db.cfg = JSON.parse(c); db.cfgText = c; db.layouts = db.cfg.layouts || {} } catch (e) { }
                }
            }
        }
    }
    Process {
        id: cfgProc
        // (gaming mode and "no blur & transparency" count as a change of the settings too)
        command: ["bash", "-c", "cat \"$HOME/.config/rice/dashboard.json\" 2>/dev/null; [ -e \"$HOME/.config/rice/gaming-on\" ] && echo G; [ -e \"$HOME/.cache/rice/flat\" ] && echo F; echo '@@'; cat \"$HOME/.cache/rice/dashboard-open\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const q = text.split("@@")
                if (q[0] !== db.rawCfg) { db.rawCfg = q[0]; if (!fullProc.running) fullProc.running = true }
                const o = q.length > 1 ? q[1].trim() : ""
                if (db.cmdSeen && o.length > 0 && o !== db.lastCmd) {
                    const w = o.split(/\s+/)
                    const want = w[1] && w[1] !== "-" ? w[1] : ""
                    if (db.open && w[2] === "toggle" && (want === "" || want === db.tab)) db.close()
                    else if (db.open && want !== "") db.tab = want
                    else db.show(want, false)
                    if (w[3] === "edit") db.editing = true
                }
                db.lastCmd = o
                db.cmdSeen = true
            }
        }
    }
    Timer { interval: 300; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!cfgProc.running) cfgProc.running = true }

    Process {
        id: statsProc
        command: ["bash", "-c", "exec \"$HOME/.local/bin/rice-dashboard\" stats"]
        running: db.open
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    const j = JSON.parse(line)
                    if (j.disks) db.disks = j.disks
                    else j.disks = db.disks
                    db.stats = j
                } catch (e) { }
            }
        }
    }
    Process {
        id: aboutProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-dashboard\" about"]
        stdout: StdioCollector { onStreamFinished: { try { db.about = JSON.parse(text) } catch (e) { } } }
    }

    // ---------------- staying open while the pointer is near ----------------
    // the whole bottom edge counts as "near" while it is open: moving the pointer along the bottom of the
    // screen never closes it (it used to close in the corners and open again on the edge, over and over)
    function inside() { return shellHover.hovered || bridgeHover.hovered || edgeHover.hovered || trayHover.hovered || bottomHover.hovered }
    Item {
        id: bottomZone
        visible: db.open && db.byHover
        width: db.width
        height: 10
        y: db.height - height
        HoverHandler { id: bottomHover; onHoveredChanged: db.pointerMoved() }
    }
    function pointerMoved() {
        if (shellHover.hovered) db.entered = true
        if (inside()) leaveTimer.stop()
        else if (db.open && (db.entered || db.byHover)) leaveTimer.restart()
    }
    Timer {
        id: leaveTimer
        // opened from the edge but not moved into it yet: a little longer
        interval: db.entered ? 380 : 900
        onTriggered: {
            if (db.inside() || db.cfg.close_on_leave === false || db.editing || db.typing || !(db.entered || db.byHover)) return
            // a screenshot is being taken (slurp takes the pointer): stay, so the dashboard can be in the picture
            shotCheck.running = true
        }
    }
    Process {
        id: shotCheck
        command: ["bash", "-c", "[ -e \"$HOME/.cache/rice/shooting\" ] && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "1") { shotWait.restart(); return }
                if (!db.inside() && db.open) db.close()
            }
        }
    }
    // check again until the screenshot is done, then close only if the pointer is not back on the dashboard
    Timer { id: shotWait; interval: 400; onTriggered: if (db.open && !db.inside()) shotCheck.running = true }

    // click outside: close
    MouseArea {
        anchors.fill: parent
        enabled: db.open
        onClicked: db.close()
    }


    // between the edge and the panel: the bar itself counts as "near"
    Item {
        id: bridge
        visible: db.open
        x: shell.x
        width: shell.width * db.sc
        y: db.atTop ? 0 : shell.y + shell.height
        height: db.atTop ? Math.max(0, db.barOff) + 2 : db.height - y
        HoverHandler { id: bridgeHover; onHoveredChanged: db.pointerMoved() }
    }

    // keyboard: Esc, arrows, 1-4
    Item {
        id: keys
        focus: true
        Keys.onPressed: function(e) {
            if (e.key === Qt.Key_Escape) { if (db.editing) db.editing = false; else db.close(); e.accepted = true }
            else if (db.typing) return
            // Wallpaper tab: arrows move through the wallpapers (down / right = next, up / left = back), Enter sets it
            else if (db.tab === "wallpaper" && db.wallsTab && (e.key === Qt.Key_Down || e.key === Qt.Key_Right)) { db.wallsTab.move(1); e.accepted = true }
            else if (db.tab === "wallpaper" && db.wallsTab && (e.key === Qt.Key_Up || e.key === Qt.Key_Left)) { db.wallsTab.move(-1); e.accepted = true }
            else if (db.tab === "wallpaper" && db.wallsTab && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) { db.wallsTab.applySel(); e.accepted = true }
            else if (e.key === Qt.Key_Right || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) { db.tab = db.tabs[(db.curIdx + 1) % db.tabs.length]; e.accepted = true }
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) { db.tab = db.tabs[(db.curIdx - 1 + db.tabs.length) % db.tabs.length]; e.accepted = true }
            else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4 && e.key - Qt.Key_1 < db.tabs.length) { db.tab = db.tabs[e.key - Qt.Key_1]; e.accepted = true }
        }
    }

    // ---------------- edit tray: floats just above the panel ----------------
    Item {
        id: tray
        readonly property bool on: db.editing && db.open && db.tab !== "wallpaper"
        transformOrigin: Item.TopLeft
        scale: db.sc
        width: db.curW - 2 * db.pad
        height: 52
        x: (db.width - width * db.sc) / 2
        y: shell.y - (height + 12) * db.sc + (on ? 0 : 14)
        opacity: on ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        HoverHandler { id: trayHover }
        MouseArea { anchors.fill: parent }
        readonly property var g: db.grids[db.tab] || null
        readonly property var hid: g && g.packed ? (g.packed, g.hidden()) : []
        Rectangle {
            anchors.fill: parent; radius: height / 2
            color: db.p.solidBg
            border.width: 1
            border.color: db.p.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
        }
        Row {
            x: 18; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            DText { text: tray.hid.length ? "Add" : "All cards are on"; font.pixelSize: 12; color: db.p.sub; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: tray.hid
                Rectangle {
                    height: 32; width: ar.implicitWidth + 24; radius: 16
                    color: am.containsMouse ? db.p.primary : db.p.container
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Row {
                        id: ar
                        anchors.centerIn: parent
                        spacing: 4
                        MIcon { name: "add"; glyph: "+"; size: 16; color: am.containsMouse ? db.p.onPrimary : db.p.onContainer; anchors.verticalCenter: parent.verticalCenter }
                        DText { text: modelData.name; font.pixelSize: 12; color: am.containsMouse ? db.p.onPrimary : db.p.onContainer; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tray.g.add(modelData.id) }
                }
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            DText { text: "Drag to move · pull the handles to resize · + fills a gap"; font.pixelSize: 11; color: db.p.sub; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
                height: 32; width: rr.implicitWidth + 24; radius: 16
                color: rm.containsMouse ? db.p.card2 : db.p.container
                DText { id: rr; anchors.centerIn: parent; text: "Reset"; font.pixelSize: 12; color: db.p.onContainer }
                MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: db.resetLayout(db.tab) }
            }
            Rectangle {
                height: 32; width: dn.implicitWidth + 28; radius: 16
                color: dnm.containsMouse ? Qt.lighter(db.p.primary, 1.08) : db.p.primary
                DText { id: dn; anchors.centerIn: parent; text: "Done"; font.pixelSize: 12; font.weight: Font.DemiBold; color: db.p.onPrimary }
                MouseArea { id: dnm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: db.editing = false }
            }
        }
    }

    // ---------------- the panel ----------------
    Item {
        id: shell
        // the full size; what you see grows inside it
        width: db.curW + 2 * db.earR
        height: db.curH
        x: (db.width - width * db.sc) / 2
        y: db.atTop ? db.barOff + (db.attach ? 0 : 10) : db.height - db.barOff - (db.attach ? 0 : 10) - height * db.sc
        transformOrigin: Item.TopLeft
        scale: db.sc
        visible: db.t > 0.003
        clip: db.anim === "slide" && db.t < 0.999

        // how much of it shows (Morph grows out of the bar, Slide comes down, Fade fades in)
        readonly property real e: db.t
        readonly property real sw: db.curW
        readonly property real sh: db.curH
        readonly property real slideY: db.anim === "slide" ? (1 - e) * (db.curH + 4) : 0
        opacity: db.anim === "fade" ? e : (db.anim === "slide" ? Math.min(1, 0.4 + e) : 1)

        HoverHandler { id: shellHover; onHoveredChanged: db.pointerMoved() }
        MouseArea { x: (shell.width - shell.sw) / 2 - db.earR; y: db.atTop ? 0 : shell.height - shell.sh; width: shell.sw + 2 * db.earR; height: shell.sh }

        Item {
            id: frameBox
            width: shell.width
            height: shell.height
            y: shell.slideY
            // shape: flat edge against the bar, curved "ears" where it meets it, round corners away from it
            Canvas {
                id: shape
                anchors.fill: parent
                property real sw: shell.sw
                property real sh: shell.sh
                property color fill: db.p.bg
                property color stroke: db.p.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.07)
                onSwChanged: requestPaint()
                onShChanged: requestPaint()
                onFillChanged: requestPaint()
                onWidthChanged: requestPaint()
                transform: Scale { yScale: db.atTop ? 1 : -1; origin.y: shape.height / 2 }
                onPaint: {
                    const c = getContext("2d")
                    c.reset()
                    const er = db.attach ? Math.min(db.earR, sh / 2) : 0
                    const r = Math.min(db.p.radius, sh / 2, sw / 2)
                    const L = (width - sw) / 2, R = L + sw, B = sh
                    function outline(close) {
                        c.beginPath()
                        if (db.attach) {
                            c.moveTo(L - er, 0)
                            c.arc(L - er, er, er, -Math.PI / 2, 0, false)
                        } else {
                            c.moveTo(L, r)
                            c.arc(L + r, r, r, Math.PI, 1.5 * Math.PI, false)
                            c.lineTo(R - r, 0)
                            c.arc(R - r, r, r, 1.5 * Math.PI, 2 * Math.PI, false)
                            c.lineTo(R, B - r)
                            c.arc(R - r, B - r, r, 0, Math.PI / 2, false)
                            c.lineTo(L + r, B)
                            c.arc(L + r, B - r, r, Math.PI / 2, Math.PI, false)
                            c.closePath()
                            return
                        }
                        c.lineTo(L, B - r)
                        c.arc(L + r, B - r, r, Math.PI, Math.PI / 2, true)
                        c.lineTo(R - r, B)
                        c.arc(R - r, B - r, r, Math.PI / 2, 0, true)
                        c.lineTo(R, er)
                        c.arc(R + er, er, er, Math.PI, 1.5 * Math.PI, false)
                        if (close) c.closePath()
                    }
                    outline(true)
                    c.fillStyle = fill
                    c.fill()
                    outline(false)
                    c.lineWidth = 1
                    c.strokeStyle = stroke
                    c.stroke()
                }
            }
            // a soft colored glow (Aurora)
            Rectangle {
                visible: db.p.glow
                x: (shell.width - shell.sw) / 2 + 30; width: shell.sw - 60
                y: db.atTop ? 0 : shell.height - height
                height: Math.min(140, shell.sh)
                radius: 60
                opacity: 0.12 * db.t
                gradient: Gradient {
                    GradientStop { position: db.atTop ? 0 : 1; color: db.acc }
                    GradientStop { position: db.atTop ? 1 : 0; color: "transparent" }
                }
            }

            // ---------- contents (clipped to the growing shape) ----------
            Item {
                id: clipBox
                x: (shell.width - shell.sw) / 2
                y: db.atTop ? 0 : shell.height - shell.sh
                width: shell.sw
                height: shell.sh
                clip: true
                Item {
                    id: content
                    width: db.curW
                    height: db.curH
                    x: (clipBox.width - width) / 2
                    y: db.atTop ? 0 : clipBox.height - height
                    opacity: 1

                    // ---------- tabs ----------
                    Item {
                        id: head
                        x: db.pad; y: 10
                        width: parent.width - 2 * db.pad - (canEdit ? 50 : 0)
                        height: db.headH - 14
                        readonly property bool canEdit: db.tab !== "wallpaper"
                        readonly property real tw: width / Math.max(1, db.tabs.length)
                        readonly property var names: ({ dashboard: "Dashboard", wallpaper: "Wallpaper", performance: "Performance", about: "About" })
                        readonly property var icons: ({ dashboard: ["space_dashboard", 0xF056E], wallpaper: ["wallpaper", 0xF02E9],
                                                        performance: ["speed", 0xF04C5], about: ["info", 0xF02FD] })
                        Behavior on width { NumberAnimation { duration: 260 } }
                        Rectangle {
                            visible: db.p.tabStyle === "segment"
                            anchors.fill: parent
                            radius: height / 2
                            color: db.p.card
                        }
                        Rectangle {
                            id: ind
                            readonly property bool under: db.p.tabStyle === "underline"
                            function labelW(i) { const it = tabRep.itemAt(i); return it ? it.labelWidth : 60 }
                            readonly property real lw: under ? labelW(db.curIdx) + 22 : head.tw - (db.p.tabStyle === "segment" ? 8 : 14)
                            x: db.curIdx * head.tw + (head.tw - lw) / 2
                            y: under ? head.height - 3 : (db.p.tabStyle === "segment" ? 4 : 2)
                            width: lw
                            height: under ? 3 : head.height - (db.p.tabStyle === "segment" ? 8 : 4)
                            radius: under ? 1.5 : height / 2
                            color: under ? db.p.primary : (db.p.tabStyle === "segment" ? db.p.primary : db.p.container)
                            Behavior on x { NumberAnimation { duration: 460 / db.spd; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.36, 0.64, 1, 1, 1] } }
                            Behavior on width { NumberAnimation { duration: 320 / db.spd; easing.type: Easing.OutCubic } }
                        }
                        Rectangle {
                            visible: db.p.tabStyle === "underline"
                            anchors.left: parent.left; anchors.right: parent.right
                            y: parent.height
                            height: 1
                            color: db.p.track
                        }
                        Row {
                            anchors.fill: parent
                            Repeater {
                                id: tabRep
                                model: db.tabs
                                delegate: Item {
                                    id: tb
                                    readonly property bool on: db.curIdx === index
                                    readonly property real labelWidth: lab.implicitWidth
                                    width: head.tw
                                    height: head.height
                                    readonly property color fg: on ? (db.p.tabStyle === "segment" ? db.p.onPrimary : db.p.primary) : db.p.sub
                                    Rectangle {
                                        visible: db.p.tabStyle !== "segment"
                                        anchors.fill: parent; anchors.margins: 2
                                        radius: height / 2
                                        color: tm.containsMouse && !tb.on ? db.p.card : "transparent"
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                    }
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        MIcon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            name: (head.icons[modelData] || ["info", 0xF02FD])[0]
                                            glyph: db.md((head.icons[modelData] || ["info", 0xF02FD])[1])
                                            size: 20; color: tb.fg
                                            Behavior on color { ColorAnimation { duration: 220 } }
                                            scale: tb.on ? 1.08 : 1
                                            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                                        }
                                        DText { id: lab; anchors.horizontalCenter: parent.horizontalCenter; text: head.names[modelData] || modelData; font.pixelSize: 12; font.weight: tb.on ? Font.DemiBold : Font.Medium; color: tb.fg
                                            Behavior on color { ColorAnimation { duration: 220 } } }
                                    }
                                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: db.tab = modelData }
                                }
                            }
                        }
                    }
                    // edit button
                    Rectangle {
                        visible: head.canEdit
                        anchors.right: parent.right; anchors.rightMargin: db.pad
                        y: head.y + (head.height - height) / 2
                        width: 40; height: 40; radius: 20
                        color: db.editing ? db.p.primary : (edm.containsMouse ? db.p.card2 : db.p.card)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        MIcon { anchors.centerIn: parent; name: db.editing ? "check" : "edit"; glyph: db.editing ? db.md(0xF012C) : ""; size: 19; color: db.editing ? db.p.onPrimary : db.p.text }
                        MouseArea { id: edm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: db.editing = !db.editing }
                    }

                    // ---------- tab pages ----------
                    Item {
                        id: body
                        x: db.pad
                        y: db.headH + 4
                        width: parent.width - 2 * db.pad
                        height: db.tabH(db.tab)
                        Repeater {
                            model: db.tabs
                            delegate: Item {
                                id: page
                                readonly property int dist: index - db.curIdx
                                width: db.tabW(modelData) - 2 * db.pad
                                height: db.tabH(modelData)
                                x: dist * 90 + (body.width - width) / 2
                                opacity: dist === 0 ? 1 : 0
                                visible: opacity > 0.01
                                enabled: dist === 0
                                Behavior on x { NumberAnimation { duration: 460 / db.spd; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] } }
                                Behavior on opacity { NumberAnimation { duration: 240 / db.spd; easing.type: Easing.OutCubic } }
                                readonly property bool liveNow: db.open && db.t > 0.3 && dist === 0
                                Loader {
                                    anchors.fill: parent
                                    active: db.visited[modelData] === true
                                    sourceComponent: modelData === "dashboard" ? homeC : modelData === "wallpaper" ? wallC
                                                   : modelData === "performance" ? perfC : aboutC
                                }
                                Component { id: homeC; DashHome { d: db; live: page.liveNow } }
                                Component { id: wallC; DashWalls { d: db; live: page.liveNow } }
                                Component { id: perfC; DashPerf { d: db; live: page.liveNow } }
                                Component { id: aboutC; DashAbout { d: db; live: page.liveNow } }
                            }
                        }
                    }

                    // ---------- toast ----------
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - height - 14
                        width: tt.implicitWidth + 28; height: 32; radius: 16
                        color: db.p.primary
                        opacity: db.toastText !== "" ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        DText { id: tt; anchors.centerIn: parent; text: db.toastText; font.pixelSize: 12; color: db.p.onPrimary }
                    }
                }
            }
        }
    }

    // the click sound for everything clickable on the dashboard (Settings > Sfx & sounds)
    SfxTap { visible: db.open }
}
