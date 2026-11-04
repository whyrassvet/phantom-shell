pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var values: ({})
    property string lastText: ""
    function get(key, fallback) {
        if (key === "popup_style" && values[key] === "match")
            return values.style === "solid" ? "solid" : "glass";
        return values[key] === undefined ? fallback : values[key];
    }
    FileView {
        id: config
        path: `${Quickshell.env("HOME")}/.config/rice/notify.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const data = text();
            if (data === root.lastText) return;
            try { root.values = JSON.parse(data); root.lastText = data; } catch (e) { console.warn("Invalid notification settings:", e); }
        }
        onLoadFailed: if (root.lastText !== "") { root.lastText = ""; root.values = ({}); }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: config.reload() }
}
