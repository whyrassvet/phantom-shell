#!/usr/bin/env python3
"""Check dock scale persistence and the actual hover handler with child controls."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
source = (ROOT / "quickshell/rice-desktop/Dock.qml").read_text()
handler = source[source.index("        HoverHandler {"):source.index("    Rectangle {\n        id: bar")]
assert 'implicitHeight: bar.height + 28' in source
assert 'mask: Region { item: (dock.reveal || slide.running) ? hoverArea : edge }' in source
qml = '''import QtQuick
import QtTest
TestCase {
    id: dock
    name: "DockHover"
    width: 400; height: 100; visible: true; when: windowShown
    property bool hovering: false
    property int clicks: 0
    Item {
        id: hoverArea
        anchors.fill: parent
''' + handler + '''
        Rectangle {
            x: 140; y: 30; width: 100; height: 50
            MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: dock.clicks++ }
        }
    }
    Timer { id: hideTimer; interval: 500; onTriggered: dock.hovering = false }
    function test_stationary_and_child() {
        mouseMove(dock, 10, 10, 20)
        tryCompare(dock, "hovering", true)
        mouseMove(dock, 180, 50, 20)
        wait(1300); compare(dock.hovering, true)
        mouseClick(dock, 180, 50, Qt.LeftButton); compare(dock.clicks, 1)
        wait(700); compare(dock.hovering, true)
    }
}
'''
with tempfile.TemporaryDirectory(prefix="phantom-dock-", dir="/tmp/opencode") as tmp:
    env = {"PATH": os.environ["PATH"], "HOME": tmp, "QT_QPA_PLATFORM": "offscreen",
           "QT_QUICK_BACKEND": "software", "XDG_RUNTIME_DIR": tmp}
    path = Path(tmp) / "tst_dock.qml"
    path.write_text(qml)
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(path)], env=env,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
    assert result.returncode == 0, result.stdout
    print(result.stdout)
    cmd = [str(ROOT / "bin/desktop-set")]
    def state():
        return json.loads(subprocess.check_output(cmd + ["state"], env=env, text=True))
    assert state()["dock"]["scale"] == 1
    for value, expected in (("1.5", 1.5), ("3", 2), ("0.5", 1)):
        subprocess.run(cmd + ["dock", "scale", value], env=env, check=True)
        assert state()["dock"]["scale"] == expected
    print("dock scale persistence and bounds passed")
