// The existing Phantom hot-corner content and notification dock on one surface.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

Item {
    id: root
    required property ScreenState screenState
    required property var targetScreen
    property var cfg: ({ enabled: false })
    property var status: ({})
    property bool opened: false
    property bool armed: true
    property string lastOpenCmd: ""
    property bool cmdSeen: false
    property real dashboardSpeed: 1
    property bool shownNotifications: false
    readonly property real reveal: opened ? 1 : 0
    readonly property alias pressed: cornerMouse.pressed
    readonly property bool panelReady: control.status === Loader.Ready
    readonly property bool enabledHere: cfg.enabled === true && (cfg.corner ?? "bottom-right") === "bottom-right"
    readonly property real scaleFactor: Math.max(0.75, Math.min(1.5, cfg.scale || 1))
    readonly property real panelWidth: Math.max(0, Math.min(width - 20, (control.item?.width ?? 400) * scaleFactor))
    readonly property real panelHeight: (control.item?.height ?? 0) * scaleFactor
    readonly property real topInset: 48
    readonly property real notificationHeight: Math.min(360, Math.max(0, height - topInset - panelHeight - 30))
    readonly property real inputX: width - panelWidth - 10
    readonly property real inputHeight: panelHeight + (shownNotifications ? notificationHeight + 10 : 0)
    readonly property real inputY: height - inputHeight - 10
    signal hoverChanged(bool hovered)

    function close(): void { opened = false; screenState.sidebar = false }
    function openBoth(): void { opened = true; screenState.sidebar = true }
    function refresh(): void { if (!stateProc.running) stateProc.running = true }
    function run(cmd: string, arg: string, closeFirst: bool): void {
        if (closeFirst) close();
        const s = Object.assign({}, status);
        if (cmd === "close") return;
        if (cmd === "dnd") {
            Notifs.dnd = !Notifs.dnd;
            s.dnd = Notifs.dnd;
            status = s;
            return;
        }
        if (cmd === "allapps") Quickshell.execDetached(["sh", "-c", 'sleep 0.25; "$HOME/.local/bin/phantom-app-launcher"']);
        else if (cmd === "settings") Quickshell.execDetached(["sh", "-c", '"$HOME/.local/bin/rice-settings"']);
        else if (cmd === "wallpaper") Quickshell.execDetached(["sh", "-c", 'sleep 0.25; "$HOME/.local/bin/rice-wallpaper"']);
        else if (cmd === "lock") Quickshell.execDetached(["sh", "-c", 'sleep 0.3; loginctl lock-session || hyprlock']);
        else {
            if (["awake", "wifi", "bluetooth", "gaming"].includes(cmd)) s[cmd] = !s[cmd];
            if (cmd === "mic") s.mic_muted = !s.mic_muted;
            if (cmd === "record" && arg === "stop") s.recording = false;
            if (cmd === "wall") s.wall = arg;
            if (cmd === "scheme") s.scheme = arg;
            status = s;
            Quickshell.execDetached(["sh", "-c", 'sleep "$3"; "$HOME/.local/bin/rice-hotcorner" "$1" "$2"', "_", cmd, arg, closeFirst ? "0.35" : "0"]);
        }
        soon.restart(); later.restart();
    }
    Process {
        id: cfgProc
        command: ["sh", "-c", 'cat "$HOME/.config/rice/hotcorner.json" 2>/dev/null || "$HOME/.local/bin/rice-hotcorner" config; echo; echo "@@"; cat "$HOME/.cache/rice/hotcorner-open" 2>/dev/null; echo "@@"; [ -e "$HOME/.cache/rice/flat" ] && echo flat; echo; echo "@@"; cat "$HOME/.config/rice/dashboard.json" 2>/dev/null']
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.split("@@");
                try {
                    const c = JSON.parse(p[0]);
                    if (p[2]?.trim() === "flat") { c.transparency = false; c.blur = false; }
                    root.cfg = c;
                } catch (e) {}
                try { root.dashboardSpeed = Number(JSON.parse(p[3]).speed) || 1; } catch (e) { root.dashboardSpeed = 1; }
                const request = p[1]?.trim() ?? "";
                if (root.cmdSeen && request && request !== root.lastOpenCmd && root.enabledHere) root.opened = true;
                root.lastOpenCmd = request; root.cmdSeen = true;
            }
        }
    }
    Process {
        id: stateProc
        command: ["sh", "-c", '"$HOME/.local/bin/rice-hotcorner" state']
        stdout: StdioCollector { onStreamFinished: { try { const s = JSON.parse(text); s.dnd = Notifs.dnd; root.status = s; } catch (e) {} } }
    }
    Timer { interval: 400; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!cfgProc.running) cfgProc.running = true }
    Timer { interval: 1500; running: root.opened; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Timer { id: soon; interval: 450; onTriggered: root.refresh() }
    Timer { id: later; interval: 1600; onTriggered: root.refresh() }
    Timer { id: leaveTimer; interval: 380; onTriggered: if (root.cfg.close_on_leave !== false && !panelHover.hovered && !cornerHover.hovered) root.close() }
    Timer { id: openTimer; interval: Math.max(250, root.cfg.delay ?? 150); onTriggered: if (!cornerMouse.pressed && cornerHover.hovered) root.opened = true }
    Timer { id: closeHold; interval: 1000 }

    onOpenedChanged: {
        if (opened) { closeHold.stop(); shownNotifications = screenState.sidebar; screenState.session = false; refresh(); leaveTimer.stop(); }
        else { closeHold.restart(); screenState.sidebar = false; }
    }
    Connections { target: root.screenState; function onSidebarChanged(): void { if (root.screenState.sidebar) root.opened = true; if (root.opened) root.shownNotifications = root.screenState.sidebar; } }

    MouseArea {
        id: cornerMouse
        x: parent.width - width
        y: parent.height - height
        width: 24; height: 24
        enabled: root.enabledHere
        hoverEnabled: true
        property real startX
        property real startY
        property bool dragged
        function handleDrag(dx: real, dy: real): void {
            if (!dragged && (dx < -35 || dy < -35)) { dragged = true; root.openBoth(); }
        }
        onEntered: { leaveTimer.stop(); if (root.armed && !root.opened && !pressed) openTimer.restart(); }
        onExited: { openTimer.stop(); root.armed = true; if (root.opened) leaveTimer.restart(); }
        onPressed: event => { openTimer.stop(); startX = event.x; startY = event.y; dragged = false; }
        onPositionChanged: event => {
            if (pressed) handleDrag(event.x - startX, event.y - startY);
        }
        onReleased: if (!dragged && containsMouse) root.opened = !root.opened
        HoverHandler { id: cornerHover }
    }
    PanelWindow {
        id: panelWindow
        screen: root.targetScreen
        visible: root.opened
        color: "transparent"
        anchors.right: true
        anchors.bottom: true
        margins.right: 10
        margins.bottom: 10
        implicitWidth: root.panelWidth
        implicitHeight: root.inputHeight
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "phantom-corner"
        WlrLayershell.keyboardFocus: root.screenState.sidebar ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    Item {
        id: panels
        x: 0
        y: 0
        width: root.panelWidth
        height: root.inputHeight
        HoverHandler {
            id: panelHover
            onHoveredChanged: { if (hovered) leaveTimer.stop(); else if (root.opened) leaveTimer.restart(); }
        }
        NotificationPanel {
            x: 0; y: 0
            width: panels.width
            height: root.notificationHeight
            screenState: root.screenState
            backgroundColor: control.item?.backgroundColor ?? "transparent"
            cardColor: Qt.rgba(1, 1, 1, root.cfg.card_alpha !== undefined ? root.cfg.card_alpha : 0.05)
            visible: root.shownNotifications
        }
        Loader {
            id: control
            x: 0
            y: panels.height - root.panelHeight
            scale: root.scaleFactor
            transformOrigin: Item.TopLeft
            source: "file://" + Quickshell.shellDir + "/../rice-desktop/HotCornerPanel.qml"
            onLoaded: {
                item.cfg = Qt.binding(() => root.cfg);
                item.st = Qt.binding(() => root.status);
                // Keep the content populated while the tile collapses; otherwise the
                // panel resets its sections as soon as opened turns false.
                item.open = Qt.binding(() => root.opened || closeHold.running);
            }
            Connections {
                target: control.item
                function onAct(cmd, arg, closeFirst): void { root.run(cmd, arg, closeFirst); }
                function onLaunch(entry): void { root.close(); entry.execute(); }
            }
        }
        Loader {
            anchors.fill: parent
            active: root.opened
            source: "file://" + Quickshell.shellDir + "/../rice-desktop/SfxTap.qml"
            onLoaded: item.root = panels
        }
    }
    }
}
