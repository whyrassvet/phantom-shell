pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.config
import qs.services

StyledRect {
    id: root

    readonly property alias layout: layout
    readonly property alias items: items
    readonly property alias expandIcon: expandIcon

    readonly property int padding: Config.bar.tray.background ? Tokens.padding.medium : Tokens.padding.extraSmall
    readonly property int spacing: Config.bar.tray.background ? Tokens.spacing.medium : Tokens.spacing.extraSmall

    property bool expanded

    readonly property real nonAnimWidth: {
        if (!Config.bar.tray.compact)
            return layout.implicitWidth + padding * 2;
        if (expanded)
            return padding + layout.implicitWidth + spacing + height;
        return items.count > 0 ? height : 0;
    }

    clip: true
    visible: width > 0

    implicitHeight: BarConfig.innerThickness
    implicitWidth: nonAnimWidth

    color: BarConfig.style === "islands" && Config.bar.tray.background && items.count > 0
        ? Qt.alpha(Qt.darker(Colours.palette.m3surfaceContainer, 1.35), Effects.flat ? 1 : Colours.tPalette.m3surface.a)
        : Qt.alpha(Colours.tPalette.m3surfaceContainer, (Config.bar.tray.background && items.count > 0) ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: height / 2
    border.width: BarConfig.style === "islands" && Config.bar.tray.background && items.count > 0 ? 1 : 0
    border.color: Colours.outline

    Row {
        id: layout

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.padding
        spacing: Tokens.spacing.small

        opacity: root.expanded || !Config.bar.tray.compact ? 1 : 0

        add: Transition {
            Anim {
                properties: "scale"
                from: 0
                to: 1
                easing: Tokens.anim.standardDecel
            }
        }

        move: Transition {
            Anim {
                properties: "scale"
                to: 1
                easing: Tokens.anim.standardDecel
            }
            Anim {
                properties: "x,y"
            }
        }

        Repeater {
            id: items

            model: ScriptModel {
                values: SystemTray.items.values.filter(i => i.status !== Status.Passive && !GlobalConfig.bar.tray.hiddenIcons.includes(i.id))
            }

            TrayItem {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: expandIcon

        asynchronous: true

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        width: root.height
        height: root.height

        active: Config.bar.tray.compact && items.count > 0

        sourceComponent: Item {
            implicitWidth: expandIconInner.implicitWidth
            implicitHeight: expandIconInner.implicitHeight

            MaterialIcon {
                id: expandIconInner

                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -1
                anchors.verticalCenterOffset: root.expanded ? 0 : 2
                text: "chevron_left"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
                rotation: root.expanded ? 180 : 0

                Behavior on rotation {
                    Anim {}
                }
            }
        }
    }

    Behavior on implicitWidth {
        Anim {}
    }
}
