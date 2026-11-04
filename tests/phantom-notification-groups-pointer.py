#!/usr/bin/env python3
"""Exercise the flat notification list and clear button with isolated data."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="phantom-notification-list-", dir="/tmp/opencode") as tmp:
    path = Path(tmp)
    stubs = path / "stubs"
    stubs.mkdir()
    (stubs / "qmldir").write_text("singleton Notifs 1.0 Notifs.qml\nsingleton Colours 1.0 Colours.qml\nScreenState 1.0 ScreenState.qml\n")
    (stubs / "Notifs.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
    property int closedCount: 0
    property var notClosed: [
        {appName: "App A", close: () => closedCount++}, {appName: "App A", close: () => closedCount++},
        {appName: "App A", close: () => closedCount++}, {appName: "App B", close: () => closedCount++}
    ]
}''')
    (stubs / "Colours.qml").write_text('''pragma Singleton
import QtQuick
QtObject { property color outline: "#333333"; property var palette: ({m3onSurface: "white", m3outline: "gray"}) }''')
    (stubs / "ScreenState.qml").write_text('import QtQuick\nQtObject { property bool sidebar: true }\n')
    panel = (root / "quickshell/caelestia-bar/components/NotificationPanel.qml").read_text()
    panel = panel.replace("import qs.services", 'import "stubs"')
    panel = panel.replace("delegate: NotificationCard {", "delegate: Rectangle {")
    panel = panel.replace("            notif: modelData\n            cardColor: root.cardColor", '            height: 50\n            color: root.cardColor\n            objectName: "card-" + modelData.appName')
    panel = panel.replace("id: notifications\n", 'id: notifications\n        objectName: "notificationList"\n')
    (path / "NotificationPanel.qml").write_text(panel)
    (path / "tst_list.qml").write_text('''import QtQuick
import QtTest
import "stubs"
TestCase {
    name: "NotificationList"
    width: 420; height: 400; visible: true; when: windowShown
    ScreenState { id: state }
    NotificationPanel { id: panel; width: 380; height: 360; screenState: state; backgroundColor: "black"; cardColor: "#20ffffff" }
    function test_list_and_clear() {
        const list = findChild(panel, "notificationList")
        const button = findChild(panel, "clearNotifications")
        verify(list !== null); verify(button !== null)
        compare(list.count, 4)
        tryVerify(() => findChild(panel, "card-App A") !== null)
        compare(list.itemAtIndex(0).modelData.appName, "App A")
        compare(list.itemAtIndex(1).modelData.appName, "App A")
        compare(list.itemAtIndex(2).modelData.appName, "App A")
        verify(button.y > list.y + list.height)
        mouseClick(button)
        compare(Notifs.closedCount, 4)
    }
}''')
    env = {"PATH": os.environ["PATH"], "HOME": tmp, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software", "XDG_RUNTIME_DIR": tmp}
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(path / "tst_list.qml")], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
    assert result.returncode == 0, result.stdout
    print("Flat notification list and clear button respond to synthetic clicks.")
