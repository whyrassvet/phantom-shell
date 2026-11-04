// Adapted from Caelestia v2.5.0 notifications and sidebar components (GPL-3.0-only).
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import qs.services

Rectangle {
    id: root
    required property NotifData notif
    property bool popup: false
    property bool expanded: !popup
    signal dismissed()
    readonly property string look: popup ? PopupSettings.get("popup_style", "glass") : ""
    readonly property string surface: PopupSettings.get("colors", "black")
    readonly property color accent: PopupSettings.get("accent", true) ? Colours.palette.m3primary : "#f6f5f4"
    readonly property color base: surface === "black" ? "#000000" : surface === "slate" ? "#181b22" : surface === "white" ? "#f6f5f4" : surface === "tinted" ? Qt.tint("#0e0e0e", Qt.alpha(accent, 0.14)) : "#121214"
    readonly property bool lightText: popup && (look === "light" || (surface === "white" && look !== "island"))
    readonly property color foreground: popup ? (lightText ? "#141414" : "#f6f5f4") : Colours.palette.m3onSurface
    readonly property color secondary: popup ? (lightText ? "#5c5c64" : "#9a9aa4") : Colours.palette.m3onSurfaceVariant
    readonly property real popupOpacity: Math.max(0.3, Math.min(1, Number(PopupSettings.get("popup_opacity", 0.3))))
    readonly property string family: PopupSettings.get("font", "rounded") === "mono" ? "JetBrainsMono Nerd Font" : PopupSettings.get("font", "rounded") === "rounded" ? "Rubik" : PopupSettings.get("font", "rounded") === "system" ? "" : "Inter"
    readonly property int textSize: Math.max(10, Math.min(18, Number(PopupSettings.get("font_size", 14))))
    implicitHeight: content.implicitHeight + 24
    radius: !popup ? 18 : look === "pill" ? height / 2 : look === "minimal" ? 8 : look === "accent" ? 10 : look === "island" ? 28 : 18
    color: !popup ? Colours.tPalette.m3surfaceContainer : look === "island" ? "black" : look === "light" ? Qt.rgba(0.965, 0.96, 0.957, Math.max(popupOpacity, 0.9)) : Qt.alpha(base, look === "solid" ? 1 : look === "glass" ? Math.min(popupOpacity, 0.62) : popupOpacity)
    border.width: 1
    border.color: !popup ? Colours.outline : PopupSettings.get("border", "subtle") === "none" ? "transparent" : PopupSettings.get("border", "subtle") === "accent" || look === "glow" ? accent : (lightText ? "#1a000000" : "#1affffff")
    layer.enabled: popup && (look === "glow" || PopupSettings.get("shadow", false))
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: root.look === "glow" ? Qt.alpha(root.accent, 0.6) : "#80000000"
        shadowBlur: root.look === "glow" ? 1 : 0.5
        shadowVerticalOffset: root.look === "glow" ? 0 : 2
    }

    Rectangle { visible: root.popup && root.look === "accent"; width: 4; height: parent.height; radius: 2; color: root.accent }

    Component.onCompleted: notif.lock(root)
    Component.onDestruction: notif?.unlock(root)

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: if (root.popup) root.notif?.timer.stop()
        onExited: if (root.popup && !(root.notif?.urgency === NotificationUrgency.Critical && PopupSettings.get("critical_sticky", true))) root.notif?.timer.restart()
        onClicked: root.expanded = !root.expanded
    }

    Column {
        id: content
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 5

        Row {
            width: parent.width
            spacing: 8
            Image {
                width: root.popup ? Math.max(20, Math.min(72, Number(PopupSettings.get("icon_size", 42)))) : 36; height: width
                source: (!root.popup || PopupSettings.get("images", true)) && root.notif?.image ? Qt.resolvedUrl(root.notif.image) : Quickshell.iconPath(root.notif?.appIcon ?? "", true)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
            Column {
                width: parent.width - (root.popup ? Math.max(20, Math.min(72, Number(PopupSettings.get("icon_size", 42)))) : 36) - 52
                Text { width: parent.width; color: root.secondary; text: (root.notif?.appName ?? "") + " · " + (root.notif?.timeStr ?? ""); elide: Text.ElideRight; font.family: root.popup ? root.family : ""; font.pixelSize: root.popup ? Math.max(9, root.textSize - 2) : 11 }
                Text { width: parent.width; color: root.foreground; text: root.notif?.summary ?? ""; elide: Text.ElideRight; font.family: root.popup ? root.family : ""; font.pixelSize: root.popup ? root.textSize : 14; font.bold: true }
            }
            Text {
                width: 28; height: 28; text: "×"; color: root.foreground; font.pixelSize: 22
                horizontalAlignment: Text.AlignHCenter
                MouseArea { anchors.fill: parent; onClicked: root.notif?.close() }
            }
        }
        Text {
            width: parent.width
            text: root.notif?.body ?? ""
            color: root.secondary
            font.family: root.popup ? root.family : ""
            font.pixelSize: root.popup ? root.textSize : 12
            textFormat: Text.MarkdownText
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: root.expanded ? 100 : 2
            elide: Text.ElideRight
            onLinkActivated: link => Qt.openUrlExternally(link)
        }
        Flow {
            width: parent.width
            spacing: 6
            visible: root.expanded
            Repeater {
                model: root.notif?.actions ?? []
                Rectangle {
                    required property var modelData
                    width: actionLabel.implicitWidth + 20
                    height: 30
                    radius: 15
                    color: Colours.palette.m3secondaryContainer
                    Text { id: actionLabel; anchors.centerIn: parent; text: parent.modelData.text; color: Colours.palette.m3onSecondaryContainer }
                    MouseArea { anchors.fill: parent; onClicked: parent.modelData.invoke() }
                }
            }
        }
    }
}
