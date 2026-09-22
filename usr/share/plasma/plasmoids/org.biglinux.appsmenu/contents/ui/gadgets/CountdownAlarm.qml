/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    CountdownAlarm — the sound of a finished countdown, repeated until it is
    acknowledged.

    Deliberately *not* QtMultimedia. Importing QtMultimedia brings up the
    FFmpeg backend, which brings up Vulkan, which loads whatever implicit
    Vulkan layers the machine has installed. On a machine with vkBasalt
    enabled that combination segfaults — and inside plasmashell it takes the
    whole desktop with it, restart after restart, which is a far worse bug
    than a missing sound. A file containing nothing but a MediaPlayer
    reproduces it under bare `qml6`, and the same file survives with the
    Vulkan layers disabled, so the shell must not be the process that finds
    out whether the media stack works here.

    The sound is therefore played by a short-lived process, one per
    repetition, each exiting on its own. The loop is this item's Timer, not a
    shell loop: acknowledging stops it at the next tick, and nothing outlives
    the gadget — no `while true`, no player left running, no module that can
    bring the shell down.

    The command is a fixed string. Nothing from an event, a setting or a
    file name is interpolated into it.
*/

import QtQuick
import org.kde.plasma.plasma5support as P5Support

Item {
    id: alarm

    property bool ringing: false
    readonly property bool playing: repeat.running

    /*  The sound theme's own alarm first, then a known file for systems
        whose theme does not carry it; `||` moves on when a player or a file
        is missing, and the last one failing simply leaves the notification
        as the only signal.  */
    readonly property string command:
        "canberra-gtk-play -i alarm-clock-elapsed"
        + " || paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
        + " || pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"

    P5Support.DataSource {
        id: player
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }

    /*  Roughly the length of the sound, so the repetitions read as one
        continuous alarm. Disconnecting first lets the same command run
        again; the previous process has already exited by then.  */
    Timer {
        id: repeat
        interval: 2500
        repeat: true
        triggeredOnStart: true
        running: alarm.ringing
        onTriggered: {
            player.disconnectSource(alarm.command)
            player.connectSource(alarm.command)
        }
    }

    Component.onDestruction: player.disconnectSource(alarm.command)
}
