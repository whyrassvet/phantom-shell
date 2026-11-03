pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property PopoutState popouts
    property bool mixerExpanded: false
    readonly property var playbackStreams: Audio.streams.filter(stream => stream.properties["media.class"] === "Stream/Output/Audio")

    implicitWidth: Tokens.sizes.bar.audioWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    ButtonGroup {
        id: sinks
    }

    ButtonGroup {
        id: sources
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.medium

        StyledText {
            text: Tr.trCtx("Output device", "audio output device")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        Repeater {
            model: Audio.sinks

            StyledRadioButton {
                id: control

                required property PwNode modelData

                Layout.fillWidth: true
                ButtonGroup.group: sinks
                checked: Audio.sink?.id === modelData.id
                onClicked: Audio.setAudioSink(modelData)
                text: modelData.description
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: Tr.trCtx("Input device", "audio input device")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        Repeater {
            model: Audio.sources

            StyledRadioButton {
                required property PwNode modelData

                Layout.fillWidth: true
                ButtonGroup.group: sources
                checked: Audio.source?.id === modelData.id
                onClicked: Audio.setAudioSource(modelData)
                text: modelData.description
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: Audio.muted ? Tr.tr("Volume (muted)") : Tr.tr("Volume (%1%)").arg(Math.round(Audio.volume * 100))
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        CustomMouseArea {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.medium * 3

            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
            }

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: parent.implicitHeight

                value: Audio.volume
                onInteraction: value => Audio.setVolume(value)
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            isToggle: true
            checked: root.mixerExpanded
            verticalPadding: Tokens.padding.extraSmall
            text: Tr.tr("Application volume")
            icon: root.mixerExpanded ? "expand_less" : "expand_more"

            onClicked: root.mixerExpanded = !root.mixerExpanded
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.mixerExpanded && root.playbackStreams.length === 0
            text: Tr.tr("No active applications")
            font: Tokens.font.body.small
        }

        ListView {
            id: streamList

            Layout.fillWidth: true
            visible: root.mixerExpanded && count > 0
            implicitHeight: Math.min(contentHeight, 240)
            clip: true
            spacing: Tokens.spacing.medium
            model: root.playbackStreams
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: streamList.contentHeight > streamList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

            delegate: ColumnLayout {
                id: streamRow

                required property PwNode modelData
                width: streamList.width
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Audio.getStreamName(streamRow.modelData) + " (" + Math.round((streamRow.modelData.audio?.volume ?? 0) * 100) + "%)"
                    font: Tokens.font.body.small
                }

                StyledSlider {
                    Layout.fillWidth: true
                    implicitHeight: Tokens.padding.medium * 3
                    value: streamRow.modelData.audio?.volume ?? 0
                    onInteraction: value => Audio.setStreamVolume(streamRow.modelData, value)
                }
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            inactiveColour: Colours.palette.m3primaryContainer
            inactiveOnColour: Colours.palette.m3onPrimaryContainer
            verticalPadding: Tokens.padding.extraSmall
            text: Tr.tr("Open settings")
            icon: "settings"

            onClicked: root.popouts.detachRequested("audio")
        }
    }
}
