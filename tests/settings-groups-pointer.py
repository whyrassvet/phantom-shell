#!/usr/bin/env python3
"""Verify expanded navigation rows do not flash on the group click."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
source = (root / "quickshell/rice-settings/shell.qml").read_text()
nav = source[source.index("    component NavPage: Rectangle {"):source.index("\n    Rectangle {\n        id: card")]
groups = source[source.index("                Repeater {\n                    model: win.navGroups"):source.index("\n            }\n        }\n\n        NavPage {")]
with tempfile.TemporaryDirectory(prefix="phantom-nav-pointer-", dir="/tmp/opencode") as tmp:
    path = Path(tmp)
    (path / "T.qml").write_text('import QtQuick\nText { property string kind: "body" }\n')
    (path / "tst_groups.qml").write_text('''import QtQuick
import QtTest
TestCase {
    id: win
    name: "SettingsGroups"
    width: 260; height: 800; visible: true; when: windowShown
    property int page: 0
    property var pages: Array.from({length: 16}, (_, i) => ({ name: "Page " + i, icon: "*" }))
    property var navGroups: [
        { name: "Appearance", icon: "*", pages: [2, 6, 7, 12] },
        { name: "Desktop", icon: "*", pages: [4, 5, 10, 11, 14] },
        { name: "Sound & Alerts", icon: "*", pages: [1, 8] },
        { name: "System", icon: "*", pages: [9, 13] }
    ]
    property var expandedGroups: ({})
    function toggleGroup(name) {
        const groups = Object.assign({}, expandedGroups)
        groups[name] = !groups[name]
        expandedGroups = groups
    }
''' + nav + '''
    Flickable {
        id: navFlick
        width: 206; height: 780; contentHeight: navCol.height; contentWidth: width
        Column {
            id: navCol
            width: 206; spacing: 10
''' + groups + '''
        }
    }
    function test_open_groups() {
        for (const group of navGroups) {
            const button = findChild(navCol, "navGroup_" + group.name)
            verify(button !== null)
            mouseMove(button, 100, 23)
            mouseClick(button, 100, 23)
            verify(expandedGroups[group.name])
            const last = findChild(navCol, "navPage_" + group.pages[group.pages.length - 1])
            verify(last !== null)
            compare(last.hoverReady, false)
            compare(last.color.a, 0)
            wait(30)
            verify(last.hoverReady)
            compare(last.color.a, 0)
            wait(180)
            compare(last.color.a, 0)
            compare(win.page, 0)
            mouseMove(last, 100, 23)
            wait(180)
            verify(last.color.a > 0)
            mouseMove(button, 100, 23)
            mouseClick(button, 100, 23)
            verify(!expandedGroups[group.name])
            wait(50)
        }
    }
}
''')
    env = {"PATH": os.environ["PATH"], "HOME": tmp, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software", "XDG_RUNTIME_DIR": tmp}
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(path / "tst_groups.qml")], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
    assert result.returncode == 0, result.stdout
    print("Navigation group clicks do not flash the last row; real hover still works.")
