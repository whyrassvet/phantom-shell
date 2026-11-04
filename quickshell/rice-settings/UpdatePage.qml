import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: page
    property var ctl
    property var updateInfo: ({})
    property bool checked: false
    property bool checking: false
    property string failure: ""

    function check() {
        if (checking) return
        checking = true
        failure = ""
        checkProc.running = true
    }
    Process {
        id: checkProc
        command: ["bash", "-c", '"$HOME/.local/bin/rice-update" check --json']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.updateInfo = JSON.parse(text)
                    page.checked = true
                    page.failure = page.updateInfo.error || ""
                } catch (e) { page.failure = "Could not check for updates." }
                page.checking = false
            }
        }
    }
    PageScroll {
        anchors.fill: parent
        SectionTitle { text: "Update"; sub: "Check for Phantom Shell updates when you choose." }
        Rectangle {
            width: parent.width; height: contents.implicitHeight + 36; radius: 14
            color: "#121212"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
            Column {
                id: contents
                x: 18; y: 18; width: parent.width - 36; spacing: 12
                T { text: "Phantom Shell"; font.pixelSize: 18; font.bold: true }
                T {
                    width: parent.width; wrapMode: Text.WordWrap; color: "#b0b0bc"; font.pixelSize: 13
                    text: page.checking ? "Checking for updates..." : page.failure ? "Check failed: " + page.failure : !page.checked ? "Check for the latest version." : page.updateInfo.update ? "Update available: " + (page.updateInfo.latest || "unknown") : "Phantom Shell is up to date."
                }
                T { visible: page.checked; text: "Installed: " + (page.updateInfo.installed || "unknown"); color: "#8a8a92"; font.pixelSize: 12 }
                Row {
                    spacing: 8
                    Btn { text: page.checking ? "Checking..." : "Check for updates"; primary: true; onClicked: page.check() }
                    Btn {
                        visible: page.checked && !page.failure && page.updateInfo.update === true
                        text: "Update now"
                        onClicked: Quickshell.execDetached(["bash", "-c", 't="${TERMINAL:-kitty}"; command -v "$t" >/dev/null || t=kitty; exec "$t" -e "$HOME/.local/bin/rice-update"'])
                    }
                }
            }
        }
    }
}
