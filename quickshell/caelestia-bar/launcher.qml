// Standalone adaptation of Caelestia Shell v2.5.0's application launcher.
// See LAUNCHER-SOURCE.md and LICENSE.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.items
import qs.modules.launcher.services

ShellRoot {
    id: root

    FontLoader {
        source: Quickshell.shellPath("assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf")
    }

    QtObject {
        id: launcherState
        property bool launcher: false
        onLauncherChanged: {
            if (launcher) {
                window.screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null;
                Qt.callLater(() => search.forceActiveFocus());
            } else {
                search.text = "";
            }
        }
    }

    IpcHandler {
        target: "phantomLauncher"
        function ping(): string { return "ready"; }
        function open(): void { launcherState.launcher = true; }
        function close(): void { launcherState.launcher = false; }
        function isOpen(): bool { return launcherState.launcher; }
    }

    PanelWindow {
        id: window

        visible: launcherState.launcher
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null
        implicitWidth: Math.min(630, screen?.width ?? 630)
        implicitHeight: Math.min(580, screen?.height ?? 580)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "phantom-app-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            radius: Tokens.rounding.extraLarge
            color: Effects.flat ? Colours.palette.m3surface : Colours.tPalette.m3surface

            Column {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.padding.large

                ListView {
                    id: list
                    width: parent.width
                    height: Math.max(0, parent.height - search.height - parent.spacing)
                    clip: true
                    spacing: Tokens.spacing.small
                    currentIndex: count ? 0 : -1
                    model: ScriptModel {
                        values: Apps.search(search.text)
                        onValuesChanged: list.currentIndex = list.count ? 0 : -1
                    }
                    highlight: Rectangle {
                        radius: Tokens.rounding.large
                        color: Colours.palette.m3onSurface
                        opacity: 0.08
                    }
                    delegate: AppItem { screenState: launcherState }
                }

                SearchBar {
                    id: search
                    width: parent.width
                    placeholderText: "Search applications"
                    onAccepted: {
                        if (list.currentItem) {
                            Apps.launch(list.currentItem.modelData);
                            launcherState.launcher = false;
                        }
                    }
                    Keys.onUpPressed: list.decrementCurrentIndex()
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onEscapePressed: launcherState.launcher = false
                }
            }
        }
    }
}
