import Quickshell
import Quickshell.Io
import QtQuick

// About tab: this computer, your distro, DarkShadow's Shell (with updates). Cards can be edited.
Item {
    id: ab
    property var d
    property bool live: false
    readonly property var p: d.p
    readonly property var a: d.about || ({})
    readonly property var di: a.distro || ({})
    property var up: ({ installed: "", latest: "", update: false, news: [], changes: 0 })
    property bool checking: false

    Process {
        id: upProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-update\" check --json 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { try { ab.up = JSON.parse(text) } catch (e) { } ab.checking = false } }
    }
    Process {
        id: upCache
        command: ["bash", "-c", "cat \"$HOME/.cache/rice/update.json\" 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { try { ab.up = JSON.parse(text) } catch (e) { } } }
    }
    onLiveChanged: if (live) { upCache.running = true; checking = true; upProc.running = true; d.loadAbout() }

    function gib(b) { return (b / 1073741824).toFixed(1) + " GiB" }
    function open(u) { if (u) { Quickshell.execDetached(["xdg-open", u]); d.close() } }

    DashGrid {
        anchors.fill: parent
        d: ab.d
        tabId: "about"
        rows: 1
        live: ab.live
        catalog: [
            { id: "system", name: "This computer", sizes: [[5, 1], [4, 1], [6, 1]] },
            { id: "distro", name: "Distro", sizes: [[3, 1], [4, 1], [2, 1]] },
            { id: "rice", name: "DarkShadow's Shell", sizes: [[4, 1], [3, 1], [5, 1]] }
        ]
        defaults: [{ id: "system", w: 5, h: 1 }, { id: "distro", w: 3, h: 1 }, { id: "rice", w: 4, h: 1 }]
        comps: ({ system: sysC, distro: distC, rice: riceC })
    }

    Component {
        id: sysC
        DCard {
            id: sys
            p: ab.p
            Row {
                x: 18; y: 14
                spacing: 8
                MIcon { name: "developer_board"; glyph: ab.d.md(0xF0697); size: 19; color: ab.p.primary; anchors.verticalCenter: parent.verticalCenter }
                DText { text: "This computer"; font.pixelSize: 17; font.weight: Font.DemiBold; color: ab.p.text }
            }
            Column {
                x: 18; y: 48
                width: parent.width - 36
                spacing: 2
                Repeater {
                    model: [
                        { n: "developer_board", g: 0xF0697, t: "Board", v: ab.a.board || ab.a.product || "Unknown" },
                        { n: "laptop", g: 0xF0379, t: "Model", v: ab.a.product || "" },
                        { n: "memory", g: 0xF061A, t: "CPU", v: (ab.a.cpu || "") + (ab.a.cores ? "  ·  " + ab.a.cores + " threads" : "") },
                        { n: "monitor", g: 0xF08AE, t: "GPU", v: ab.a.gpu || "" },
                        { n: "memory_alt", g: 0xF035B, t: "Memory", v: ab.a.memory ? ab.gib(ab.a.memory) : "" },
                        { n: "hard_drive", g: 0xF02CA, t: "Disk", v: ab.a.disk ? ab.gib(ab.a.disk.used) + " / " + ab.gib(ab.a.disk.total) : "" },
                        { n: "terminal", g: 0xF0EC0, t: "Kernel", v: ab.a.kernel ? ab.a.kernel : "" },
                        { n: "inventory_2", g: 0xF03D7, t: "Packages", v: ab.a.packages || "" },
                        { n: "desktop_windows", g: 0xF0379, t: "Display", v: ab.a.display || "" },
                        { n: "timer", g: 0xF051B, t: "Uptime", v: ab.d.uptimeText(ab.d.stats.uptime || ab.a.uptime || 0) }
                    ].filter(function(r) { return r.v !== "" })
                    Item {
                        width: parent.width; height: Math.max(20, Math.min(26, (sys.height - 64) / 10))
                        visible: y + height < sys.height - 52
                        MIcon { name: modelData.n; glyph: ab.d.md(modelData.g); size: 15; color: ab.p.sub; anchors.verticalCenter: parent.verticalCenter }
                        DText { x: 24; text: modelData.t; font.pixelSize: 12; color: ab.p.sub; anchors.verticalCenter: parent.verticalCenter }
                        DText { x: 96; width: parent.width - 96; elide: Text.ElideRight; text: modelData.v; font.pixelSize: 12; color: ab.p.text; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
    Component {
        id: distC
        DCard {
            id: dist
            p: ab.p
            strong: true
            readonly property real ls: Math.min(108, width - 50, height * 0.36)
            Rectangle {
                id: logo
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24
                width: dist.ls; height: dist.ls; radius: width * 0.32
                color: ab.p.container
                Text { anchors.centerIn: parent; text: ab.d.distroGlyph(); font.family: DashFont.nerd; font.pixelSize: dist.ls * 0.54; color: ab.p.onContainer }
                SequentialAnimation on scale {
                    running: ab.live
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.04; duration: 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
                }
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: logo.y + logo.height + 14
                width: parent.width - 24
                spacing: 2
                DText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: ab.di.name || "Linux"; font.pixelSize: 22; font.weight: Font.DemiBold; color: ab.p.text }
                DText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: ab.di.version || ""; font.pixelSize: 12; color: ab.p.sub }
                DText { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: (ab.a.user || "") + (ab.a.host ? "@" + ab.a.host : ""); font.pixelSize: 11; color: ab.p.sub; topPadding: 4 }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - 50
                spacing: 8
                Btn { icon: "language"; glyph: ab.d.md(0xF059F); text: "Website"; primary: true; onClicked: ab.open(ab.di.url) }
                Btn { visible: !!ab.di.docs && dist.width > 215; icon: "menu_book"; glyph: ab.d.md(0xF02FD); text: "Docs"; onClicked: ab.open(ab.di.docs) }
            }
        }
    }
    Component {
        id: riceC
        DCard {
            id: rice
            p: ab.p
            Image {
                id: moon
                x: 18; y: 18
                width: 54; height: 54
                source: "file://" + Quickshell.env("HOME") + "/.local/share/rice/icon.png"
                sourceSize.width: 108; sourceSize.height: 108
                smooth: true
            }
            Column {
                anchors.left: moon.right; anchors.leftMargin: 14
                anchors.right: parent.right; anchors.rightMargin: 16
                y: 20
                spacing: 6
                DText { width: parent.width; elide: Text.ElideRight; text: "DarkShadow's Shell"; font.pixelSize: 17; font.weight: Font.DemiBold; color: ab.p.text }
                Row {
                    spacing: 6
                    Rectangle {
                        width: vt.implicitWidth + 14; height: 22; radius: 11
                        color: ab.p.container
                        DText { id: vt; anchors.centerIn: parent; text: "V" + (ab.up.installed || ab.a.rice || "?"); font.pixelSize: 11; font.weight: Font.DemiBold; color: ab.p.onContainer }
                    }
                    Rectangle { width: 7; height: 7; radius: 3.5; anchors.verticalCenter: parent.verticalCenter
                        color: ab.checking ? ab.p.sub : (ab.up.update ? ab.p.primary : "#7bd88f") }
                    DText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ab.checking ? "Checking..." : (ab.up.update ? "V" + ab.up.latest + " is out" : "Up to date")
                        font.pixelSize: 12; color: ab.up.update ? ab.p.primary : ab.p.sub
                    }
                }
            }
            Column {
                x: 18; y: 92
                width: parent.width - 36
                spacing: 6
                DText { text: ab.up.update ? "WHAT'S NEW" : "RUNNING ON"; font.pixelSize: 10; font.letterSpacing: 1.4; font.weight: Font.Medium; color: ab.p.sub }
                Repeater {
                    model: ab.up.update ? (ab.up.news || []).slice(0, 4) : [ab.a.wm || "Hyprland", ab.a.quickshell || "Quickshell", "Shell: " + (ab.a.shell || "fish")]
                    Row {
                        spacing: 8
                        width: parent.width
                        Rectangle { width: 5; height: 5; radius: 2.5; color: ab.p.primary; anchors.verticalCenter: parent.verticalCenter }
                        DText { width: parent.width - 13; elide: Text.ElideRight; text: modelData; font.pixelSize: 12; color: ab.p.text }
                    }
                }
            }
            Row {
                x: 18; y: parent.height - 50
                spacing: 8
                Btn {
                    primary: ab.up.update === true
                    icon: ab.up.update ? "system_update_alt" : "refresh"
                    glyph: ab.up.update ? ab.d.md(0xF06B0) : ab.d.md(0xF0450)
                    text: ab.up.update ? "Update now" : (ab.checking ? "Checking..." : "Check")
                    onClicked: {
                        if (ab.up.update) {
                            Quickshell.execDetached(["bash", "-c", "t=\"${TERMINAL:-kitty}\"; command -v \"$t\" >/dev/null || t=kitty; exec \"$t\" -e \"$HOME/.local/bin/rice-update\""])
                            ab.d.close()
                        } else if (!ab.checking) { ab.checking = true; upProc.running = true }
                    }
                }
                Btn { visible: rice.width > 260; icon: "code"; glyph: ab.d.md(0xF02A4); text: "GitHub"; onClicked: ab.open("https://github.com/whyrassvet/phantom-shell") }
            }
        }
    }

    component Btn: Rectangle {
        id: bb
        property string icon: ""
        property string glyph: ""
        property string text: ""
        property bool primary: false
        signal clicked()
        height: 36
        width: br.implicitWidth + 28
        radius: 18
        color: primary ? (bm.containsMouse ? Qt.lighter(ab.p.primary, 1.08) : ab.p.primary) : (bm.containsMouse ? ab.p.card2 : ab.p.container)
        Behavior on color { ColorAnimation { duration: 120 } }
        scale: bm.pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Row {
            id: br
            anchors.centerIn: parent
            spacing: 6
            MIcon { name: bb.icon; glyph: bb.glyph; size: 17; color: bb.primary ? ab.p.onPrimary : ab.p.onContainer; anchors.verticalCenter: parent.verticalCenter }
            DText { text: bb.text; font.pixelSize: 12; font.weight: bb.primary ? Font.DemiBold : Font.Normal; color: bb.primary ? ab.p.onPrimary : ab.p.onContainer; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bb.clicked() }
    }
}
