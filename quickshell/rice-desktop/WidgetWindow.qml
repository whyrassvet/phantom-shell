import Quickshell
import Quickshell.Wayland
import QtQuick

// Full-screen transparent surface; only the widget rectangle receives input (mask).
// Dragging moves an item inside the surface, so nothing is resized or re-configured
// by the compositor while you drag (no shaking).
// The widget editor (EditorWindow.qml) changes px/py/sc/fw/fh/op/bgv/sty/flp live and saves on release.
PanelWindow {
    id: w
    property string wid: ""
    property var wc: ({})
    property int defX: 100
    property int defY: 100
    property int cw: 300          // natural size of the content
    property int ch: 200
    property bool free: false     // free width and height (visualizer) instead of scaling
    property bool autoBottom: false // full screen width, anchored to the bottom edge
    property string fixedCorner: "" // top-left, bottom-left or bottom-right
    property int edgeGap: 25
    property int topInset: 0
    property int defW: 600
    property int defH: 160
    property int bw: 1920
    property int bh: 1080
    property bool active: true
    property bool draggable: true
    property bool passive: false  // never takes clicks (visualizer)
    property bool editing: false
    // auto-hide (Settings > Desktop): fades out while windows are open, then the surface goes away
    property bool hidden: false
    property real fk: hidden ? 0 : 1
    Behavior on fk { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    // current look; the editor changes these while you drag
    property real px: autoBottom ? 0 : fixedCorner === "bottom-right" ? Math.max(0, bw - dispW - edgeGap) : fixedCorner !== "" ? edgeGap : defX
    property real py: autoBottom ? Math.max(0, bh - dispH) : fixedCorner === "top-left" ? topInset + edgeGap : fixedCorner !== "" ? Math.max(0, bh - dispH - edgeGap) : defY
    property real sc: 1
    property real fw: autoBottom ? bw : defW
    property real fh: defH
    property real op: 1
    property real bgv: 1
    property string sty: ""
    property bool flp: false
    property bool dragging: false
    property bool ready: false
    readonly property real dispW: free ? fw : cw * sc
    readonly property real dispH: free ? fh : ch * sc

    signal moved(string id, int x, int y)
    default property alias content: inner.data

    function adopt() {
        if (!ready || dragging) return
        if (!autoBottom && fixedCorner === "") {
            px = wc.x !== undefined ? wc.x : defX
            py = wc.y !== undefined ? wc.y : defY
            fw = wc.w !== undefined ? wc.w : defW
        }
        sc = wc.scale !== undefined ? wc.scale : 1
        fh = wc.h !== undefined ? wc.h : defH
        op = wc.opacity !== undefined ? wc.opacity : 1
        bgv = wc.bg !== undefined ? wc.bg : 1
        sty = wc.style !== undefined ? wc.style : ""
        flp = wc.flip === true
    }
    onWcChanged: adopt()
    onDefXChanged: adopt()
    onDefYChanged: adopt()
    onDefWChanged: adopt()
    onDefHChanged: adopt()
    Component.onCompleted: { ready = true; adopt() }

    visible: active && fk > 0.01
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    // above windows while you edit, so you can see what you change
    WlrLayershell.layer: editing ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.namespace: "rice-widget"
    // only the widget itself takes clicks; the visualizer (passive) and widgets in the editor take none,
    // so whatever is under them (other widgets, the desktop) stays clickable
    mask: Region { item: (w.passive || w.editing) ? nothing : holder }
    Item { id: nothing; width: 0; height: 0 }

    Item {
        id: holder
        x: w.px
        y: w.py
        width: w.dispW
        height: w.dispH
        opacity: w.op * w.fk
        scale: 0.96 + 0.04 * w.fk
        Behavior on opacity { enabled: !w.hidden && w.fk > 0.99; NumberAnimation { duration: 120 } }

        Item {
            id: inner
            width: w.free ? holder.width : w.cw
            height: w.free ? holder.height : w.ch
            scale: w.free ? 1 : w.sc
            transformOrigin: Item.TopLeft
        }

        MouseArea {
            anchors.fill: parent
            enabled: w.draggable && !w.passive && !w.editing && w.fixedCorner === ""
            property real sx: 0
            property real sy: 0
            property real ox: 0
            property real oy: 0
            property real tick: 0       // way moved since the last soft tick
            property bool moved: false
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
            onPressed: function(m) {
                const g = mapToItem(null, m.x, m.y)
                sx = g.x; sy = g.y; ox = w.px; oy = w.py
                tick = 0; moved = false
                w.dragging = true
                Sfx.play("select")
            }
            onPositionChanged: function(m) {
                if (!pressed) return
                const g = mapToItem(null, m.x, m.y)
                const nx = Math.max(0, Math.min(w.bw - w.dispW, ox + g.x - sx))
                const ny = Math.max(0, Math.min(w.bh - w.dispH, oy + g.y - sy))
                tick += Math.abs(nx - w.px) + Math.abs(ny - w.py)
                if (tick > 34) { tick = 0; moved = true; Sfx.play("slide") }
                w.px = nx
                w.py = ny
            }
            onReleased: {
                if (moved) Sfx.play("done")
                w.dragging = false
                w.px = Math.round(w.px)
                w.py = Math.round(w.py)
                w.moved(w.wid, w.px, w.py)
            }
        }
    }
}
