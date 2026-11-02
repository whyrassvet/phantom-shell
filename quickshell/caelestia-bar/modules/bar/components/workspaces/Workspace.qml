pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import M3Shapes
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.config
import qs.services
import qs.utils

Item {
    id: root

    required property int modelData
    required property int activeWsId
    required property int ws
    required property HyprlandMonitor monitor

    required property int displayType
    required property bool showWindows
    required property var iconRules
    property string activeLabel
    property string occupiedLabel
    property string label
    property color offMonitorColour: Colours.palette.m3outlineVariant

    readonly property list<HyprlandToplevel> toplevels: Hypr.toplevelsForWs(ws, GlobalConfig.bar.workspaces.ignoredTags)
    readonly property bool isOccupied: toplevels.length > 0
    readonly property bool hasWindows: isOccupied && showWindows && Config.bar.workspaces.maxWindowIcons > 0
    readonly property bool focused: activeWsId === ws
    readonly property bool onOtherMonitor: {
        if (Config.bar.workspaces.perMonitor)
            return false;
        const mon = Hypr.workspaces.values.find(w => w.id === ws)?.monitor;
        return mon && mon !== monitor;
    }
    readonly property color fgColour: {
        if (focused)
            return Colours.palette.m3onPrimary;
        if (onOtherMonitor)
            return offMonitorColour;
        if (isOccupied || Config.bar.workspaces.occupiedBg)
            return Colours.palette.m3onSurface;
        return Colours.layer(Colours.palette.m3outlineVariant, 2);
    }

    readonly property int indicatorSize: BarConfig.innerThickness - Tokens.padding.extraSmall

    implicitWidth: layout.implicitWidth
    implicitHeight: BarConfig.innerThickness

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.full
        color: root.focused ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3surfaceContainerHighest, root.isOccupied && Config.bar.workspaces.occupiedBg ? 0.6 : 0)

        Behavior on color {
            CAnim {}
        }
    }

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall / 2

        Item {
            id: indicatorBox

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.indicatorSize
            implicitHeight: root.indicatorSize

            Loader {
                anchors.centerIn: parent

                sourceComponent: {
                    if (root.displayType === BarWorkspaceDisplay.Icons)
                        return iconComponent;
                    if (root.displayType === BarWorkspaceDisplay.Text)
                        return textComponent;
                    return shapeComponent;
                }
            }
        }

        Repeater {
            model: root.hasWindows ? root.toplevels.slice(0, Config.bar.workspaces.maxWindowIcons) : []

            MaterialIcon {
                required property var modelData

                anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                grade: 0
                text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                color: root.focused ? Colours.palette.m3onPrimary : root.onOtherMonitor ? Colours.palette.m3outlineVariant : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }
        }
    }

    Component {
        id: shapeComponent

        MaterialShape {
            implicitSize: root.indicatorSize - Tokens.padding.extraSmall
            color: root.fgColour
            scale: root.focused ? 2 / 3 : root.isOccupied ? 1 / 3 : 1 / 4

            animationEasing: Tokens.anim.expressiveDefaultSpatial
            animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

            Behavior on color {
                CAnim {}
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Component {
        id: textComponent

        StyledText {
            animate: true
            text: {
                if (root.focused) {
                    const active = root.activeLabel;
                    if (active)
                        return active;
                }

                if (root.focused || root.isOccupied) {
                    const occupied = root.occupiedLabel;
                    if (occupied)
                        return occupied;
                }

                const custom = root.label;
                if (custom)
                    return custom;

                const ws = Hypr.workspaces.values.find(w => w.id === root.ws);
                const wsName = !ws || ws.name == root.ws ? root.ws : Hypr.trimWsName(ws.name)[0];

                const capitalisation = Config.bar.workspaces.capitalisation;
                if (capitalisation === BarWorkspaceCapitalisation.Upper)
                    return String(wsName).toUpperCase();
                else if (capitalisation === BarWorkspaceCapitalisation.Lower)
                    return String(wsName).toLowerCase();
                return wsName;
            }
            color: root.fgColour
            verticalAlignment: Qt.AlignVCenter
            font.family: Tokens.font.workspaces
        }
    }

    Component {
        id: iconComponent

        MaterialIcon {
            fill: 1
            grade: 25
            text: iconCacher.icon
            color: root.fgColour
            verticalAlignment: Qt.AlignVCenter

            WsIconCacher {
                id: iconCacher
            }
        }
    }

    component WsIconCacher: QtObject {
        id: cacher

        property string name
        readonly property string icon: Icons.matchIconRuleList(Hypr.trimWsName(name), root.iconRules)
        readonly property HyprlandWorkspace wsObj: Hypr.workspaces.values.find(w => w.id === root.ws) ?? null

        readonly property Connections conn: Connections {
            function onNameChanged(): void {
                cacher.updateName();
            }

            target: cacher.wsObj
        }

        function updateName(): void {
            if (wsObj)
                name = wsObj.name;
        }

        onWsObjChanged: updateName()
        Component.onCompleted: updateName()
    }
}
