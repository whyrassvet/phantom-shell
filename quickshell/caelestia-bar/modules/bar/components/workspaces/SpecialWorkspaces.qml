pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.config
import qs.services

Item {
    id: root

    required property HyprlandMonitor monitor

    readonly property int activeSpecialId: monitor?.lastIpcObject.specialWorkspace?.id ?? 0
    readonly property var wsIds: {
        const allMonitors = !Config.bar.workspaces.perMonitor;
        return Hypr.workspaces.values.filter(w => w.name.startsWith("special:") && (allMonitors || w.monitor === root.monitor)).map(w => w.id);
    }

    Row {
        id: view

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Repeater {
            model: ScriptModel {
                values: root.wsIds
            }

            Workspace {
                activeWsId: root.activeSpecialId
                ws: modelData
                monitor: root.monitor
                offMonitorColour: Colours.palette.m3outline
                displayType: Config.bar.workspaces.specialDisplayType
                showWindows: Config.bar.workspaces.showWindowsOnSpecialWorkspaces
                iconRules: GlobalConfig.bar.workspaces.specialWorkspaceIcons
            }
        }
    }

    MouseArea {
        anchors.fill: view

        onClicked: event => {
            const ws = view.childAt(event.x, event.y) as Workspace;
            if (ws) {
                const match = Hypr.workspaces.values.find(w => w.id === ws.ws);
                if (match)
                    Hypr.toggleSpecial(Hypr.trimWsName(match.name));
            } else {
                Hypr.toggleSpecial("special");
            }
        }
    }
}
