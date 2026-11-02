pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Total height of the horizontal bar in px.
    property int thickness: 40
    // Padding between the bar edges and the entries.
    property int padding: 4
    // Command used by the logo button.
    property string launcherCommand: "rofi -show drun"
    // Command used by the power button. Empty = toggle the session panel state.
    property string powerCommand: ""

    readonly property int innerThickness: thickness - padding * 2
}
