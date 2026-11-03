pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Caelestia
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.config
import qs.services

StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property bool onSpecial: (monitor?.lastIpcObject.specialWorkspace?.name?.length ?? 0) > 0
    readonly property int activeWsId: monitor.activeWorkspace?.id ?? 1
    readonly property int shown: Math.max(1, Config.bar.workspaces.shown)

    readonly property var wsIds: {
        if (Config.bar.workspaces.showUnoccupied)
            return Array.from({
                length: shown
            }, (_, i) => i + 1);

        const allMonitors = !Config.bar.workspaces.perMonitor;
        const ignoredTags = GlobalConfig.bar.workspaces.ignoredTags;
        const workspaces = Hypr.workspaces.values.filter(w => w.id > 0 && (allMonitors || w.monitor === root.monitor) && (w.id === activeWsId || w.toplevels.values.some(t => !Hypr.isToplevelIgnored(t, ignoredTags))));
        const currentIdx = workspaces.findIndex(w => w.id === activeWsId);
        if (currentIdx < 0)
            return [];

        const end = CUtils.clamp(currentIdx + 1, Math.min(shown, workspaces.length), workspaces.length);
        const start = Math.max(0, end - shown);

        return workspaces.slice(start, end).map(w => w.id);
    }

    // Only relevant for when showUnoccupied is true
    readonly property int groupOffset: {
        if (!Config.bar.workspaces.showUnoccupied)
            return 0;
        return Math.floor((activeWsId - 1) / shown) * shown;
    }

    implicitHeight: BarConfig.innerThickness
    implicitWidth: workspaces.implicitWidth + Tokens.padding.extraSmall * (BarConfig.style === "islands" ? 1 : 2)

    color: BarConfig.style === "islands" ? Qt.alpha(Qt.darker(Colours.palette.m3surfaceContainer, 1.35), Effects.flat ? 1 : Colours.tPalette.m3surface.a) : Colours.tPalette.m3surfaceContainer
    radius: height / 2

    Rectangle {
        objectName: "workspaceOutline"
        anchors.fill: parent
        z: 1
        radius: parent.radius
        color: "transparent"
        border.width: BarConfig.style === "islands" ? 1 : 0
        border.color: Colours.outline
    }

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1
        visible: !root.fullscreen

        Row {
            id: workspaces

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: ScriptModel {
                    values: root.wsIds
                }

                Workspace {
                    activeWsId: root.activeWsId
                    ws: Config.bar.workspaces.showUnoccupied ? root.groupOffset + modelData : modelData
                    monitor: root.monitor

                    displayType: Config.bar.workspaces.displayType
                    showWindows: Config.bar.workspaces.showWindows
                    iconRules: GlobalConfig.bar.workspaces.workspaceIcons
                    activeLabel: Config.bar.workspaces.activeLabel
                    occupiedLabel: Config.bar.workspaces.occupiedLabel
                    label: Config.bar.workspaces.label
                }
            }
        }

        MouseArea {
            anchors.fill: workspaces

            onClicked: event => {
                const ws = (workspaces.childAt(event.x, event.y) as Workspace)?.ws;
                if (!ws)
                    return;
                if (Hypr.activeWsId !== ws)
                    Hypr.focusWorkspace(ws);
                else
                    Hypr.toggleSpecial("special");
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: specialWs

        anchors.fill: parent

        asynchronous: true
        active: opacity > 0
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: Item {
            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3scrim, Colours.light ? 0 : 0.2)
            }

            SpecialWorkspaces {
                anchors.fill: parent
                monitor: root.monitor
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Behavior on implicitWidth {
        Anim {}
    }
}
