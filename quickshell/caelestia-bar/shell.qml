// phantom-shell bar: horizontal, top edge, one surface per monitor.
// Reuses Caelestia's bar module (GPL-3), rewritten for horizontal layout.

import QtQuick
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
            // by the 36px bar window. The mask limits input to the popout rect,
            // and excluding nothing keeps the bar's exclusive zone intact.
            StyledWindow {
                id: popoutWin
                name: "popouts"
                screen: scope.modelData

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                visible: pops.hasCurrent
                color: "transparent"

                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.keyboardFocus: pops.hasCurrent && pops.currentName === "wirelesspassword" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                exclusiveZone: -1

                mask: Region {
                    x: Math.round(pops.x)
                    y: Math.round(pops.y)
                    width: Math.round(pops.width)
                    height: Math.round(pops.height)
                }

                // Hover tracking: hover events propagate through children, so
                // this stays true while the pointer is anywhere on the popout.
                HoverHandler {
                    id: popoutHover
                }

                // Caelestia draws popout backgrounds with PanelBg blobs in the
                // drawers window; here we use a plain elevated surface.
                Elevation {
                    x: pops.x
                    y: pops.y
                    width: pops.width
                    height: pops.height
                    radius: Tokens.rounding.extraLarge
                    level: 2
                    visible: pops.hasCurrent && width > 0 && height > 0

                    StyledRect {
                        anchors.fill: parent
                        color: Colours.tPalette.m3surface
                        radius: Tokens.rounding.extraLarge
                    }
                }

                BarPopouts.Wrapper {
                    id: pops

                    screen: scope.modelData
                    offsetScale: hasCurrent ? 1 : 0

                    width: implicitWidth
                    height: implicitHeight

                    y: BarConfig.thickness + BarConfig.padding
                    x: {
                        if (!hasCurrent || width <= 0)
                            return BarConfig.padding;

                        const max = Math.max(BarConfig.padding, scope.modelData.width - width - BarConfig.padding);
                        return Math.round(Math.max(BarConfig.padding, Math.min(max, currentCenter - width / 2)));
                    }
                }
            }

            onFullscreenChanged: {
                if (fullscreen)
                    pops.close();
            }

            // Close the popout when the pointer leaves both the bar and the popout.
            Timer {
                id: closePopoutTimer

                interval: 400

                onTriggered: {
                    if (!bar.isHovered && !popoutHover.hovered)
                        pops.close();
                }
            }

            Connections {
                target: bar

                function onIsHoveredChanged(): void {
                    if (bar.isHovered)
                        closePopoutTimer.stop();
                    else if (pops.hasCurrent)
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
