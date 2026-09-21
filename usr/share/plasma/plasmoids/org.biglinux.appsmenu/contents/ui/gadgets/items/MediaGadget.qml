/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Media Player gadget — now playing + controls via MPRIS (any player).
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.mpris as Mpris
import ".." as G

Item {
    id: media
    required property var host

    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string track: hasPlayer ? (player.track || "") : ""
    readonly property string artist: hasPlayer ? (player.artist || "") : ""
    readonly property real length: hasPlayer && player.length ? player.length : 0     // microseconds
    readonly property real position: hasPlayer && player.position ? player.position : 0
    readonly property string artUrl: hasPlayer ? (player.artUrl || "") : ""

    Component.onCompleted: host.accentColor = "#ec4899"
    Binding { target: media.host; property: "subtitle"; value: media.hasPlayer ? (media.player.identity || "") : "" }

    // Keep the position fresh while playing (MPRIS only pushes changes on seek)
    Timer {
        interval: 1000
        running: media.host.active && media.playing
        repeat: true
        onTriggered: if (media.hasPlayer && media.player.updatePosition) media.player.updatePosition()
    }
    function fmt(us) {
        const s = Math.max(0, Math.floor(us / 1000000))
        const m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // ── playing ──
    RowLayout {
        anchors.fill: parent
        visible: media.hasPlayer
        spacing: Kirigami.Units.largeSpacing

        // Album art with soft glow
        Item {
            Layout.preferredWidth: media.host.wide ? Math.min(parent.height, Kirigami.Units.gridUnit * 6) : parent.width * 0.38
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignVCenter
            G.RoundedImage {
                id: art
                anchors.fill: parent
                source: media.artUrl
                radius: Kirigami.Units.largeSpacing
                fallbackIcon: "multimedia-player"
                // slow "vinyl" breathing while playing
                scale: media.playing ? 1.0 : 0.96
                Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            PC3.Label {
                text: media.track.length ? media.track : i18n("Unknown title")
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: media.host.compact ? 2 : 1
                wrapMode: media.host.compact ? Text.Wrap : Text.NoWrap
                Layout.fillWidth: true
            }
            PC3.Label {
                text: media.artist
                opacity: 0.7
                elide: Text.ElideRight
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
                visible: text.length > 0
            }

            // Progress
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                visible: media.length > 0
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                    Rectangle {
                        width: parent.width * (media.length > 0 ? Math.min(1, media.position / media.length) : 0)
                        height: parent.height
                        radius: 2
                        color: media.host.accent
                        Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: media.hasPlayer && media.player.canSeek
                        onClicked: mouse => {
                            const frac = Math.max(0, Math.min(1, (mouse.x - 6) / parent.width))
                            if (media.player.Seek) media.player.Seek((frac * media.length) - media.position)
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    PC3.Label { text: media.fmt(media.position); font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9; opacity: 0.6 }
                    Item { Layout.fillWidth: true }
                    PC3.Label { text: media.fmt(media.length); font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9; opacity: 0.6 }
                }
            }

            // Controls
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing
                PC3.ToolButton {
                    icon.name: "media-skip-backward"
                    enabled: media.hasPlayer && media.player.canGoPrevious
                    onClicked: media.player.Previous()
                    Accessible.name: i18n("Previous track")
                }
                PC3.ToolButton {
                    id: playBtn
                    icon.name: media.playing ? "media-playback-pause" : "media-playback-start"
                    icon.width: Kirigami.Units.iconSizes.medium
                    icon.height: Kirigami.Units.iconSizes.medium
                    enabled: media.hasPlayer && (media.player.canPlay || media.player.canPause)
                    onClicked: media.player.PlayPause()
                    Accessible.name: media.playing ? i18n("Pause") : i18n("Play")
                    background: Rectangle {
                        radius: width / 2
                        color: Qt.rgba(media.host.accent.r, media.host.accent.g, media.host.accent.b, playBtn.hovered ? 0.35 : 0.22)
                        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                    }
                }
                PC3.ToolButton {
                    icon.name: "media-skip-forward"
                    enabled: media.hasPlayer && media.player.canGoNext
                    onClicked: media.player.Next()
                    Accessible.name: i18n("Next track")
                }
                PC3.ToolButton {
                    visible: !media.host.compact
                    icon.name: "window-new"
                    enabled: media.hasPlayer && media.player.canRaise
                    onClicked: media.player.Raise()
                    Accessible.name: i18n("Show player")
                    PC3.ToolTip.text: i18n("Show player"); PC3.ToolTip.visible: hovered
                }
            }
        }
    }

    // ── nothing playing ──
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        visible: !media.hasPlayer
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            source: "multimedia-player"
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.45
        }
        PC3.Label {
            text: i18n("Nothing playing")
            opacity: 0.7
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        PC3.Label {
            text: i18n("Play something in any media player and control it here.")
            opacity: 0.5
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            visible: !media.host.compact
        }
    }
}
