import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root
    property var cfg: ({ widgets: {}, clock: {}, dock: {}, lock: {} })
    property string cfgText: ""
    property string wallpaper: ""
    property bool locked: false
    readonly property string home: Quickshell.env("HOME")
    property string primaryMonitor: ""
    readonly property var scr: {
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === primaryMonitor) return screens[i]
        return screens.length > 0 ? screens[0] : null
    }
    Process {
        id: primaryRead
        command: ["sh", "-c", "cat \"$HOME/.config/phantom-shell/primary-monitor\" 2>/dev/null"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.primaryMonitor = text.trim() }
    }
    Timer { interval: 1000; repeat: true; running: true; onTriggered: if (!primaryRead.running) primaryRead.running = true }
    readonly property int sw: scr ? scr.width : 1920
    readonly property int sh: scr ? scr.height : 1080
    // Keep in sync with the installed Phantom bar's default thickness.
    readonly property int barHeight: 40
    readonly property string placement: cfg.clock && cfg.clock.placement ? cfg.clock.placement : "draggable"

    function wc(id) { return cfg.widgets && cfg.widgets[id] ? cfg.widgets[id] : ({}) }
    function on(id) { return wc(id).enabled === true }
    function savePos(id, x, y) {
        Quickshell.execDetached([home + "/.local/bin/desktop-set", "pos", id, String(x), String(y)])
    }

    // ---------------- widget editor ----------------
    readonly property bool editing: cfg.editing === true
    // what the editor offers; free = free width and height instead of scaling
    readonly property var catalog: [
        { id: "visualizer", name: "Visualizer", icon: "\udb85\udc7d", free: true,
          styles: [["bars", "Bars"], ["mirror", "Mirror"], ["wave", "Wave"], ["dots", "Dots"]] },
        { id: "clock", name: "Clock", icon: "\uf017", styles: [["digital", "Digital"], ["cookie", "Cookie"], ["pixel", "Pixel"]] },
        { id: "media", name: "Music", icon: "\uf001", card: true },
        { id: "weather", name: "Weather", icon: "\uf0c2", card: true },
        { id: "calendar", name: "Calendar", icon: "\uf073", card: true },
        { id: "usercard", name: "User", icon: "\uf007", card: true },
        { id: "resources", name: "CPU & RAM", icon: "\uf2db", card: true },
        { id: "battery", name: "Battery", icon: "\uf240", card: true }
    ]
    property var wins: ({})
    function reg(id, w) { const n = Object.assign({}, wins); n[id] = w; wins = n }
    function ds(args) { Quickshell.execDetached([home + "/.local/bin/desktop-set"].concat(args.map(function(a) { return String(a) }))) }
    function enabledOf(id) { return id === "clock" ? !!(cfg.clock && cfg.clock.enabled === true) : on(id) }
    function styleOf(id) {
        const w = wins[id]
        if (w && w.sty) return w.sty
        return id === "clock" ? (cfg.clock && cfg.clock.style ? cfg.clock.style : "digital") : (id === "visualizer" ? "bars" : "")
    }
    // optimistic local change, the file follows a moment later
    function patch(id, obj) {
        const c = JSON.parse(JSON.stringify(cfg))
        if (id === "clock") c.clock = Object.assign(c.clock || {}, obj)
        else { c.widgets = c.widgets || {}; c.widgets[id] = Object.assign(c.widgets[id] || {}, obj) }
        cfg = c
    }
    function saveGeom(id) {
        const w = wins[id]
        if (!w) return
        const free = id === "visualizer"
        patch(id, free ? { x: Math.round(w.px), y: Math.round(w.py), w: Math.round(w.fw), h: Math.round(w.fh) }
                       : { x: Math.round(w.px), y: Math.round(w.py), scale: Math.round(w.sc * 1000) / 1000 })
        ds(["geom", id, Math.round(w.px), Math.round(w.py), free ? "-" : (Math.round(w.sc * 1000) / 1000), free ? Math.round(w.fw) : "-", free ? Math.round(w.fh) : "-"])
    }
    function wset(id, key, val) { ds(["wset", id, key, val]) }
    function setStyle(id, v) {
        const w = wins[id]
        if (w) w.sty = v
        if (id === "clock") { patch("clock", { style: v }); ds(["clock", "style", v]) }
        else { patch(id, { style: v }); wset(id, "style", v) }
    }
    function addWidget(id) {
        const w = wins[id]
        let geo = {}
        if (w && id !== "visualizer" && !(id === "clock" ? (cfg.clock && cfg.clock.x !== undefined) : (wc(id).x !== undefined))) {
            // a new widget lands in the middle of the screen
            geo = { x: Math.round((sw - w.dispW) / 2), y: Math.round((sh - w.dispH) / 2) }
        }
        if (id === "clock") { patch("clock", Object.assign({ enabled: true, placement: "draggable" }, geo)); ds(["clock", "enabled", "on"]) }
        else { patch(id, Object.assign({ enabled: true }, geo)); ds(["widget", id, "on"]) }
        if (geo.x !== undefined) ds(["geom", id, geo.x, geo.y])
    }
    function removeWidget(id) {
        if (id === "clock") { patch("clock", { enabled: false }); ds(["clock", "enabled", "off"]) }
        else { patch(id, { enabled: false }); ds(["widget", id, "off"]) }
    }
    function resetWidget(id) {
        const w = wins[id]
        ds(["reset-widget", id])
        if (w) { w.sc = 1; w.op = 1; w.bgv = 1; w.flp = false; if (!w.autoBottom && w.fixedCorner === "") { w.px = w.defX; w.py = w.defY; w.fw = w.defW }; w.fh = w.defH }
    }
    function resetAll() { ds(["reset-pos"]) }
    function finishEditing() { const c = JSON.parse(JSON.stringify(cfg)); c.editing = false; cfg = c; ds(["edit", "off"]) }

    Process {
        id: cfgProc
        // desktop.json, then "@@flat" while rice-effects has blur and transparency off
        command: ["bash", "-c", "cat \"$HOME/.config/rice/desktop.json\" 2>/dev/null; [ -e \"$HOME/.cache/rice/flat\" ] && printf '@@flat'; [ -e \"$HOME/.cache/rice/lite\" ] && printf '@@lite'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const fl = text.indexOf("@@flat") >= 0
                if (fl !== Look.flat) Look.flat = fl
                const lt = text.indexOf("@@lite") >= 0
                if (lt !== Look.lite) Look.lite = lt
                const t = text.replace("@@flat", "").replace("@@lite", "")
                if (t.trim().length === 0 || t === root.cfgText) return
                try {
                    const j = JSON.parse(t)
                    root.cfgText = t
                    root.cfg = j
                    Look.blur = j.widgetBlur !== false
                } catch (e) { }
            }
        }
    }
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: { if (!cfgProc.running) cfgProc.running = true }
    }

    Process {
        id: wpProc
        command: ["bash", "-c", "awww query 2>/dev/null | grep -o 'image: .*' | head -1 | sed 's/^image: //'"]
        stdout: StdioCollector { onStreamFinished: root.wallpaper = text.trim() }
    }
    Timer {
        interval: 6000
        running: !!(root.placement !== "draggable" && root.cfg.clock && root.cfg.clock.enabled === true)
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!wpProc.running) wpProc.running = true }
    }

    Process {
        id: lockProc
        command: ["bash", "-c", "pgrep -x hyprlock >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.locked = text.trim() === "1" }
    }
    Timer {
        interval: 2000
        running: !!(root.cfg.clock && root.cfg.clock.onlyLocked === true)
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!lockProc.running) lockProc.running = true }
    }

    // ---- auto-hide (Settings > Desktop): widgets fade out while windows are open on this screen
    readonly property bool autoHide: cfg.autoHide !== false || Look.lite
    property bool busy: false
    readonly property bool hideWidgets: autoHide && busy && !editing && !locked
    readonly property string busyMonitor: scr ? scr.name : ""
    onBusyMonitorChanged: syncBusyWatcher()
    onAutoHideChanged: syncBusyWatcher()
    function syncBusyWatcher() {
        const wanted = autoHide ? busyMonitor : ""
        if (busyProc.running) {
            if (busyProc.monitor !== wanted) {
                busyProc.restartPending = true
                busyProc.running = false
            }
        } else {
            busy = false
            if (wanted !== "") {
                busyProc.monitor = wanted
                busyProc.running = true
            }
        }
    }
    Process {
        id: busyProc
        property string monitor: ""
        property bool restartPending: false
        command: ["bash", "-c", "exec \"$HOME/.local/bin/rice-busy\" \"$1\"", "_", monitor]
        stdout: SplitParser { onRead: function(line) { root.busy = line.trim() === "1" } }
        onRunningChanged: if (!running) {
            root.busy = false
            if (restartPending) {
                restartPending = false
                Qt.callLater(root.syncBusyWatcher)
            }
        }
    }
    Component.onCompleted: syncBusyWatcher()

    // ---- clock
    WidgetWindow {
        id: clockWin
        screen: root.scr
        wid: "clock"
        fixedCorner: root.placement === "draggable" ? "top-left" : ""
        topInset: root.barHeight
        wc: root.placement === "draggable" ? (root.cfg.clock ? root.cfg.clock : ({})) : ({})
        draggable: root.placement === "draggable"
        editing: root.editing
        hidden: root.hideWidgets
        active: !!(root.cfg.clock && root.cfg.clock.enabled === true && (root.cfg.clock.onlyLocked !== true || root.locked || root.editing))
        bw: root.sw
        bh: root.sh
        cw: clk.natW
        ch: clk.natH
        defX: root.placement === "draggable" || clk.fx < 0 ? 40 : Math.round(Math.max(30, Math.min(root.sw - cw - 30, clk.fx * root.sw - cw / 2)))
        defY: root.placement === "draggable" || clk.fy < 0 ? 40 : Math.round(Math.max(60, Math.min(root.sh - ch - 30, clk.fy * root.sh - ch / 2)))
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg("clock", clockWin)
        ClockWidget {
            id: clk
            anchors.fill: parent
            clockStyle: clockWin.sty !== "" ? clockWin.sty : (root.cfg.clock && root.cfg.clock.style ? root.cfg.clock.style : "digital")
            mode: root.placement
            wallpaper: root.wallpaper
            bw: root.sw
            bh: root.sh
        }
    }

    // ---- widgets (positions, sizes and looks come from the widget editor)
    WidgetWindow {
        id: weatherWin
        screen: root.scr
        wid: "weather"; wc: root.wc("weather"); active: root.on("weather"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 300; ch: 120; defX: 40; defY: 370
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, weatherWin)
        WeatherWidget { anchors.fill: parent; running: root.on("weather") && !root.hideWidgets; bg: weatherWin.bgv }
    }
    WidgetWindow {
        id: mediaWin
        screen: root.scr
        wid: "media"; wc: root.wc("media"); active: root.on("media"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 400; ch: 120; defX: root.sw - 440; defY: 60
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, mediaWin)
        MediaWidget { anchors.fill: parent; bg: mediaWin.bgv }
    }
    WidgetWindow {
        id: calWin
        screen: root.scr; fixedCorner: "bottom-right"
        wid: "calendar"; wc: root.wc("calendar"); active: root.on("calendar"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 340; ch: 340; defX: root.sw - 380; defY: 200
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, calWin)
        CalendarWidget { anchors.fill: parent; bg: calWin.bgv }
    }
    WidgetWindow {
        id: userWin
        screen: root.scr
        wid: "usercard"; wc: root.wc("usercard"); active: root.on("usercard"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 340; ch: 120; defX: root.sw - 380; defY: 560
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, userWin)
        UserCard { anchors.fill: parent; bg: userWin.bgv }
    }
    WidgetWindow {
        id: resWin
        screen: root.scr; fixedCorner: "bottom-left"
        wid: "resources"; wc: root.wc("resources"); active: root.on("resources"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 160; ch: 380; defX: 40; defY: root.sh - 440
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, resWin)
        ResourcesWidget { anchors.fill: parent; running: root.on("resources") && !root.hideWidgets; bg: resWin.bgv }
    }
    WidgetWindow {
        id: batWin
        screen: root.scr
        wid: "battery"; wc: root.wc("battery"); active: root.on("battery"); editing: root.editing; hidden: root.hideWidgets
        bw: root.sw; bh: root.sh; cw: 280; ch: 110; defX: 40; defY: 520
        onMoved: function(id, x, y) { root.savePos(id, x, y) }
        Component.onCompleted: root.reg(wid, batWin)
        BatteryWidget { anchors.fill: parent; running: root.on("battery") && !root.hideWidgets; bg: batWin.bgv }
    }
    // audio visualizer: see-through, at the bottom of the screen by default, never takes clicks
    WidgetWindow {
        id: vizWin
        screen: root.scr
        wid: "visualizer"; wc: root.wc("visualizer"); active: root.on("visualizer"); editing: root.editing; hidden: root.hideWidgets
        free: true; passive: true; autoBottom: true
        bw: root.sw; bh: root.sh
        defW: root.sw; defH: 180; defX: 0; defY: root.sh - 180
        Component.onCompleted: root.reg(wid, vizWin)
        VizWidget { anchors.fill: parent; running: root.on("visualizer") && !root.hideWidgets && !Look.lite; style: vizWin.sty !== "" ? vizWin.sty : "bars"; flip: vizWin.flp }
    }

    EditorWindow { root: root; screen: root.scr }

    // ---- dashboard (middle of the bar edge, SUPER + W for wallpapers)
    Dashboard { id: dash; screen: root.scr }
    WallPreview { path: dash.previewPath; screen: root.scr }

    Dock { dc: root.cfg.dock ? root.cfg.dock : ({}) }

    // ---- hot corner (Settings > Hot corners)
    HotCorner { screen: root.scr }

}
