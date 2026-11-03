import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects

PanelWindow {
    id: dock
    property var dc: ({})
    property bool pinned: false
    property bool hovering: false
    readonly property bool autoHide: dc.hover !== false
    readonly property bool reveal: !autoHide || pinned || hovering

    function pickPlayer() {
        const l = Mpris.players.values
        for (let i = 0; i < l.length; i++) if (l[i].isPlaying) return l[i]
        return l.length > 0 ? l[0] : null
    }
    readonly property var player: pickPlayer()

    function build() {
        const tl = ToplevelManager.toplevels.values
        const out = []
        const used = {}
        const apps = dc.apps || []
        for (let i = 0; i < apps.length; i++) {
            const e = DesktopEntries.heuristicLookup(apps[i])
            if (!e) continue
            const ids = [apps[i].toLowerCase(), (e.id || "").toLowerCase(), (e.startupClass || "").toLowerCase()]
            let t = null
            for (let j = 0; j < tl.length; j++) {
                const id = (tl[j].appId || "").toLowerCase()
                if (id !== "" && ids.indexOf(id) >= 0) { t = tl[j]; break }
            }
            if (t) used[(t.appId || "").toLowerCase()] = true
            out.push({ entry: e, tl: t, key: apps[i] })
        }
        for (let j = 0; j < tl.length; j++) {
            const id = (tl[j].appId || "").toLowerCase()
            if (id === "" || used[id]) continue
            used[id] = true
            out.push({ entry: DesktopEntries.heuristicLookup(tl[j].appId), tl: tl[j], key: id })
        }
        return out
    }
    readonly property var items: build()

    function iconFor(it) {
        const n = it.entry ? it.entry.icon : (it.tl ? (it.tl.appId || "").toLowerCase() : "")
        const p = n !== "" ? Quickshell.iconPath(n, true) : ""
        return p !== "" ? p : Quickshell.iconPath("application-x-executable", true)
    }

    property bool initDone: false
    onDcChanged: {
        if (!initDone && dc.enabled !== undefined) {
            pinned = dc.pinnedStartup === true
            initDone = true
        }
    }

    visible: dc.enabled === true
    color: "transparent"
    anchors { bottom: true }
    implicitWidth: bar.width + 24
    implicitHeight: (reveal || slide.running) ? bar.height + 28 : 6
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "rice-dock"

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: { hideTimer.stop(); dock.hovering = true }
        onExited: hideTimer.restart()
    }
    Timer { id: hideTimer; interval: 500; onTriggered: dock.hovering = false }

    Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dock.reveal ? 14 : -(height + 4)
        Behavior on anchors.bottomMargin {
            NumberAnimation { id: slide; duration: 280; easing.type: Easing.OutCubic }
        }
        width: row.width + 20
        height: 60
        radius: 22
        color: dock.dc.background === false ? "transparent" : Qt.rgba(0.1, 0.1, 0.11, Look.flat ? 1 : (dock.dc.opacity !== undefined ? Number(dock.dc.opacity) : 0.78))
        border.width: dock.dc.background === false ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.07)
        Behavior on color { ColorAnimation { duration: 200 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                visible: dock.dc.pinButton !== false
                width: 40
                height: 40
                radius: 14
                anchors.verticalCenter: parent.verticalCenter
                color: dock.pinned ? "#F6F5F4" : (pinMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06))
                Behavior on color { ColorAnimation { duration: 140 } }
                T {
                    anchors.centerIn: parent
                    text: ""
                    font.pixelSize: 15
                    color: dock.pinned ? "#0d0d0d" : "#F6F5F4"
                    rotation: dock.pinned ? 0 : 45
                    Behavior on rotation { NumberAnimation { duration: 200 } }
                }
                MouseArea {
                    id: pinMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dock.pinned = !dock.pinned
                }
            }

            Repeater {
                model: dock.items
                delegate: Item {
                    id: app
                    width: 44
                    height: 48
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool tint: dock.dc.tint === true
                    Image {
                        id: ico
                        width: 34
                        height: 34
                        x: 5
                        y: 3
                        visible: false
                        source: dock.iconFor(modelData)
                        sourceSize.width: 64
                        sourceSize.height: 64
                        asynchronous: true
                    }
                    MultiEffect {
                        id: fx
                        x: 5
                        y: 3
                        width: 34
                        height: 34
                        source: ico
                        colorization: app.tint ? 1.0 : 0.0
                        colorizationColor: "#e4e4e7"
                        scale: appMouse.containsMouse ? 1.18 : 1.0
                        transformOrigin: Item.Bottom
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on colorization { NumberAnimation { duration: 200 } }
                    }
                    Rectangle {
                        visible: modelData.tl !== null
                        width: modelData.tl && modelData.tl.activated ? 14 : 5
                        height: 4
                        radius: 2
                        color: "#F6F5F4"
                        opacity: modelData.tl && modelData.tl.activated ? 1 : 0.55
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        Behavior on width { NumberAnimation { duration: 160 } }
                    }
                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.tl) modelData.tl.activate()
                            else if (modelData.entry) modelData.entry.execute()
                        }
                    }
                }
            }

            Rectangle {
                visible: dock.dc.media !== false && dock.player !== null
                width: 1
                height: 30
                color: Qt.rgba(1, 1, 1, 0.12)
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                visible: dock.dc.media !== false && dock.player !== null
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                RoundImage {
                    width: 38
                    height: 38
                    cornerRadius: 12
                    fallback: ""
                    anchors.verticalCenter: parent.verticalCenter
                    source: dock.player && dock.player.trackArtUrl ? dock.player.trackArtUrl : ""
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 130
                    T { width: parent.width; elide: Text.ElideRight; font.pixelSize: 12; font.bold: true; text: dock.player ? (dock.player.trackTitle || "") : "" }
                    T { width: parent.width; elide: Text.ElideRight; font.pixelSize: 10; color: "#a8a8ad"; text: dock.player ? (dock.player.trackArtist || "") : "" }
                }
                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    anchors.verticalCenter: parent.verticalCenter
                    color: playMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    T { anchors.centerIn: parent; text: dock.player && dock.player.isPlaying ? "" : ""; font.pixelSize: 12 }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (dock.player) dock.player.togglePlaying()
                    }
                }
            }

            Rectangle {
                visible: dock.dc.appsButton !== false
                width: 40
                height: 40
                radius: 14
                anchors.verticalCenter: parent.verticalCenter
                color: appsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 140 } }
                T { anchors.centerIn: parent; text: ""; font.pixelSize: 16 }
                MouseArea {
                    id: appsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/phantom-app-launcher"])
                }
            }
        }
    }

    // a soft click on the dock's buttons (Settings > Sfx & sounds)
    SfxTap {}
}
