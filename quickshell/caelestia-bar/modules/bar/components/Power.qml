import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.config
import qs.services

Item {
    id: root

    required property ScreenState screenState

    readonly property int buttonSize: Math.round(BarConfig.innerThickness * 0.85)

    implicitWidth: buttonSize
    implicitHeight: BarConfig.innerThickness

    StateLayer {
        anchors.centerIn: parent
        implicitWidth: root.buttonSize
        implicitHeight: root.buttonSize
        radius: Tokens.rounding.full
        onClicked: {
            if (BarConfig.powerCommand) {
                Quickshell.execDetached(["sh", "-c", BarConfig.powerCommand]);
                return;
            }
            root.screenState.session = !root.screenState.session;
        }
    }

    MaterialIcon {
        id: icon
        objectName: "powerIcon"

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: BarConfig.style === "islands" ? -1 : 0

        text: "power_settings_new"
        color: Colours.palette.m3error
        fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()
    }
}
