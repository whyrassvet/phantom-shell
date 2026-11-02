pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.config
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3secondary
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.small : Tokens.padding.extraSmall
    readonly property var font: Tokens.font.body.builders.small.scale(1.15)
    readonly property string timeText: Config.bar.clock.showSeconds ? Time.format("HH:mm:ss") : Time.format("HH:mm")

    implicitHeight: BarConfig.innerThickness
    implicitWidth: layout.implicitWidth + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: height / 2

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        Loader {
            asynchronous: true
            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
                fontStyle: Tokens.font.icon.small
            }
        }

        Loader {
            asynchronous: true
            active: Config.bar.clock.showDate
            visible: active

            sourceComponent: StyledText {
                text: Time.format("ddd d")
                font: Tokens.font.body.builders.small.scale(0.9).build()
                color: root.colour
            }
        }

        StyledText {
            text: root.timeText
            font: root.font.build()
            color: root.colour
        }

        Loader {
            asynchronous: true
            active: Units.twelveHourClock
            visible: active

            sourceComponent: StyledText {
                text: Time.amPmStr.toLowerCase()
                font: Tokens.font.body.builders.small.scale(0.9).build()
                color: root.colour
            }
        }
    }
}
