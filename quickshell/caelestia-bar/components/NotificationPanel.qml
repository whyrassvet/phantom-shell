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
    property var pendingDismissals: []
    readonly property int dismissDuration: 240

    function dismiss(items): void {
        const pending = pendingDismissals.slice();
        for (const n of items) if (n && !pending.includes(n)) pending.push(n);
        if (pending.length === 0) return;
        pendingDismissals = pending;
        dismissTimer.restart();
    }
    Timer {
        id: dismissTimer
        interval: root.dismissDuration
        onTriggered: {
            const pending = root.pendingDismissals;
            root.pendingDismissals = [];
            for (const n of pending) if (n && !n.closed) n.close();
        }
    }

    Text {
        id: heading
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
        text: "Notifications (" + Notifs.notClosed.length + ")"
        color: Colours.palette.m3onSurface
        font.pixelSize: 18
        font.bold: true
        elide: Text.ElideRight
    }
    ListView {
        id: notifications
        anchors { top: heading.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: clearButton.top; bottomMargin: 12; leftMargin: 16; rightMargin: 16 }
        clip: true
        spacing: 8
        Text {
            anchors.centerIn: parent
            visible: Notifs.notClosed.length === 0
            text: "All up to date!"
            color: Colours.palette.m3outline
        }
        model: Notifs.notClosed
        delegate: Item {
            id: entry
            required property var modelData
            width: ListView.view.width
            height: dismissing ? 0 : card.implicitHeight
            opacity: dismissing ? 0 : 1
            property bool dismissing: root.pendingDismissals.includes(modelData)
            Behavior on height { NumberAnimation { duration: root.dismissDuration; easing.type: Easing.InOutCubic } }
            Behavior on opacity { NumberAnimation { duration: root.dismissDuration; easing.type: Easing.OutCubic } }
            NotificationCard {
                id: card
                width: parent.width
                x: entry.dismissing ? 24 : 0
                notif: entry.modelData
                cardColor: root.cardColor
                animatedDismiss: true
                enabled: !entry.dismissing
                onDismissRequested: root.dismiss([entry.modelData])
                Behavior on x { NumberAnimation { duration: root.dismissDuration; easing.type: Easing.OutCubic } }
            }
        }
    }
    Rectangle {
        id: clearButton
        objectName: "clearNotifications"
        anchors { right: parent.right; bottom: parent.bottom; margins: 16 }
        width: 40; height: 40; radius: 14
        color: clearMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
        scale: clearMouse.pressed ? 0.96 : 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 90 } }
        Accessible.role: Accessible.Button
        Accessible.name: "Clear all notifications"
        Text { anchors.centerIn: parent; text: "󰆴"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; color: "#F6F5F4" }
        MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.dismiss(Notifs.notClosed.slice()) }
    }
}
