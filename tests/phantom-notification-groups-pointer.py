#!/usr/bin/env python3
"""Exercise the real panel layout and mouse handlers with isolated notification data."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="phantom-notification-groups-", dir="/tmp/opencode") as tmp:
    path = Path(tmp)
    stubs = path / "stubs"
    stubs.mkdir()
    (stubs / "qmldir").write_text("singleton Notifs 1.0 Notifs.qml\nsingleton Colours 1.0 Colours.qml\nScreenState 1.0 ScreenState.qml\n")
    (stubs / "Notifs.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property bool dnd: false
    property int closedCount: 0
    property var notClosed: [
        {appName: "App A", close: () => closedCount++}, {appName: "App A", close: () => closedCount++},
        {appName: "App A", close: () => closedCount++}, {appName: "App A", close: () => closedCount++},
        {appName: "App B", close: () => closedCount++}
    ]
}''')
    (stubs / "Colours.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property color outline: "#333333"
    property var palette: ({m3onSurface: "white", m3outline: "gray", m3primary: "blue", m3onPrimary: "white"})
}''')
    (stubs / "ScreenState.qml").write_text('import QtQuick\nQtObject { property bool sidebar: true }\n')
    panel = (root / "quickshell/caelestia-bar/components/NotificationPanel.qml").read_text()
    panel = panel.replace("import qs.services", 'import "stubs"')
    panel = panel.replace("NotificationCard {", "Rectangle {")
    panel = panel.replace("                        notif: modelData\n                        expanded: group.expanded\n                        cardColor: root.cardColor", "                        height: 50\n                        color: root.cardColor")
    panel = panel.replace("id: group\n", 'id: group\n                objectName: "group-" + modelData\n')
    panel = panel.replace("width: group.width\n                    height: 38", 'objectName: "header-" + group.modelData\n                    width: group.width\n                    height: 38')
    panel = panel.replace("id: dndButton\n", 'id: dndButton\n                objectName: "dndButton"\n')
    panel = panel.replace("id: clearButton\n", 'id: clearButton\n                objectName: "clearButton"\n')
    (path / "NotificationPanel.qml").write_text(panel)
    (path / "tst_groups.qml").write_text('''import QtQuick
import QtTest
import "stubs"
TestCase {
    name: "NotificationGroups"
    width: 420; height: 400; visible: true; when: windowShown
    ScreenState { id: state }
    NotificationPanel { id: panel; width: 380; height: 360; screenState: state; backgroundColor: "black"; cardColor: "#20ffffff" }
    function test_groups_and_dnd() {
        let a = findChild(panel, "group-App A")
        let b = findChild(panel, "group-App B")
        verify(a !== null); verify(b !== null)
        compare(findChild(panel, "header-App A").color, panel.cardColor)
        compare(a.expanded, false)
        let collapsedHeight = a.height
        mouseClick(findChild(panel, "header-App A"))
        compare(a.expanded, true)
        tryVerify(() => a.height > collapsedHeight + 180)
        compare(b.expanded, false)
        mouseClick(findChild(panel, "header-App A"))
        compare(a.expanded, false)
        tryCompare(a, "height", collapsedHeight)
        mouseClick(findChild(panel, "dndButton"))
        compare(Notifs.dnd, true)
        mouseClick(findChild(panel, "dndButton"))
        compare(Notifs.dnd, false)
        mouseClick(findChild(panel, "clearButton"))
        compare(Notifs.closedCount, 5)
    }
}''')
    env = {"PATH": os.environ["PATH"], "HOME": tmp, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software", "XDG_RUNTIME_DIR": tmp}
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(path / "tst_groups.qml")], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
    assert result.returncode == 0, result.stdout
    print("Notification groups, card color, DND and clear respond to synthetic clicks.")
