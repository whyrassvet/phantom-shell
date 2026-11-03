// Adapted from Caelestia v2.5.0 notifications and sidebar components (GPL-3.0-only).
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

Rectangle {
    id: root
    required property NotifData notif
    property bool popup: false
    property bool expanded: !popup
    signal dismissed()
    implicitHeight: content.implicitHeight + 24
    radius: 18
    color: Colours.tPalette.m3surfaceContainer
    border.width: 1
    border.color: Colours.outline

    Component.onCompleted: notif.lock(root)
    Component.onDestruction: notif?.unlock(root)

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: if (root.popup) root.notif?.timer.stop()
        onExited: if (root.popup) root.notif?.timer.restart()
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
                width: 36; height: 36
                source: root.notif?.image ? Qt.resolvedUrl(root.notif.image) : Quickshell.iconPath(root.notif?.appIcon ?? "", true)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
            Column {
                width: parent.width - 80
                Text { width: parent.width; color: Colours.palette.m3onSurfaceVariant; text: (root.notif?.appName ?? "") + " · " + (root.notif?.timeStr ?? ""); elide: Text.ElideRight; font.pixelSize: 11 }
                Text { width: parent.width; color: Colours.palette.m3onSurface; text: root.notif?.summary ?? ""; elide: Text.ElideRight; font.pixelSize: 14; font.bold: true }
            }
            Text {
                width: 28; height: 28; text: "×"; color: Colours.palette.m3onSurface; font.pixelSize: 22
                horizontalAlignment: Text.AlignHCenter
                MouseArea { anchors.fill: parent; onClicked: root.notif?.close() }
            }
        }
        Text {
            width: parent.width
            text: root.notif?.body ?? ""
            color: Colours.palette.m3onSurfaceVariant
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
