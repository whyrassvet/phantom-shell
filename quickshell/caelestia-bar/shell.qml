// phantom-shell bar: horizontal, top edge, one surface per monitor.
// Reuses Caelestia's bar module (GPL-3), rewritten for horizontal layout.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.config
import qs.services
import qs.modules.bar as Bar
import qs.modules.bar.popouts as BarPopouts

ShellRoot {
    id: root

    function hotCornerCall(method: string, args: list<string>): void {
        const config = (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell/rice-desktop";
        Quickshell.execDetached(["qs", "ipc", "-p", config, "call", "hotCornerLink", method].concat(args));
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.hotCornerCall("useUnified", [])
    }

    // Match the upstream shell: Google Sans Flex is bundled, not assumed to
    // be installed globally. Font tokens continue to honour user settings.
    FontLoader {
        source: Quickshell.shellPath("assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf")
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: scope

            required property ShellScreen modelData

            readonly property var monitor: Hypr.monitorFor(modelData)
            readonly property bool fullscreen: {
                const mon = monitor;
                if (!mon)
                    return false;

                const specialName = mon.lastIpcObject.specialWorkspace?.name;
                if (specialName && specialName.length > 0) {
                    const special = Hypr.workspaces.values.find(w => w.name === specialName);
                    return special?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
                }

                return mon.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
            }

            // Reserve the bar's space without adding another visible surface.
            StyledWindow {
                id: reservation

                name: "reservation"
                screen: scope.modelData
                anchors.top: true
                anchors.left: true
                anchors.right: true
                WlrLayershell.layer: WlrLayer.Top
                exclusiveZone: bar.exclusiveZone
                implicitHeight: 1
                color: "transparent"
                mask: Region {}
            }

            // Notifications use their own layer so popup blur is independent of the bar.
            PanelWindow {
                id: notificationWindow
                screen: scope.modelData
                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true
                color: "transparent"
                visible: !ShellState.forScreen(scope.modelData).sidebar && Notifs.popups.length > 0
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "phantom-notifications"
                mask: Region {
                    x: Math.floor(notificationPopups.x)
                    y: Math.floor(notificationPopups.y)
                    width: Math.ceil(notificationPopups.width)
                    height: Math.ceil(notificationPopups.height)
                }
                Column {
                    id: notificationPopups
                    readonly property string horizontal: PopupSettings.get("pos_x", "center")
                    readonly property bool atBottom: PopupSettings.get("pos_y", "top") === "bottom"
                    width: Math.min(Math.max(260, Math.min(600, Number(PopupSettings.get("popup_width", 360)))), scope.modelData.width - 24)
                    x: horizontal === "left" ? 12 : horizontal === "center" ? (scope.modelData.width - width) / 2 : scope.modelData.width - width - 12
                    y: atBottom ? scope.modelData.height - height - 12 : BarConfig.topGap + BarConfig.thickness + 12
                    height: Math.min(implicitHeight, scope.modelData.height - BarConfig.thickness - 24)
                    clip: true
                    spacing: 8
                    visible: !ShellState.forScreen(scope.modelData).sidebar && Notifs.popups.length > 0
                    Repeater {
                        model: Notifs.popups.filter(n => !n.closed)
                        NotificationCard {
                            required property var modelData
                            width: notificationPopups.width
                            notif: modelData
                            popup: true
                        }
                    }
                }
            }

            // Draw the bar and popouts together so neither is blurred behind the other.
            // Only the bar and visible popout receive input; empty space stays click-through.
            StyledWindow {
                id: popoutWin
                name: "bar"
                screen: scope.modelData

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                property real reveal: pops.hasCurrent ? 1 : 0

                // Keep the transparent surface mapped so the compositor does
                // not slide a fullscreen layer in on the first popout.
                visible: true
                color: "transparent"

                Behavior on reveal {
                    Anim {
                        duration: pops.animLength
                        easing: pops.animCurve
                    }
                }

                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.keyboardFocus: popoutWin.sessionState.session ? WlrKeyboardFocus.Exclusive : (pops.hasCurrent && pops.currentName === "wirelesspassword") ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                exclusiveZone: -1

                mask: Region {
                    id: barInputRegion

                    x: bar.x
                    y: BarConfig.topGap
                    width: bar.width
                    height: bar.shouldBeVisible ? BarConfig.thickness : 0

                    Region {
                        id: popoutInputRegion

                        x: Math.max(0, Math.floor(revealArea.x - revealArea.joinRadius))
                        y: revealArea.y
                        width: Math.min(scope.modelData.width - x, Math.ceil(pops.width + 2 * revealArea.joinRadius))
                        height: bar.shouldBeVisible ? Math.max(0, Math.ceil(pops.height * popoutWin.reveal)) : 0
                    }
                    Region {
                        x: scope.modelData.width - 24
                        y: scope.modelData.height - 24
                        width: !scope.fullscreen && corner.enabledHere ? 24 : 0
                        height: width
                    }
                    Region {
                        id: sessionEdgeRegion
                        x: scope.modelData.width - 8
                        y: Math.floor(scope.modelData.height / 3)
                        width: scope.fullscreen || corner.opened ? 0 : 8
                        height: width > 0 ? Math.floor(scope.modelData.height / 3) : 0
                    }
                    // Keep receiving an edge drag after it leaves the 4 px strip.
                    // Without an underlying application, the pointer can otherwise
                    // leave the surface before the session drag threshold is reached.
                    Region {
                        id: sessionDragRegion
                        width: corner.pressed || sessionEdge.pressed ? scope.modelData.width : 0
                        height: corner.pressed || sessionEdge.pressed ? scope.modelData.height : 0
                    }
                    Region {
                        x: Math.floor(sessionPanel.x)
                        y: Math.floor(sessionPanel.y)
                        width: popoutWin.sessionState.session ? Math.ceil(sessionPanel.width) : 0
                        height: popoutWin.sessionState.session ? Math.ceil(sessionPanel.height) : 0
                    }
                }

                property var sessionState: ShellState.forScreen(scope.modelData)

                Connections {
                    target: popoutWin.sessionState
                    function onSessionChanged(): void {
                        if (!popoutWin.sessionState.session)
                            return;
                        corner.close();
                        popoutWin.sessionState.sidebar = false;
                        for (const screen of Quickshell.screens) {
                            const state = ShellState.forScreen(screen);
                            if (state && state !== popoutWin.sessionState)
                                state.session = false;
                        }
                    }
                    function onSidebarChanged(): void {
                        if (!popoutWin.sessionState.sidebar)
                            return;
                        for (const screen of Quickshell.screens) {
                            const state = ShellState.forScreen(screen);
                            if (state && state !== popoutWin.sessionState)
                                state.sidebar = false;
                        }
                        for (const notif of Notifs.popups)
                            notif.popup = false;
                    }
                }

                MouseArea {
                    id: sessionEdge
                    z: 10
                    x: parent.width - width
                    y: Math.floor(parent.height / 3)
                    width: 8
                    height: Math.floor(parent.height / 3)
                    enabled: !scope.fullscreen && !corner.opened
                    property real startX
                    function handleDrag(delta: real): void {
                        if (delta < -Config.session.dragThreshold && Config.session.enabled) {
                            corner.close();
                            popoutWin.sessionState.session = true;
                        }
                    }
                    onPressed: event => startX = event.x
                    onPositionChanged: event => { if (pressed) handleDrag(event.x - startX); }
                }

                UnifiedCorner {
                    id: corner
                    anchors.fill: parent
                    screenState: popoutWin.sessionState
                    targetScreen: scope.modelData
                }

                Shape {
                    id: sessionBackground
                    readonly property real ear: Math.min(24, width / 2)
                    readonly property real corner: Math.min(28, width / 2, (height - 2 * ear) / 2)
                    readonly property real curve: 0.55228475
                    x: sessionPanel.x - 16
                    y: sessionPanel.y - 40
                    width: parent.width - x
                    height: sessionPanel.height + 80
                    opacity: sessionPanel.opacity
                    visible: sessionPanel.visible

                    ShapePath {
                        id: sessionFill
                        strokeWidth: 0
                        fillColor: barBackground.color
                        startX: sessionBackground.width
                        startY: 0
                        // Rotated version of the dashboard's attached outline:
                        // concave ears at the screen and rounded outer corners.
                        PathCubic {
                            x: sessionBackground.width - sessionBackground.ear; y: sessionBackground.ear
                            control1X: sessionBackground.width; control1Y: sessionBackground.ear * sessionBackground.curve
                            control2X: x + sessionBackground.ear * sessionBackground.curve; control2Y: y
                        }
                        PathLine { x: sessionBackground.corner; y: sessionBackground.ear }
                        PathCubic {
                            x: 0; y: sessionBackground.ear + sessionBackground.corner
                            control1X: sessionBackground.corner * (1 - sessionBackground.curve); control1Y: sessionBackground.ear
                            control2X: 0; control2Y: y - sessionBackground.corner * sessionBackground.curve
                        }
                        PathLine { x: 0; y: sessionBackground.height - sessionBackground.ear - sessionBackground.corner }
                        PathCubic {
                            x: sessionBackground.corner; y: sessionBackground.height - sessionBackground.ear
                            control1X: 0; control1Y: y - sessionBackground.corner * (1 - sessionBackground.curve)
                            control2X: sessionBackground.corner * (1 - sessionBackground.curve); control2Y: y
                        }
                        PathLine { x: sessionBackground.width - sessionBackground.ear; y: sessionBackground.height - sessionBackground.ear }
                        PathCubic {
                            x: sessionBackground.width; y: sessionBackground.height
                            control1X: sessionBackground.width - sessionBackground.ear * (1 - sessionBackground.curve); control1Y: sessionBackground.height - sessionBackground.ear
                            control2X: sessionBackground.width; control2Y: sessionBackground.height - sessionBackground.ear * sessionBackground.curve
                        }
                        PathLine { x: sessionBackground.width; y: 0 }
                    }
                }

                SessionPanel {
                    id: sessionPanel
                    screenState: popoutWin.sessionState
                    anchors.verticalCenter: parent.verticalCenter
                    x: parent.width - width * (1 - offsetScale)
                    opacity: 1 - offsetScale
                    visible: offsetScale < 1
                    property real offsetScale: screenState.session && Config.session.enabled ? 0 : 1
                    Behavior on offsetScale { Anim {} }
                }

                Rectangle {
                    id: barBackground

                    x: bar.x
                    y: BarConfig.topGap
                    width: bar.width
                    height: BarConfig.thickness
                    radius: BarConfig.style === "flat" ? 0 : 12
                    visible: bar.shouldBeVisible && BarConfig.style !== "islands"
                    color: Effects.flat ? Colours.palette.m3surface : Colours.tPalette.m3surface
                    border.width: 1
                    border.color: Colours.outline
                }

                Bar.BarWrapper {
                    id: bar

                    x: BarConfig.style === "flat" || BarConfig.style === "islands" ? 0 : (scope.modelData.width - width) / 2
                    y: BarConfig.topGap
                    width: BarConfig.style === "flat" || BarConfig.style === "islands" ? scope.modelData.width : BarConfig.style === "floating" ? Math.max(0, scope.modelData.width - 24) : Math.min(scope.modelData.width, Math.max(0, contentWidth + BarConfig.padding * 4))
                    height: BarConfig.thickness
                    screen: scope.modelData
                    screenState: ShellState.forScreen(scope.modelData)
                    popouts: pops
                    fullscreen: scope.fullscreen
                }

                // Hover tracking: hover events propagate through children, so
                // this stays true while the pointer is anywhere on the popout.
                HoverHandler {
                    id: popoutHover
                }

                // A clipped reveal grows down from the bar. The flared top
                // corners join the popout to its lower edge like Caelestia.
                Item {
                    id: revealArea

                    readonly property real joinRadius: Tokens.rounding.extraLarge

                    y: BarConfig.topGap + BarConfig.thickness + (BarConfig.style === "flat" ? 0 : 4)
                    width: pops.width
                    height: pops.height * popoutWin.reveal
                    clip: true

                    Shape {
                        id: popoutBackground

                        width: parent.width
                        height: parent.height
                        readonly property real corner: Math.min(revealArea.joinRadius, width / 2, height / 2)

                        ShapePath {
                            strokeWidth: 0
                            fillColor: barBackground.color
                            startX: BarConfig.style === "flat" ? 0 : popoutBackground.corner
                            startY: 0
                            PathLine { x: revealArea.width - (BarConfig.style === "flat" ? 0 : popoutBackground.corner); y: 0 }
                            PathQuad { x: revealArea.width; y: BarConfig.style === "flat" ? 0 : popoutBackground.corner; controlX: revealArea.width; controlY: 0 }
                            PathLine { x: revealArea.width; y: revealArea.height - popoutBackground.corner }
                            PathQuad { x: revealArea.width - popoutBackground.corner; y: revealArea.height; controlX: revealArea.width; controlY: revealArea.height }
                            PathLine { x: popoutBackground.corner; y: revealArea.height }
                            PathQuad { x: 0; y: revealArea.height - popoutBackground.corner; controlX: 0; controlY: revealArea.height }
                            PathLine { x: 0; y: BarConfig.style === "flat" ? 0 : popoutBackground.corner }
                            PathQuad { x: BarConfig.style === "flat" ? 0 : popoutBackground.corner; y: 0; controlX: 0; controlY: 0 }
                        }
                    }

                    BarPopouts.Wrapper {
                        id: pops

                        screen: scope.modelData
                        offsetScale: 1 - popoutWin.reveal

                        width: implicitWidth
                        height: implicitHeight
                        y: -(1 - popoutWin.reveal) * height
                    }
                }

                Shape {
                    x: revealArea.x - revealArea.joinRadius
                    y: BarConfig.topGap + BarConfig.thickness
                    width: revealArea.width + 2 * revealArea.joinRadius
                    height: Math.min(revealArea.joinRadius, revealArea.height)
                    visible: BarConfig.style === "flat" && height > 0 && revealArea.width > 0
                    clip: true

                    ShapePath {
                        strokeWidth: 0
                        fillColor: barBackground.color
                        startX: 0
                        startY: 0
                        PathQuad { x: revealArea.joinRadius; y: revealArea.joinRadius; controlX: revealArea.joinRadius; controlY: 0 }
                        PathLine { x: revealArea.joinRadius; y: 0 }
                        PathLine { x: 0; y: 0 }
                    }
                    ShapePath {
                        strokeWidth: 0
                        fillColor: barBackground.color
                        startX: revealArea.width + revealArea.joinRadius
                        startY: 0
                        PathLine { x: revealArea.width + revealArea.joinRadius; y: revealArea.joinRadius }
                        PathQuad { x: revealArea.width + 2 * revealArea.joinRadius; y: 0; controlX: revealArea.width + revealArea.joinRadius; controlY: 0 }
                        PathLine { x: revealArea.width + revealArea.joinRadius; y: 0 }
                    }
                }

                Binding {
                    target: revealArea
                    property: "x"
                    value: {
                        if (pops.width <= 0)
                            return BarConfig.padding;

                        const max = Math.max(BarConfig.padding, scope.modelData.width - pops.width - BarConfig.padding);
                        return Math.round(Math.max(BarConfig.padding, Math.min(max, pops.currentCenter - pops.width / 2)));
                    }
                }
            }

            onFullscreenChanged: {
                if (fullscreen) {
                    pops.close();
                    popoutWin.sessionState.session = false;
                    popoutWin.sessionState.sidebar = false;
                    corner.close();
                }
            }

            // Close the popout and compact tray after leaving both surfaces.
            Timer {
                id: closePopoutTimer

                interval: 400

                onTriggered: {
                    if (!bar.isHovered && !popoutHover.hovered) {
                        bar.closeTray();
                        pops.close();
                    }
                }
            }

            Connections {
                target: bar

                function onIsHoveredChanged(): void {
                    if (bar.isHovered)
                        closePopoutTimer.stop();
                    else
                        closePopoutTimer.restart();
                }
            }

            Connections {
                target: popoutHover

                function onHoveredChanged(): void {
                    if (popoutHover.hovered)
                        closePopoutTimer.stop();
                    else if (pops.hasCurrent)
                        closePopoutTimer.restart();
                }
            }

            // Close when focus moves to another window.
            Connections {
                target: Hypr

                function onActiveToplevelChanged(): void {
                    if (pops.hasCurrent)
                        pops.close();
                }
            }
        }
    }
}
