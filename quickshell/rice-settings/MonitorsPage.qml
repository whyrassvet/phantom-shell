import Quickshell
import Quickshell.Io
import QtQuick

Column {
    id: page
    property var ctl
    property var mons: []
    property string primaryMonitor: ""
    property int vrrMode: -1
    property int countdown: 0
    spacing: 14

    Process {
        id: monProc
        command: ["bash", "-c", "\"$HOME/.local/bin/hypr-set\" monitors"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { page.mons = JSON.parse(text) } catch (e) { } }
        }
    }

    Timer { id: refresh; interval: 1500; onTriggered: monProc.running = true }

    Process {
        id: vrrRead
        command: ["hyprctl", "-j", "getoption", "misc:vrr"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { const v = JSON.parse(text).int; page.vrrMode = Number.isInteger(v) ? v : -1 }
                catch (e) { page.vrrMode = -1 }
            }
        }
    }
    Process {
        id: vrrWrite
        onExited: function(code) {
            page.ctl.status = code === 0 ? "VRR updated" : "Could not update VRR"
            vrrRead.running = true
        }
    }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: if (!vrrRead.running && !vrrWrite.running) vrrRead.running = true }

    ToggleRow {
        width: parent.width
        label: "Variable refresh rate (VRR)"
        desc: "Applies to all supported monitors. Turning on uses Hyprland's always-on mode."
        enabled: page.vrrMode >= 0 && !vrrWrite.running
        checked: page.vrrMode > 0
        onToggled: function(v) {
            vrrWrite.command = [Quickshell.env("HOME") + "/.local/bin/hypr-set", "vrr-set", v ? "1" : "0"]
            vrrWrite.running = true
        }
    }

    Process {
        id: primaryRead
        command: ["sh", "-c", "cat \"$HOME/.config/phantom-shell/primary-monitor\" 2>/dev/null"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.primaryMonitor = text.trim() }
    }
    Process {
        id: primaryWrite
        onExited: function(code) {
            if (code === 0) page.ctl.status = "Primary monitor saved"
            else page.ctl.status = "Could not save primary monitor"
            primaryRead.running = true
        }
    }
    Timer { interval: 2000; running: true; repeat: true; onTriggered: if (!primaryRead.running) primaryRead.running = true }
    function setPrimary(name) {
        if (primaryWrite.running) return
        primaryWrite.command = ["python3", "-c", "import os,sys,tempfile\np=os.path.expanduser('~/.config/phantom-shell/primary-monitor')\nos.makedirs(os.path.dirname(p),exist_ok=True)\nf,t=tempfile.mkstemp(dir=os.path.dirname(p),prefix='.primary-monitor-')\nwith os.fdopen(f,'w') as out: out.write(sys.argv[1]+'\\n')\nos.replace(t,p)", name]
        primaryWrite.running = true
    }

    T { text: "Primary monitor"; font.bold: true; font.pixelSize: 16 }
    T { text: "Dashboard, hot corner and desktop widgets. If unavailable, another screen is used."; color: "#8a8a8a"; wrapMode: Text.WordWrap; width: parent.width }
    Seg {
        options: page.mons.map(m => ({ label: m.name, value: m.name }))
        current: page.primaryMonitor
        onChosen: function(v) { page.setPrimary(v) }
    }

    Timer {
        interval: 1000
        repeat: true
        running: page.countdown > 0
        onTriggered: {
            page.countdown -= 1
            if (page.countdown === 0) page.revert()
        }
    }

    function ratesFor(m, res) {
        for (let i = 0; i < m.modes.length; i++) {
            if (m.modes[i].res === res) return m.modes[i].rates
        }
        return []
    }
    function apply(name, res, rate, scale) {
        ctl.hrun(["monitor-apply", name, res, rate, scale], "Display changed")
        countdown = 12
        refresh.restart()
    }
    function keep() { ctl.hrun(["monitor-keep"], "Display settings saved"); countdown = 0; refresh.restart() }
    function revert() { ctl.hrun(["monitor-revert"], "Reverted display settings"); countdown = 0; refresh.restart() }

    Rectangle {
        visible: page.countdown > 0
        width: parent.width
        height: 56
        radius: 12
        color: "#1c1c1c"
        border.width: 1
        border.color: "#3a3a3a"
        T {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "Keep these display settings? Reverting in " + page.countdown + " s"
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Pill { label: "Keep"; onClicked: page.keep() }
            Pill { label: "Revert"; onClicked: page.revert() }
        }
    }

    Repeater {
        model: page.mons
        delegate: Rectangle {
            id: card
            property var m: modelData
            property string curRes: m.width + "x" + m.height
            width: page.width
            height: inner.implicitHeight + 28
            radius: 12
            color: "#141414"
            border.width: 1
            border.color: "#1f1f1f"

            Column {
                id: inner
                x: 16
                y: 14
                width: parent.width - 32
                spacing: 8

                T { text: card.m.name + "   " + card.curRes + " @ " + card.m.rate + " Hz   scale " + card.m.scale; font.bold: true }

                T { text: "Resolution"; color: "#8a8a8a"; font.pixelSize: 12 }
                Seg {
                    options: card.m.modes.slice(0, 5).map(x => ({ label: x.res, value: x.res }))
                    current: card.curRes
                    onChosen: function(v) {
                        const r = page.ratesFor(card.m, v)
                        page.apply(card.m.name, v, r.length > 0 ? r[0] : card.m.rate, card.m.scale)
                    }
                }

                T { text: "Refresh rate"; color: "#8a8a8a"; font.pixelSize: 12 }
                Seg {
                    options: page.ratesFor(card.m, card.curRes).slice(0, 6).map(x => ({ label: x + " Hz", value: x }))
                    current: card.m.rate
                    onChosen: function(v) { page.apply(card.m.name, card.curRes, v, card.m.scale) }
                }

                T { text: "Scale"; color: "#8a8a8a"; font.pixelSize: 12 }
                Seg {
                    options: [
                        { label: "1x", value: "1" },
                        { label: "1.25x", value: "1.25" },
                        { label: "1.5x", value: "1.5" },
                        { label: "2x", value: "2" }
                    ]
                    current: String(card.m.scale)
                    onChosen: function(v) { page.apply(card.m.name, card.curRes, card.m.rate, v) }
                }
            }
        }
    }

    T {
        visible: page.mons.length === 0
        text: "No monitors found."
        color: "#8a8a8a"
    }
}
