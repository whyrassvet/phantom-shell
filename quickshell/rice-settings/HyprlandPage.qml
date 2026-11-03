import Quickshell
import QtQuick

Item {
    id: page
    property var ctl
    property int tab: 0
    property bool confirmReset: false

    readonly property var tabs: ["Gaps", "Borders", "Layout", "Rounding & Opacity", "Blur", "Animations", "Keybinds"]
    readonly property var comps: [gapsC, bordersC, layoutC, roundC, blurC, animC, bindsC]

    readonly property var gapsSpec: [
        { key: "general.gaps_in", type: "slider", label: "Inner gaps", desc: "Gaps between windows", min: 0, max: 40, step: 1, unit: " px", def: 5 },
        { key: "general.gaps_out", type: "slider", label: "Outer gaps", desc: "Gaps between windows and the screen edges", min: 0, max: 80, step: 1, unit: " px", def: 20 },
        { key: "general.gaps_workspaces", type: "slider", label: "Workspace gaps", desc: "Gaps between workspaces", min: 0, max: 100, step: 1, unit: " px", def: 0 }
    ]
    readonly property var bordersSpec: [
        { key: "general.border_size", type: "slider", label: "Border size", desc: "Thickness of window borders", min: 0, max: 12, step: 1, unit: " px", def: 2 },
        { key: "general.resize_on_border", type: "toggle", label: "Resize on border", desc: "Drag borders and gaps to resize windows" },
        { key: "general.extend_border_grab_area", type: "slider", label: "Border grab area", desc: "How far from the border you can grab it", min: 0, max: 60, step: 1, unit: " px", def: 15 },
        { key: "general.hover_icon_on_border", type: "toggle", label: "Cursor icon on border", desc: "Show a resize cursor over borders" }
    ]
    readonly property var layoutSpec: [
        { key: "general.layout", type: "seg", label: "Layout", desc: "How windows are arranged",
          options: [{ label: "Dwindle", value: "dwindle" }, { label: "Master", value: "master" }, { label: "Scrolling", value: "scrolling" }, { label: "Monocle", value: "monocle" }] },
        { key: "dwindle.preserve_split", type: "toggle", label: "Preserve split", desc: "Keep the split direction when windows close (Dwindle)" }
    ]
    readonly property var roundSpec: [
        { key: "decoration.rounding", type: "slider", label: "Corner rounding", desc: "Radius of window corners", min: 0, max: 40, step: 1, unit: " px", def: 10 },
        { key: "decoration.rounding_power", type: "slider", label: "Rounding power", desc: "Curve of the corners (2 = circle, 4 = squircle)", min: 2, max: 10, step: 0.5, dec: 1, def: 2 },
        { key: "decoration.active_opacity", type: "slider", label: "Active window opacity", desc: "Opacity of the focused window", min: 0.3, max: 1, step: 0.05, dec: 2, def: 1 },
        { key: "decoration.inactive_opacity", type: "slider", label: "Inactive window opacity", desc: "Opacity of unfocused windows", min: 0.3, max: 1, step: 0.05, dec: 2, def: 1 },
        { key: "decoration.dim_inactive", type: "toggle", label: "Dim inactive windows", desc: "Darken windows that are not focused" },
        { key: "decoration.dim_strength", type: "slider", label: "Dim strength", desc: "How dark inactive windows get", min: 0, max: 1, step: 0.05, dec: 2, def: 0.5 },
        { key: "decoration.shadow.enabled", type: "toggle", label: "Window shadows", desc: "Draw a shadow behind windows" },
        { key: "decoration.shadow.range", type: "slider", label: "Shadow range", desc: "Size of the shadow", min: 0, max: 60, step: 1, unit: " px", def: 4 },
        { key: "decoration.shadow.render_power", type: "slider", label: "Shadow falloff", desc: "How fast the shadow fades (1 soft, 4 sharp)", min: 1, max: 4, step: 1, def: 3 }
    ]
    readonly property var blurSpec: [
        { key: "decoration.blur.enabled", type: "toggle", label: "Enable blur", desc: "Blur what is behind translucent windows and bars" },
        { key: "decoration.blur.size", type: "slider", label: "Blur size", desc: "Radius of the blur", min: 1, max: 30, step: 1, def: 8 },
        { key: "decoration.blur.passes", type: "slider", label: "Blur passes", desc: "More passes look smoother but cost more", min: 1, max: 8, step: 1, def: 2 },
        { key: "decoration.blur.noise", type: "slider", label: "Noise", desc: "Film grain on the blurred area", min: 0, max: 0.5, step: 0.01, dec: 2, def: 0.01 },
        { key: "decoration.blur.contrast", type: "slider", label: "Contrast", desc: "Contrast of the blurred area", min: 0, max: 2, step: 0.05, dec: 2, def: 0.89 },
        { key: "decoration.blur.brightness", type: "slider", label: "Brightness", desc: "Brightness of the blurred area", min: 0, max: 2, step: 0.05, dec: 2, def: 0.81 },
        { key: "decoration.blur.vibrancy", type: "slider", label: "Vibrancy", desc: "Color saturation of the blur", min: 0, max: 1, step: 0.05, dec: 2, def: 0.17 },
        { key: "decoration.blur.vibrancy_darkness", type: "slider", label: "Vibrancy darkness", desc: "How much vibrancy darkens dark areas", min: 0, max: 1, step: 0.05, dec: 2, def: 0 },
        { key: "decoration.blur.xray", type: "toggle", label: "X-ray blur", desc: "Blur only the wallpaper, not other windows" },
        { key: "decoration.blur.ignore_opacity", type: "toggle", label: "Ignore opacity", desc: "Blur fully even for very transparent windows" },
        { key: "decoration.blur.new_optimizations", type: "toggle", label: "Optimizations", desc: "Faster blur rendering" },
        { key: "decoration.blur.popups", type: "toggle", label: "Blur popups", desc: "Also blur menus and popups" }
    ]

    Flow {
        id: tabsFlow
        x: 24
        y: 4
        width: parent.width - 48
        spacing: 6
        Repeater {
            model: page.tabs
            delegate: Rectangle {
                width: tabText.implicitWidth + 24
                height: 30
                radius: 9
                color: page.tab === index ? "#F6F5F4" : (tabMouse.containsMouse ? "#262626" : "#1a1a1a")
                border.width: 1
                border.color: "#2a2a2a"
                Behavior on color { ColorAnimation { duration: 140 } }
                T {
                    id: tabText
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 12
                    color: page.tab === index ? "#0d0d0d" : "#F6F5F4"
                }
                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.tab = index
                }
            }
        }
    }

    Flickable {
        id: flick
        x: 0
        y: tabsFlow.y + tabsFlow.height + 14
        width: parent.width
        height: parent.height - y - 52
        contentWidth: width
        contentHeight: contentLoader.height + 30
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Behavior on contentY {
            enabled: !flick.dragging && !flick.flicking
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(e) {
                const max = Math.max(0, flick.contentHeight - flick.height)
                flick.contentY = Math.max(0, Math.min(max, flick.contentY - e.angleDelta.y * 0.6))
            }
        }

        Loader {
            id: contentLoader
            x: 24
            width: flick.width - 48
            sourceComponent: page.comps[page.tab]
            onSourceComponentChanged: flick.contentY = 0
            onLoaded: tabFade.restart()
            ParallelAnimation {
                id: tabFade
                NumberAnimation { target: contentLoader; property: "opacity"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
                NumberAnimation { target: contentLoader; property: "y"; from: 14; to: 0; duration: 280; easing.type: Easing.OutCubic }
            }
        }
    }

    Row {
        x: 24
        y: parent.height - 42
        spacing: 8
        Pill { label: "Reload Hyprland"; onClicked: page.ctl.hrun(["reload"], "Hyprland reloaded") }
        Pill {
            label: page.confirmReset ? "Click again to reset" : "Reset everything"
            onClicked: {
                if (page.confirmReset) {
                    page.confirmReset = false
                    page.ctl.hrun(["reset-all"], "All changes reset")
                } else {
                    page.confirmReset = true
                    resetTimer.restart()
                }
            }
        }
    }
    Timer { id: resetTimer; interval: 4000; onTriggered: page.confirmReset = false }

    Component { id: gapsC; OptionsList { ctl: page.ctl; specs: page.gapsSpec } }

    Component {
        id: bordersC
        Column {
            spacing: 10
            OptionsList { width: parent.width; ctl: page.ctl; specs: page.bordersSpec }
            T { kind: "title"; text: "Border colors"; font.pixelSize: 16; font.bold: true; topPadding: 8 }
            SegRow {
                width: parent.width
                label: "Color source"
                desc: "Follow the wallpaper or use your own colors"
                options: [{ label: "Wallpaper", value: "wallpaper" }, { label: "Custom", value: "custom" }]
                current: page.ctl.hb.mode
                onChosen: function(v) { page.ctl.setBorderMode(v) }
            }
            ColorRow {
                width: parent.width
                visible: page.ctl.hb.mode === "custom"
                label: "Active border"
                desc: "Border of the focused window"
                hex: page.ctl.hb.active
                onCommitted: function(h) { page.ctl.setBorderColor("active", h) }
            }
            ColorRow {
                width: parent.width
                visible: page.ctl.hb.mode === "custom"
                label: "Inactive border"
                desc: "Border of unfocused windows"
                hex: page.ctl.hb.inactive
                onCommitted: function(h) { page.ctl.setBorderColor("inactive", h) }
            }
        }
    }

    Component { id: layoutC; OptionsList { ctl: page.ctl; specs: page.layoutSpec } }
    Component { id: roundC; OptionsList { ctl: page.ctl; specs: page.roundSpec } }
    Component { id: blurC; OptionsList { ctl: page.ctl; specs: page.blurSpec } }

    Component {
        id: animC
        Column {
            spacing: 10
            ToggleRow {
                width: parent.width
                label: "Animations"
                desc: "Window, workspace and layer animations"
                checked: page.ctl.ha.enabled !== false
                onToggled: function(v) { page.ctl.setAnim("enabled", v) }
            }
            SliderRow {
                width: parent.width
                label: "Animation speed"
                desc: "100% keeps your current speeds; higher is faster"
                from: 50
                to: 200
                step: 10
                unit: " %"
                value: page.ctl.ha.speed !== undefined ? page.ctl.ha.speed : 100
                onCommitted: function(v) { page.ctl.setAnim("speed", Math.round(v)) }
            }
        }
    }

    Component { id: bindsC; BindsPage { ctl: page.ctl } }
}
