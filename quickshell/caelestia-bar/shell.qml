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
                WlrLayershell.keyboardFocus: pops.hasCurrent && pops.currentName === "wirelesspassword" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                exclusiveZone: -1

                mask: Region {
                    id: barInputRegion

                    width: scope.modelData.width
                    height: bar.shouldBeVisible ? BarConfig.thickness : 0

                    Region {
                        id: popoutInputRegion

                        x: Math.max(0, Math.floor(revealArea.x - revealArea.joinRadius))
                        y: BarConfig.thickness
                        width: Math.min(scope.modelData.width - x, Math.ceil(pops.width + 2 * revealArea.joinRadius))
                        height: bar.shouldBeVisible ? Math.max(0, Math.ceil(pops.height * popoutWin.reveal)) : 0
                    }
                }

                Rectangle {
                    id: barBackground

                    anchors.top: parent.top
                    width: parent.width
                    height: BarConfig.thickness
                    visible: bar.shouldBeVisible
                    color: Effects.flat ? Colours.palette.m3surface : Colours.tPalette.m3surface
                }

                Bar.BarWrapper {
                    id: bar

                    anchors.top: parent.top
                    width: parent.width
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

                    y: BarConfig.thickness
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
                            startX: 0
                            startY: 0
                            PathLine { x: revealArea.width; y: 0 }
                            PathLine { x: revealArea.width; y: revealArea.height - popoutBackground.corner }
                            PathQuad { x: revealArea.width - popoutBackground.corner; y: revealArea.height; controlX: revealArea.width; controlY: revealArea.height }
                            PathLine { x: popoutBackground.corner; y: revealArea.height }
                            PathQuad { x: 0; y: revealArea.height - popoutBackground.corner; controlX: 0; controlY: revealArea.height }
                            PathLine { x: 0; y: 0 }
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
