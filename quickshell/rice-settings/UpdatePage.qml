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
    property var prefs: ({ notifications: false, major_only: false, beta: true })
    property bool prefsReady: false
    property string prefsError: ""
    readonly property bool prefsBusy: prefsProc.running
    readonly property bool available: checked && !failure && updateInfo.update === true
    readonly property var notes: checked && !failure && Array.isArray(updateInfo.news) ? updateInfo.news : []

    function check() {
        if (checking || prefsProc.running) return
        checking = true
        failure = ""
        checkProc.running = true
    }
    function setPreference(name, value) {
        if (prefsProc.running) return
        if (name === "beta") { checked = false; failure = "" }
        prefsError = ""
        prefsProc.command = ["bash", "-c", 'exec "$HOME/.local/bin/rice-update" settings "$1" "$2"', "settings", name, value ? "on" : "off"]
        prefsProc.running = true
    }
    Component.onCompleted: prefsProc.running = true
    Process {
        id: prefsProc
        command: ["bash", "-c", 'exec "$HOME/.local/bin/rice-update" settings']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    if (typeof result.notifications !== "boolean" || typeof result.major_only !== "boolean" || typeof result.beta !== "boolean") throw new Error("Invalid settings")
                    page.prefs = result
                    page.prefsReady = true
                    page.prefsError = ""
                } catch (e) { page.prefsError = "Could not load or save update settings." }
            }
        }
        onExited: function(code) { if (code !== 0) page.prefsError = "Could not load or save update settings." }
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
        SectionTitle { text: "Update"; sub: "Keep Phantom Shell up to date, on your terms." }

        Flow {
            id: layout
            width: parent.width
            spacing: 12
            property bool stacked: width < 720
            property real cardWidth: stacked ? width : Math.floor((width - spacing) * 0.42)

            Rectangle {
                width: layout.cardWidth
                height: summary.implicitHeight + 40
                radius: 16; color: "#121212"
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)
                Column {
                    id: summary
                    x: 20; y: 20; width: parent.width - 40; spacing: 16
                    Row {
                        spacing: 10
                        Rectangle {
                            width: 36; height: 36; radius: 12
                            color: page.available ? Qt.rgba(0.55, 0.85, 0.65, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                            T { anchors.centerIn: parent; kind: "icon"; text: page.available ? "\uf062" : "\uf021"; font.pixelSize: 15; color: page.available ? "#a4ddb3" : "#c8c8ce" }
                        }
                        T {
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.checking ? "Checking..." : page.failure ? "Check failed" : !page.checked ? "Ready to check" : page.available ? "Update available" : "You're up to date"
                            font.bold: true; font.pixelSize: 14
                            color: page.available ? "#a4ddb3" : "#F6F5F4"
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }
                    Column {
                        width: parent.width; spacing: 5
                        T { text: "INSTALLED VERSION"; color: "#8a8a92"; font.pixelSize: 10; font.letterSpacing: 1.1 }
                        T { objectName: "updateInstalled"; text: page.checked ? (page.updateInfo.installed || "Unknown") : "—"; font.pixelSize: 17; font.bold: true }
                    }
                    Column {
                        width: parent.width; spacing: 5
                        T { text: "LATEST VERSION"; color: "#8a8a92"; font.pixelSize: 10; font.letterSpacing: 1.1 }
                        T { objectName: "updateLatest"; text: page.checked && !page.failure ? (page.updateInfo.latest || "Unknown") : "—"; font.pixelSize: 25; font.bold: true; color: page.available ? "#a4ddb3" : "#F6F5F4" }
                    }
                    T {
                        width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12; color: page.failure ? "#e6a4a4" : "#8a8a92"
                        text: page.failure ? page.failure : page.checking ? "Contacting the update source..." : !page.checked ? "Check for a release in your selected channel." : page.available ? "An update is ready to install." : "No update is currently available."
                    }
                    Btn {
                        objectName: "updateInstall"
                        visible: page.available && !page.checking
                        width: parent.width; primary: true; icon: "\uf019"; text: "Update now"
                        onClicked: Quickshell.execDetached(["bash", "-c", 't="${TERMINAL:-kitty}"; command -v "$t" >/dev/null || t=kitty; exec "$t" -e "$HOME/.local/bin/rice-update"'])
                    }
                    T { visible: page.available; width: parent.width; wrapMode: Text.WordWrap; text: "The updater opens in a terminal."; color: "#8a8a92"; font.pixelSize: 11 }
                    Btn {
                        objectName: "updateCheck"
                        width: parent.width; primary: !page.available
                        enabled: !page.checking && !page.prefsBusy; opacity: enabled ? 1 : 0.55
                        icon: "\uf021"; text: page.checking ? "Checking..." : page.checked ? "Check again" : "Check for updates"
                        onClicked: page.check()
                    }
                }
            }
            Rectangle {
                width: layout.stacked ? layout.width : layout.width - layout.cardWidth - layout.spacing
                height: details.implicitHeight + 40
                radius: 16; color: "#121212"
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)
                Column {
                    id: details
                    x: 20; y: 20; width: parent.width - 40; spacing: 14
                    T { text: "Release notes"; font.pixelSize: 17; font.bold: true }
                    T {
                        width: parent.width; wrapMode: Text.WordWrap; color: "#8a8a92"; font.pixelSize: 12
                        text: !page.checked ? "Check for updates to see what's new." : page.failure ? "Release notes are unavailable. Try checking again." : page.notes.length === 0 ? "No release notes are available for this version." : "Latest available changes"
                    }
                    Rectangle {
                        visible: page.notes.length > 0 && !page.failure
                        width: parent.width; height: notesColumn.implicitHeight + 28; radius: 12
                        color: Qt.rgba(1, 1, 1, 0.035); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                        Column {
                            id: notesColumn
                            x: 14; y: 14; width: parent.width - 28; spacing: 10
                            T { text: page.updateInfo.latest || "Latest"; font.bold: true; font.pixelSize: 14; color: page.available ? "#a4ddb3" : "#F6F5F4" }
                            Repeater {
                                model: page.notes
                                Row {
                                    width: notesColumn.width; spacing: 9
                                    T { text: "•"; color: "#a4ddb3"; font.pixelSize: 13 }
                                    T { width: parent.width - 20; text: modelData; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: "#c2c2c8"; font.pixelSize: 12 }
                                }
                            }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }
                    T { text: "UPDATE SOURCE"; color: "#8a8a92"; font.pixelSize: 10; font.letterSpacing: 1.1 }
                    T { text: "Phantom Shell"; font.pixelSize: 13; font.bold: true }
                    T { width: parent.width; text: "Version tags from your configured repository · " + (page.prefs.beta ? "Stable and beta" : "Stable only"); wrapMode: Text.WordWrap; color: "#8a8a92"; font.pixelSize: 12 }
                    T {
                        visible: page.checked && !page.failure && !!page.updateInfo.checked
                        text: "Last checked: " + new Date(page.updateInfo.checked * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)
                        color: "#8a8a92"; font.pixelSize: 11
                    }
                }
            }
        }
        SectionTitle { text: "Update preferences"; sub: "Choose which releases to follow and when to be notified." }
        ToggleRow {
            objectName: "updateNotifications"
            label: "Update notifications"; desc: "Periodically check for new releases in the background"
            enabled: page.prefsReady && !prefsProc.running; opacity: enabled ? 1 : 0.5
            checked: page.prefs.notifications === true
            onToggled: function(v) { page.setPreference("notifications", v) }
        }
        ToggleRow {
            objectName: "updateMajorOnly"
            label: "Feature releases only"; desc: "Notify for 0.5.x after 0.4.x, not for patch updates"
            enabled: page.prefsReady && page.prefs.notifications && !prefsProc.running; opacity: enabled ? 1 : 0.45
            checked: page.prefs.major_only === true
            onToggled: function(v) { page.setPreference("major_only", v) }
        }
        ToggleRow {
            objectName: "updateBeta"
            label: "Include beta releases"; desc: "Off: stable releases only · On: stable and beta releases"
            enabled: page.prefsReady && !prefsProc.running && !page.checking; opacity: enabled ? 1 : 0.5
            checked: page.prefs.beta === true
            onToggled: function(v) { page.setPreference("beta", v) }
        }
        T { visible: page.prefsError.length > 0; text: page.prefsError; color: "#e6a4a4"; font.pixelSize: 12 }
    }
}
