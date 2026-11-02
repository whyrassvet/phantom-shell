import QtQuick
import Caelestia.Config
import qs.components
import qs.config
import qs.services

Item {
    id: root

    implicitWidth: clockText.implicitWidth
    implicitHeight: BarConfig.innerThickness

    StyledText {
        id: clockText

        anchors.centerIn: parent
        text: Time.format("HH:mm")
        color: Colours.palette.m3secondary
        font: Tokens.font.body.builders.small.scale(1.15).weight(Font.Bold).build()
    }
}
