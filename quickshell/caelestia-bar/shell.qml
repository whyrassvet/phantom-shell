// phantom-shell bar: horizontal, top edge, one surface per monitor.
// Reuses Caelestia's bar module (GPL-3), rewritten for horizontal layout.

import QtQuick
import QtQuick.Shapes
import Quickshell
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

            StyledWindow {
                id: win

                name: "bar"
                screen: scope.modelData

                anchors.top: true
                anchors.left: true
                anchors.right: true

                WlrLayershell.layer: WlrLayer.Top
                exclusiveZone: bar.exclusiveZone
                implicitHeight: BarConfig.thickness
                visible: bar.shouldBeVisible
                color: Colours.tPalette.m3surface

                Bar.BarWrapper {
                    id: bar

                    anchors.fill: parent
                    screen: scope.modelData
                    screenState: ShellState.forScreen(scope.modelData)
                    popouts: pops
                    fullscreen: scope.fullscreen
                }
            }

            // Popouts live in their own fullscreen surface so they are not clipped
            // by the bar window. The mask limits input to the revealed popout,
            // and excluding nothing keeps the bar's exclusive zone intact.
            StyledWindow {
                id: popoutWin
                name: "popouts"
                screen: scope.modelData

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                property real reveal: pops.hasCurrent ? 1 : 0

                visible: pops.hasCurrent || reveal > 0
                color: "transparent"

                Behavior on reveal {
                    Anim {
                        duration: pops.animLength
                        easing: pops.animCurve
                    }
                }

                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.keyboardFocus: pops.hasCurrent && pops.currentName === "wirelesspassword" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                exclusiveZone: -1

                mask: Region {
                    x: Math.max(0, Math.floor(revealArea.x - revealArea.joinRadius))
                    y: BarConfig.thickness
                    width: Math.min(scope.modelData.width - x, Math.ceil(pops.width + 2 * revealArea.joinRadius))
                    height: Math.max(0, Math.ceil(pops.height * popoutWin.reveal))
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

                    y: BarConfig.thickness
                    width: pops.width
                    height: pops.height * popoutWin.reveal
                    clip: true

                    Rectangle {
                        width: parent.width
                        height: parent.height
                        color: win.color
                        radius: Tokens.rounding.extraLarge

                        Rectangle {
                            width: parent.width
                            height: Math.min(parent.radius, parent.height)
                            color: parent.color
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
                    y: BarConfig.thickness
                    width: revealArea.width + 2 * revealArea.joinRadius
                    height: Math.min(revealArea.joinRadius, revealArea.height)
                    visible: height > 0 && revealArea.width > 0
                    clip: true

                    ShapePath {
                        strokeWidth: 0
                        fillColor: win.color
                        startX: 0
                        startY: 0
                        PathQuad { x: revealArea.joinRadius; y: revealArea.joinRadius; controlX: revealArea.joinRadius; controlY: 0 }
                        PathLine { x: revealArea.joinRadius; y: 0 }
                        PathLine { x: 0; y: 0 }
                    }
                    ShapePath {
                        strokeWidth: 0
                        fillColor: win.color
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
                if (fullscreen)
                    pops.close();
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
