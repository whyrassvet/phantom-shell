import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.config
import qs.services
import qs.utils

Item {
    id: root

    readonly property int iconSize: Math.round(BarConfig.innerThickness * 0.65)

    implicitWidth: BarConfig.innerThickness
    implicitHeight: BarConfig.innerThickness

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(BarConfig.launcherCommand.split(" "))
    }

    Loader {
        asynchronous: true
        anchors.centerIn: parent
        sourceComponent: SysInfo.isDefaultLogo ? caelestiaLogo : distroIcon
    }

    Component {
        id: caelestiaLogo

        Logo {
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize
        }
    }

    Component {
        id: distroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: root.iconSize
            colour: Colours.palette.m3tertiary
        }
    }
}
