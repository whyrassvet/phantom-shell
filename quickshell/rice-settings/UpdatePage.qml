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
    property var about: ({})
    property var history: []
    function loadHistory() { if (!historyProc.running) historyProc.running = true }
    Component.onCompleted: { prefsProc.running = true; aboutProc.running = true; loadHistory() }
    Process {
        id: aboutProc
        command: ["bash", "-c", 'exec "$HOME/.local/bin/rice-dashboard" about']
        stdout: StdioCollector { onStreamFinished: { try { page.about = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: historyProc
        command: ["bash", "-c", '"$HOME/.local/bin/rice-update" --help | grep -q "rice-update history" && exec "$HOME/.local/bin/rice-update" history --json']
        stdout: StdioCollector { onStreamFinished: { try { const h = JSON.parse(text); if (Array.isArray(h) && !page.checked) page.history = h } catch (e) {} } }
    }
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
                    if (!page.failure && Array.isArray(page.updateInfo.history)) page.history = page.updateInfo.history
                } catch (e) { page.failure = "Could not check for updates." }
                page.checking = false
            }
        }
    }
    Item {
        id: upper
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: preferences.top
        anchors.leftMargin: 24; anchors.rightMargin: 24; anchors.topMargin: 6; anchors.bottomMargin: 10
        Flickable {
            id: upperScroll
            anchors.fill: parent; clip: true
            contentWidth: width; contentHeight: upperColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(e) { upperScroll.contentY = Math.max(0, Math.min(upperScroll.contentHeight - upperScroll.height, upperScroll.contentY - e.angleDelta.y * 0.6)) }
            }
            Column {
                id: upperColumn
                width: parent.width; spacing: 10
                SectionTitle { id: pageTitle; text: "Update"; sub: "Keep Phantom Shell up to date, on your terms." }
                Flow {
                    id: layout
                    width: parent.width; spacing: 12
                    property bool stacked: width < 570
                    property real leftWidth: stacked ? width : Math.floor((width - spacing) * 0.44)
                    property real cardHeight: Math.max(280, upper.height - pageTitle.height - 10)
                    Rectangle {
                        objectName: "updateSummaryCard"
                        width: layout.leftWidth; height: layout.cardHeight
                        radius: 16; color: "#121212"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)
                        Flickable {
                            id: summaryScroll
                            anchors.fill: parent; anchors.margins: 16; clip: true
                            contentWidth: width; contentHeight: summary.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: function(e) { summaryScroll.contentY = Math.max(0, Math.min(Math.max(0, summaryScroll.contentHeight - summaryScroll.height), summaryScroll.contentY - e.angleDelta.y * 0.6)); e.accepted = true }
                            }
                            Column {
                                id: summary
                                width: parent.width; spacing: 12
                                Row {
                                    width: parent.width; spacing: 12
                                    Image {
                                        width: 48; height: 48; smooth: true
                                        source: "file://" + Quickshell.env("HOME") + "/.local/share/rice/icon.png"
                                        sourceSize.width: 96; sourceSize.height: 96
                                    }
                                    Column {
                                        width: parent.width - 60; spacing: 5
                                        T { width: parent.width; text: "Phantom Shell"; font.pixelSize: 17; font.bold: true; elide: Text.ElideRight }
                                        T { objectName: "updateInstalled"; width: parent.width; text: "V" + (page.updateInfo.installed || page.about.rice || "?"); color: "#c2c2c8"; font.pixelSize: 12; elide: Text.ElideRight }
                                    }
                                }
                                T {
                                    width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 12
                                    color: page.failure ? "#e6a4a4" : page.available ? "#a4ddb3" : "#8a8a92"
                                    text: page.checking ? "Checking for updates..." : page.failure ? "Check failed: " + page.failure : !page.checked ? "Ready to check" : page.available ? "Update available: " + (page.updateInfo.latest || "Unknown") : "You're up to date"
                                }
                                T { text: "RUNNING ON"; color: "#8a8a92"; font.pixelSize: 10; font.letterSpacing: 1.1 }
                                Repeater {
                                    model: [page.about.wm || "Hyprland", page.about.quickshell || "Quickshell", "Shell: " + (page.about.shell || "Unknown")]
                                    T { width: summary.width; text: "•  " + modelData; textFormat: Text.PlainText; elide: Text.ElideRight; font.pixelSize: 12; color: "#c2c2c8" }
                                }
                                Btn {
                                    objectName: "updateInstall"
                                    visible: page.available && !page.checking
                                    width: parent.width; primary: true; icon: "\uf019"; text: "Update now"
                                    onClicked: Quickshell.execDetached(["bash", "-c", 't="${TERMINAL:-kitty}"; command -v "$t" >/dev/null || t=kitty; exec "$t" -e "$HOME/.local/bin/rice-update"'])
                                }
                                Btn {
                                    objectName: "updateCheck"
                                    width: parent.width; primary: !page.available
                                    enabled: !page.checking && !page.prefsBusy; opacity: enabled ? 1 : 0.55
                                    icon: "\uf021"; text: page.checking ? "Checking..." : "Check for updates"
                                    onClicked: page.check()
                                }
                                Btn {
                                    width: parent.width; icon: "\uf09b"; text: "GitHub"
                                    onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/whyrassvet/phantom-shell"])
                                }
                            }
                        }
                    }
                    Rectangle {
                        objectName: "updateHistoryCard"
                        width: layout.stacked ? layout.width : layout.width - layout.leftWidth - layout.spacing
                        height: layout.cardHeight
                        radius: 16; color: "#121212"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)
                        Column {
                            id: historyHeader
                            x: 16; y: 16; width: parent.width - 32; spacing: 4
                            T { text: "Release notes"; font.pixelSize: 17; font.bold: true }
                            T { width: parent.width; text: page.history.length ? "Scroll to explore previous versions" : "Release notes are unavailable. Check for updates to load them."; wrapMode: Text.WordWrap; color: "#8a8a92"; font.pixelSize: 11 }
                        }
                        Flickable {
                            id: historyScroll
                            objectName: "updateHistoryScroll"
                            anchors.top: historyHeader.bottom; anchors.topMargin: 12
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 16
                            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 16; anchors.rightMargin: 16
                            clip: true; contentWidth: width; contentHeight: historyList.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: function(e) { historyScroll.contentY = Math.max(0, Math.min(Math.max(0, historyScroll.contentHeight - historyScroll.height), historyScroll.contentY - e.angleDelta.y * 0.6)); e.accepted = true }
                            }
                            Column {
                                id: historyList
                                width: parent.width; spacing: 10
                                Repeater {
                                    model: page.history
                                    Rectangle {
                                        width: historyList.width; height: entry.implicitHeight + 24; radius: 12
                                        color: Qt.rgba(1, 1, 1, 0.035); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                                        Column {
                                            id: entry
                                            x: 12; y: 12; width: parent.width - 24; spacing: 8
                                            T { width: parent.width; text: modelData.version || ""; textFormat: Text.PlainText; font.bold: true; font.pixelSize: 14; color: "#a4ddb3"; wrapMode: Text.Wrap }
                                            Repeater {
                                                model: modelData.lines || []
                                                T { width: entry.width; text: "•  " + modelData; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: "#c2c2c8"; font.pixelSize: 12 }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Item {
        id: preferences
        objectName: "updatePreferences"
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 24; anchors.rightMargin: 24; anchors.bottomMargin: 12
        height: Math.min(260, Math.max(0, page.height * 0.52))
        Flickable {
            id: preferenceScroll
            anchors.fill: parent; clip: true
            contentWidth: width; contentHeight: preferenceColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(e) { preferenceScroll.contentY = Math.max(0, Math.min(Math.max(0, preferenceScroll.contentHeight - preferenceScroll.height), preferenceScroll.contentY - e.angleDelta.y * 0.6)); e.accepted = true }
            }
            Column {
                id: preferenceColumn
                width: parent.width; spacing: 6
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
    }
}
