#!/usr/bin/env python3
"""Exercise the dashboard's real edge item with synthetic mouse events."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
source = (ROOT / "quickshell/rice-desktop/Dashboard.qml").read_text()
start = source.index("    Item {\n        id: edge\n")
end = source.index("\n    // wallpaper preview", start)
edge = source[start:end]
qml = '''import QtQuick
import QtTest
TestCase {
    id: db
    name: "DashboardGesture"
    width: 800; height: 600; visible: true
    when: windowShown
    property bool edgeOn: true
    property bool open: false
    property int calls: 0
    function show(tab, byEdge) { open = true; calls++ }
    function pointerMoved() {}
''' + edge + '''
    function init() { open = false; edgeOn = true; calls = 0 }
    function test_geometry() {
        compare(edge.x, 200); compare(edge.width, 400)
        db.width = 1200
        compare(edge.x, 300); compare(edge.width, 600)
        db.width = 800
    }
    function test_hover_click_and_short_drag() {
        mouseMove(db, 400, 599, 20)
        wait(300); compare(calls, 0)
        mouseClick(db, 400, 599, Qt.LeftButton); compare(calls, 0)
        mousePress(db, 400, 599, Qt.LeftButton)
        mouseMove(db, 400, 580, 20, Qt.LeftButton)
        mouseRelease(db, 400, 580, Qt.LeftButton)
        mousePress(db, 400, 599, Qt.RightButton)
        mouseMove(db, 400, 550, 20, Qt.RightButton)
        mouseRelease(db, 400, 550, Qt.RightButton)
        compare(calls, 0)
    }
    function test_drag() {
        mousePress(db, 400, 599, Qt.LeftButton)
        mouseMove(db, 400, 560, 20, Qt.LeftButton)
        compare(calls, 1)
        mouseRelease(db, 400, 560, Qt.LeftButton)
    }
    function test_outer_and_disabled() {
        mousePress(db, 100, 599, Qt.LeftButton)
        mouseMove(db, 100, 550, 20, Qt.LeftButton)
        mouseRelease(db, 100, 550, Qt.LeftButton)
        mousePress(db, 700, 599, Qt.LeftButton)
        mouseMove(db, 700, 550, 20, Qt.LeftButton)
        mouseRelease(db, 700, 550, Qt.LeftButton)
        edgeOn = false
        mousePress(db, 400, 599, Qt.LeftButton)
        mouseMove(db, 400, 550, 20, Qt.LeftButton)
        mouseRelease(db, 400, 550, Qt.LeftButton)
        compare(calls, 0)
    }
}
'''
with tempfile.TemporaryDirectory(prefix="phantom-dashboard-gesture-", dir="/tmp/opencode") as tmp:
    path = Path(tmp) / "tst_gesture.qml"
    path.write_text(qml)
    env = {"PATH": os.environ["PATH"], "HOME": tmp, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software", "XDG_RUNTIME_DIR": tmp}
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(path)], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
    assert result.returncode == 0, result.stdout
    print(result.stdout)
