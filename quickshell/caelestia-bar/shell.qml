// phantom-shell bar: horizontal, top edge, one surface per monitor.
// Reuses Caelestia's bar module (GPL-3), rewritten for horizontal layout.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components.containers
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
                    popouts: popouts
                    fullscreen: scope.fullscreen
                }

                BarPopouts.Wrapper {
                    id: popouts

                    screen: scope.modelData
                    offsetScale: 1
                }
            }
        }
    }
}
