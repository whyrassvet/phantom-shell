import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: page
    property var ctl
    property string style: "flat"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    function selectStyle(value) {
        if (!["flat", "floating", "islands", "island"].includes(value)) return
        page.style = value
        Quickshell.execDetached(["bash", "-c", 'mkdir -p "$1/phantom-shell" && printf "%s\\n" "$2" > "$1/phantom-shell/bar-style"', "_", page.configHome, value])
    }

    FileView {
        id: styleFile
        path: page.configHome + "/phantom-shell/bar-style"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const value = text().trim()
            page.style = ["flat", "floating", "islands", "island"].includes(value) ? value : "flat"
        }
        onLoadFailed: page.style = "flat"
    }

    Column {
        x: 24
        y: 6
        width: parent.width - 48
        spacing: 12
        SectionTitle { text: "Bar"; sub: "Choose the appearance of the bar." }
        SegRow {
            label: "Bar style"
            desc: "Flat, floating, separate islands or one island"
            options: [
                { label: "Flat", value: "flat" },
                { label: "Floating", value: "floating" },
                { label: "Islands", value: "islands" },
                { label: "One island", value: "island" }
            ]
            current: page.style
            onChosen: function(value) { page.selectStyle(value) }
        }
    }
}
