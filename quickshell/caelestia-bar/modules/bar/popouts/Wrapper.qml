// Stage 1 stub: keeps the Bar API while popouts are not ported yet.
// Stage 2 replaces this with a slim wrapper around the real popouts.

import QtQuick
import Quickshell

Item {
    id: root

    required property ShellScreen screen
    required property real offsetScale

    property string currentName
    property bool hasCurrent
    property real currentCenter

    readonly property real nonAnimWidth: 0
    readonly property real nonAnimHeight: 0

    visible: false
    implicitWidth: 0
    implicitHeight: 0

    function close(): void {
        hasCurrent = false;
    }
}
