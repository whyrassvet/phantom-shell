pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Total height of the horizontal bar in px.
    property int thickness: 40
    // Padding between the bar edges and the entries.
    property int padding: 4
    property string style: "flat"
    readonly property int topGap: style === "flat" ? 0 : 8

    FileView {
        id: styleFile
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/phantom-shell/bar-style`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const value = text().trim();
            root.style = ["flat", "floating", "islands", "island"].includes(value) ? value : "flat";
        }
        onLoadFailed: root.style = "flat"
    }
    // A newly-created parent directory may not be covered by the file watcher.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: styleFile.reload()
    }
    // Command used by the logo button.
    property string launcherCommand: "phantom-app-launcher"
    // Command used by the power button. Empty = toggle the session panel state.
    property string powerCommand: ""

    readonly property int innerThickness: thickness - padding * 2
}
