// Slim wrapper: the real Caelestia one pulls in nexus and windowinfo.
// Kept API-compatible with the bar; detached mode is disabled.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property real offsetScale

    readonly property alias content: content
    readonly property real nonAnimWidth: content.implicitWidth
    readonly property real nonAnimHeight: content.implicitHeight
    property real lastWidth: 0
    property real lastHeight: 0
    readonly property Item current: (content.item as Content)?.current ?? null
    readonly property bool isDetached: false

    property alias currentName: popoutState.currentName
    property alias hasCurrent: popoutState.hasCurrent
    property real currentCenter

    property string detachedMode
    property string queuedMode

    // Dummy object so Tokens attached prop resolves to global config
    // Anim configs are not per-monitor
    readonly property QtObject dummy: QtObject {}
    property int animLength: dummy.Tokens.anim.durations.expressiveDefaultSpatial
    property var animCurve: dummy.Tokens.anim.expressiveDefaultSpatial // The easingCurve type is Qt 6.11+ so we gotta use var for now

    function detach(mode: string): void {
        // Detached nexus/windowinfo panels are not ported.
        close();
    }

    function close(): void {
        hasCurrent = false;
        detachedMode = "";
    }

    onNonAnimWidthChanged: {
        if (hasCurrent && nonAnimWidth > 0)
            lastWidth = nonAnimWidth;
    }
    onNonAnimHeightChanged: {
        if (hasCurrent && nonAnimHeight > 0)
            lastHeight = nonAnimHeight;
    }

    implicitWidth: hasCurrent && nonAnimWidth > 0 ? nonAnimWidth : lastWidth
    implicitHeight: hasCurrent && nonAnimHeight > 0 ? nonAnimHeight : lastHeight

    focus: hasCurrent
    Keys.onEscapePressed: close()

    PopoutState {
        id: popoutState

        onDetachRequested: mode => root.detach(mode)
    }

    // Keyboard focus for the password popout is handled by the window in shell.qml.

    Comp {
        id: content

        shouldBeActive: root.hasCurrent && !root.detachedMode
        anchors.fill: parent

        sourceComponent: Content {
            popouts: popoutState
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: root.animLength
            easing: root.animCurve
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: root.animLength
            easing: root.animCurve
        }
    }

    component Comp: Loader {
        id: comp

        property bool shouldBeActive

        active: false
        opacity: 0

        // Makes the loader load on the same frame shouldBeActive becomes true, which ensures size is set
        states: State {
            name: "active"
            when: comp.shouldBeActive

            PropertyChanges {
                comp.opacity: 1
                comp.active: true
            }
        }

        transitions: [
            Transition {
                from: ""
                to: "active"

                SequentialAnimation {
                    PropertyAction {
                        property: "active"
                    }
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                    }
                }
            },
            Transition {
                from: "active"
                to: ""

                SequentialAnimation {
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                    }
                    PropertyAction {
                        property: "active"
                    }
                }
            }
        ]
    }
}
