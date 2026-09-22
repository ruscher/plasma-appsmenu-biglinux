/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    CountdownAlarm — the sound of a finished countdown, looping until it is
    acknowledged.

    It is a MediaPlayer, not a process. The previous alarm ran
    `canberra-gtk-play || paplay || pw-play` through the executable data
    engine, which plays once and cannot be stopped, looped or cleaned up.
    A player owned by this item starts and stops with `ringing`, is stopped
    when the item is destroyed, never forks, and one instance serves however
    many countdowns end together.

    Kept in its own file because it imports QtMultimedia: the gadget loads it
    through a Loader and falls back to a single beep if the module is not
    installed, instead of failing to load altogether.
*/

import QtQuick
import QtMultimedia

Item {
    id: alarm

    property bool ringing: false
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState

    /*  The alarm sound of the system's own sound themes, tried in order; a
        theme that is missing is skipped on error rather than left silent.  */
    readonly property var candidates: [
        "file:///usr/share/sounds/ocean/stereo/alarm-clock-elapsed.oga",
        "file:///usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga",
        "file:///usr/share/sounds/Oxygen-Sys-App-Message.ogg"
    ]
    property int candidate: 0

    MediaPlayer {
        id: player
        source: alarm.candidates[Math.min(alarm.candidate, alarm.candidates.length - 1)]
        loops: MediaPlayer.Infinite
        audioOutput: AudioOutput { volume: 0.85 }
        onErrorOccurred: (error, message) => {
            if (alarm.candidate + 1 < alarm.candidates.length) {
                alarm.candidate++
                if (alarm.ringing) {
                    player.play()
                }
            }
        }
    }

    onRingingChanged: ringing ? player.play() : player.stop()
    Component.onDestruction: player.stop()
}
