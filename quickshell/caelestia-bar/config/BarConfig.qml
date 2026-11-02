pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Total height of the horizontal bar in px.
    property int thickness: 36
    // Padding between the bar edges and the entries.
    property int padding: 4
    // Command used by the logo button.
    property string launcherCommand: "rofi -show drun"

    readonly property int innerThickness: thickness - padding * 2
}
