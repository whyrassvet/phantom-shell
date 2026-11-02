pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // rice-effects creates this marker when blur and transparency are disabled.
    property bool flat: false

    FileView {
        id: flatFile
        path: `${Quickshell.env("HOME")}/.cache/rice/flat`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.flat = true
        onLoadFailed: root.flat = false
    }

    // File watching cannot detect a parent directory created after startup.
    Timer {
        interval: 1000
        running: !root.flat
        repeat: true
        onTriggered: flatFile.reload()
    }
}
