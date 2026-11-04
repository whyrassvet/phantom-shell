// Adapted from Caelestia v2.5.0 sidebar notification dock (GPL-3.0-only).
pragma ComponentBehavior: Bound

import QtQuick
import qs.services

Rectangle {
    id: root
    required property ScreenState screenState
    required property color backgroundColor
    required property color cardColor
    width: 380
    radius: 22
    color: root.backgroundColor
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
            spacing: 6
            Text { width: Math.max(0, parent.width - dndButton.width - clearButton.width - 12); anchors.verticalCenter: parent.verticalCenter; text: "Notifications (" + Notifs.notClosed.length + ")"; color: Colours.palette.m3onSurface; font.pixelSize: 18; font.bold: true; elide: Text.ElideRight }
            Rectangle {
                id: dndButton
                width: dndLabel.implicitWidth + 26; height: 36; radius: 18
                color: Notifs.dnd ? (dndMouse.containsMouse ? Qt.lighter(Colours.palette.m3primary, 1.1) : Colours.palette.m3primary) : (dndMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                scale: dndMouse.pressed ? 0.96 : 1
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 90 } }
                Text { id: dndLabel; anchors.centerIn: parent; text: Notifs.dnd ? "DND on" : "DND off"; font.pixelSize: 13; font.bold: Notifs.dnd; color: Notifs.dnd ? Colours.palette.m3onPrimary : "#F6F5F4" }
                MouseArea { id: dndMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.dnd = !Notifs.dnd }
            }
            Rectangle {
                id: clearButton
                width: clearLabel.implicitWidth + 26; height: 36; radius: 18
                color: clearMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                scale: clearMouse.pressed ? 0.96 : 1
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 90 } }
                Text { id: clearLabel; anchors.centerIn: parent; text: "Clear"; font.pixelSize: 13; color: "#F6F5F4" }
                MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { for (const n of Notifs.notClosed.slice()) n.close(); } }
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
                    color: root.cardColor
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.04)
                    Text {
                        anchors.centerIn: parent
                        text: (group.modelData || "Unknown") + "  ·  " + group.notifications.length + (group.expanded ? "  ▴" : "  ▾")
                        color: Colours.palette.m3onSurface
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: group.expanded = !group.expanded }
                }
                Repeater {
                    model: group.expanded ? group.notifications : []
                    NotificationCard {
                        required property var modelData
                        width: group.width
                        notif: modelData
                        expanded: group.expanded
                        cardColor: root.cardColor
                    }
                }
            }
        }
    }

}
