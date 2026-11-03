#!/usr/bin/env python3
"""Exercise the actual edge MouseArea with Qt's synthetic pointer events."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
source = (ROOT / "quickshell/caelestia-bar/shell.qml").read_text()
start = source.index("                MouseArea {\n                    id: sessionEdge")
brace = source.index("{", start)
depth = 1
end = brace + 1
while depth:
    if source[end] == "{":
        depth += 1
    elif source[end] == "}":
        depth -= 1
    end += 1
edge = source[start:end]
edge = edge.replace("!scope.fullscreen", "true").replace("Config.session.dragThreshold", "30").replace("Config.session.enabled", "true")

qml = '''import QtQuick
import QtQuick.Window
import QtTest

TestCase {
    id: win
    name: "PowerEdgePointer"
    width: 300; height: 600; visible: true
    when: windowShown
    Item {
        id: popoutWin
        anchors.fill: parent
        property QtObject sessionState: QtObject { property bool session: false }
''' + edge + '''
        Item {
            id: corner
            anchors.fill: parent
            property bool opened: false
            function close() { opened = false }
        }
    }
        function test_middle_drag() {
            compare(sessionEdge.y, 200)
            compare(sessionEdge.height, 200)
            mousePress(sessionEdge, 4, 100, Qt.LeftButton)
            verify(sessionEdge.pressed, "middle third must receive the press")
            mouseMove(popoutWin, 250, 300, 20, Qt.LeftButton)
            compare(popoutWin.sessionState.session, true)
            mouseRelease(popoutWin, 250, 300, Qt.LeftButton)
        }
        function test_outer_thirds() {
            popoutWin.sessionState.session = false
            mousePress(popoutWin, 296, 100, Qt.LeftButton)
            verify(!sessionEdge.pressed)
            mouseRelease(popoutWin, 296, 100, Qt.LeftButton)
            mousePress(popoutWin, 296, 500, Qt.LeftButton)
            verify(!sessionEdge.pressed)
            mouseRelease(popoutWin, 296, 500, Qt.LeftButton)
        }
        function test_unified_corner_open() {
            corner.opened = true
            popoutWin.sessionState.session = false
            mousePress(popoutWin, 296, 300, Qt.LeftButton)
            verify(!sessionEdge.pressed)
            mouseRelease(popoutWin, 296, 300, Qt.LeftButton)
            corner.opened = false
        }
}
'''

with tempfile.TemporaryDirectory(prefix="phantom-edge-pointer-", dir="/tmp/opencode") as tmp:
    path = Path(tmp) / "tst_edge.qml"
    path.write_text(qml)
    env = {"PATH": os.environ["PATH"], "HOME": tmp, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software", "XDG_RUNTIME_DIR": tmp}
    log = Path(tmp) / "result.txt"
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(path), "-o", f"{log},txt"], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
    assert result.returncode == 0, f"qmltestrunner exit {result.returncode}:\n{result.stdout}\n{log.read_text() if log.exists() else '(no test log)'}"
    print("Synthetic pointer press and drag reached the power edge; outer thirds ignored.")
