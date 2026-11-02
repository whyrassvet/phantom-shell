pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.config
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)
    readonly property int thickness: BarConfig.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || screenState.bar || isHovered)
    readonly property int exclusiveZone: shouldBeVisible ? thickness : 0

    property bool isHovered

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(x: real): void {
        (content.item as Bar)?.checkPopout(x);
    }

    function handleWheel(x: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(x, angleDelta);
    }

    clip: true
    implicitHeight: thickness
    visible: shouldBeVisible

    Loader {
        id: content

        anchors.fill: parent
        active: root.shouldBeVisible

        sourceComponent: Bar {
            width: root.width
            height: root.thickness
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }
}
