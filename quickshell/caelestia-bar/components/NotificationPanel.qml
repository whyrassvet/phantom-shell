// Adapted from Caelestia v2.5.0 sidebar notification dock (GPL-3.0-only).
pragma ComponentBehavior: Bound

import QtQuick
import qs.services

Rectangle {
    id: root
    required property ScreenState screenState
    width: 380
    radius: 22
    color: Colours.tPalette.m3surfaceContainerLow
    border.width: 1
    border.color: Colours.outline
    focus: visible
    Keys.onEscapePressed: screenState.sidebar = false

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        Row {
            width: parent.width
            spacing: 12
            Text { width: parent.width - 150; text: "Notifications (" + Notifs.notClosed.length + ")"; color: Colours.palette.m3onSurface; font.pixelSize: 18; font.bold: true }
            Text {
                text: Notifs.dnd ? "DND on" : "DND off"
                color: Colours.palette.m3primary
                MouseArea { anchors.fill: parent; onClicked: Notifs.dnd = !Notifs.dnd }
            }
            Text {
                text: "Clear"; color: Colours.palette.m3primary
                MouseArea { anchors.fill: parent; onClicked: { for (const n of Notifs.notClosed.slice()) n.close(); } }
            }
        }
        ListView {
            width: parent.width
            height: Math.max(0, parent.height - y)
            clip: true
            spacing: 8
            Text {
                anchors.centerIn: parent
                visible: Notifs.notClosed.length === 0
                text: "All up to date!"
                color: Colours.palette.m3outline
            }
            model: [...new Set(Notifs.notClosed.map(n => n.appName))]
            delegate: Column {
                id: group
                required property string modelData
                property bool expanded: false
                readonly property var notifications: Notifs.notClosed.filter(n => n.appName === modelData)
                width: ListView.view.width
                spacing: 5
                Rectangle {
                    width: group.width
                    height: 38
                    radius: 14
                    color: Colours.tPalette.m3surfaceContainer
                    Text {
                        anchors.centerIn: parent
                        text: (group.modelData || "Unknown") + "  ·  " + group.notifications.length + (group.expanded ? "  ▴" : "  ▾")
                        color: Colours.palette.m3onSurface
                    }
                    MouseArea { anchors.fill: parent; onClicked: group.expanded = !group.expanded }
                }
                Repeater {
                    model: group.expanded ? group.notifications : group.notifications.slice(0, 3)
                    NotificationCard {
                        required property var modelData
                        width: group.width
                        notif: modelData
                        expanded: group.expanded
                    }
                }
            }
        }
    }
}
