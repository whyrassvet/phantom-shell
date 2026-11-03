#!/usr/bin/env python3
"""Exercise the audio popout in an isolated headless compositor.

The second run uses mock streams; it does not test PipeWire itself.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(os.environ["PHANTOM_TEST_STAGE"]).resolve()

with tempfile.TemporaryDirectory(prefix="phantom-audio-", dir="/tmp/opencode") as tmp:
    scratch = Path(tmp)
    bar = scratch / "bar"
    shutil.copytree(ROOT / "quickshell/caelestia-bar", bar)
    wrapper = bar / "modules/bar/popouts/Wrapper.qml"
    wrapper.write_text(wrapper.read_text().replace('shouldBeActive: root.hasCurrent && !root.detachedMode', 'shouldBeActive: true'))
    audio = bar / "modules/bar/popouts/AudioPopout.qml"
    original = audio.read_text()
    for mock in (False, True):
        text = original
        text = text.replace('text: Tr.tr("No active applications")', 'objectName: "emptyProbe"\n            text: Tr.tr("No active applications")')
        text = text.replace('text: Tr.tr("Application volume")', 'objectName: "mixerButtonProbe"\n            text: Tr.tr("Application volume")')
        if mock:
            text = text.replace('readonly property var playbackStreams: Audio.streams.filter(stream => stream.properties["media.class"] === "Stream/Output/Audio")',
                                'property var playbackStreams: []')
            text = text.replace('required property PwNode modelData\n                width: streamList.width',
                                'required property var modelData\n                width: streamList.width')
            text = text.replace('Audio.getStreamName(streamRow.modelData)', 'streamRow.modelData.name')
            text = text.replace('Audio.setStreamVolume(streamRow.modelData, value)', 'streamRow.modelData.audio.volume = value')
        marker = '    ButtonGroup {\n        id: sinks'
        assert text.count(marker) == 1
        instrumentation = '''    Timer {
        property int step: 0
        property real before: 0
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            if (step === 0) {
                before = root.implicitHeight;
                layout.children.find(c => c.objectName === "mixerButtonProbe").clicked();
            } else if (step === 1) {
                console.log("AUDIO_EMPTY", streamList.count === 0, root.implicitHeight > before, before, root.implicitHeight, root.visible, layout.implicitHeight, root.mixerExpanded, layout.children.find(c => c.objectName === "emptyProbe").visible);
                %s
            } %s
            step++;
        }
    }
''' % ('''root.playbackStreams = Array.from({length: 8}, (_, i) => Qt.createQmlObject('import QtQuick; QtObject { property string name: "App"; property QtObject audio: QtObject { property real volume: 0.5 } }', root));''' if mock else 'console.log("AUDIO_REAL_LOADED", true); running = false;',
       '''else if (step === 2) {
                    const row = streamList.itemAtIndex(0);
                    const slider = row.children.find(child => child.interaction !== undefined);
                    slider.interaction(0.3);
                    console.log("AUDIO_MOCK", streamList.count === 8, streamList.height === 240,
                        Math.abs(root.playbackStreams[0].audio.volume - 0.3) < 0.001, slider.height === 10);
                    layout.children.find(c => c.objectName === "mixerButtonProbe").clicked();
                } else if (step === 3) {
                    console.log("AUDIO_COLLAPSED", !streamList.visible, root.implicitHeight === before);
                    running = false;
                }''' if mock else '')
        audio.write_text(text.replace(marker, instrumentation + marker))
        content = bar / "modules/bar/popouts/Content.qml"
        content_text = content.read_text()
        if 'id: audioProbe' not in content_text:
            content_text = content_text.replace('root.popouts.currentName === name', 'root.popouts.currentName === name || objectName === "geometryProbe"')
            content.write_text(content_text.replace('    Item {\n        id: content', '''    Window {
        visible: true
        width: 400
        height: 800
        AudioPopout {
            id: audioProbe
            width: implicitWidth
            height: implicitHeight
            popouts: root.popouts
        }
        Item {
            id: geometryHost
            x: 300
            width: 100
            height: targetHeight
            property real targetHeight: 100
            property real childHeight: 100
            Behavior on height { NumberAnimation { duration: 1000 } }

            Popout {
                id: geometryPopout
                objectName: "geometryProbe"
                name: "audio"
                sourceComponent: Item {
                    implicitWidth: 100
                    implicitHeight: geometryHost.childHeight
                }
            }
            Popout {
                id: otherPopout
                objectName: "geometryProbe"
                name: "other"
                sourceComponent: Item { implicitWidth: 100; implicitHeight: 100 }
            }
            Timer {
                property int step: 0
                interval: 300
                running: true
                repeat: true
                onTriggered: {
                    if (step === 1) {
                        geometryHost.targetHeight = 300;
                        geometryHost.childHeight = 300;
                    } else if (step === 2) {
                        console.log("AUDIO_TOP_FIXED", geometryPopout.active,
                            geometryPopout.y === 0, geometryHost.height > 100 && geometryHost.height < 300,
                            Math.abs(otherPopout.y - (geometryHost.height - otherPopout.height) / 2) <= 0.51);
                        running = false;
                    }
                    step++;
                }
            }
        }
    }

    Item {
        id: content'''))
        for name in ("home", "runtime", "config", "cache", "state", "data"):
            (scratch / name).mkdir(exist_ok=True)
        (scratch / "runtime").chmod(0o700)
        args = ["bwrap", "--ro-bind", "/", "/", "--bind", str(scratch), str(scratch),
                "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
        for path in ("/run/dbus", "/usr/lib/qt6/qml/Caelestia", "/etc/xdg/quickshell/caelestia"):
            if Path(path).is_dir():
                args += ["--tmpfs", path]
        env = {"HOME": scratch / "home", "XDG_CONFIG_HOME": scratch / "config",
               "XDG_CACHE_HOME": scratch / "cache", "XDG_STATE_HOME": scratch / "state",
               "XDG_DATA_HOME": scratch / "data", "XDG_RUNTIME_DIR": scratch / "runtime",
               "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman", "WLR_LIBINPUT_NO_DEVICES": "1",
               "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software",
               "PHANTOM_BAR_CONFIG": bar, "PHANTOM_QML_ROOT": STAGE / "lib/qt6/qml"}
        for key, value in env.items():
            args += ["--setenv", key, str(value)]
        for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE", "LD_PRELOAD", "LD_LIBRARY_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
            args += ["--unsetenv", key]
        args += ["cage", "--", str(ROOT / "bin/phantom-bar")]
        log = scratch / "log"
        with log.open("w") as output:
            proc = subprocess.Popen(args, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                expected = ["AUDIO_EMPTY true true", "AUDIO_MOCK true true true true", "AUDIO_COLLAPSED true true", "AUDIO_TOP_FIXED true true true true"] if mock else ["AUDIO_EMPTY true true", "AUDIO_REAL_LOADED true", "AUDIO_TOP_FIXED true true true true"]
                deadline = time.monotonic() + 12
                while time.monotonic() < deadline and proc.poll() is None:
                    result = log.read_text(errors="replace")
                    if all(item in result for item in expected):
                        break
                    time.sleep(0.1)
                result = log.read_text(errors="replace")
                assert all(item in result for item in expected), result
                for error in ("ReferenceError", "TypeError", "Failed to load configuration", "is not a type"):
                    assert error not in result, result
            finally:
                os.killpg(proc.pid, 15)
                proc.wait(timeout=10)
    print("Audio popout: real component and mock-stream layout passed; PipeWire not tested")
