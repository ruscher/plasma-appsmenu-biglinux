/*
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later

    RecentActivityTracking — reads, and can turn on, the KDE activity history
    ("Recent Files" in System Settings, kcm_recentFiles) that feeds every
    Kicker RecentUsageModel: recent apps, recent files, recent folders and
    frequently used items.

    The setting lives in kactivitymanagerd-pluginsrc, group
    "Plugin-org.kde.ActivityManager.Resources.Scoring":

        enabled=false        → the scoring plugin is never loaded
        what-to-remember=2   → "Do not remember" in System Settings
        what-to-remember=1   → only the listed applications (still tracking)
        what-to-remember=0   → all applications (the default)

    Either of the first two leaves the recent models permanently empty, which
    is what `tracking` reports. kactivitymanagerd reads these keys when it
    starts, so turning them on means restarting the daemon.

    Do NOT probe this over D-Bus with org.kde.ActivityManager.Features:
    IsFeatureOperational() makes kactivitymanagerd exit when the plugin is not
    loaded — precisely the state we need to detect. Reading the config file is
    both safe and authoritative.
*/

import QtQuick 2.15
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: root

    visible: false

    /* false only after positively reading a disabled setting; assume the
       history works until proven otherwise, so the call to action never
       flashes on a working system. */
    property bool tracking: true

    /* true while enabling: the daemon restart takes a moment. */
    property bool busy: false

    /* what-to-remember as last read, so enable() only overrides the value
       when it actually says "do not remember". */
    property int whatToRemember: 0

    readonly property string configFile: "kactivitymanagerd-pluginsrc"
    readonly property string configGroup: "Plugin-org.kde.ActivityManager.Resources.Scoring"

    signal refreshed()

    function refresh() {
        probe.connectSource(
            "kreadconfig6 --file " + root.configFile + " --group '" + root.configGroup + "' --key enabled --default true"
            + "; kreadconfig6 --file " + root.configFile + " --group '" + root.configGroup + "' --key what-to-remember --default 0")
    }

    function enable() {
        if (root.busy) {
            return
        }
        root.busy = true

        let cmd = "kwriteconfig6 --file " + root.configFile + " --group '" + root.configGroup + "' --key enabled true"
        if (root.whatToRemember === 2) {
            cmd += "; kwriteconfig6 --file " + root.configFile + " --group '" + root.configGroup + "' --key what-to-remember 0"
        }
        /* The daemon caches the plugin list at startup. Prefer the systemd
           user unit; fall back to quitting it and letting D-Bus activation
           bring it back (org.kde.ActivityManager is activatable). */
        cmd += "; systemctl --user restart plasma-kactivitymanagerd.service 2>/dev/null"
            + " || { kquitapp6 kactivitymanagerd 2>/dev/null; sleep 1;"
            + " dbus-send --session --dest=org.kde.ActivityManager --type=method_call"
            + " /ActivityManager/Activities org.freedesktop.DBus.Peer.Ping 2>/dev/null; }"

        writer.connectSource(cmd)
    }

    /* Open System Settings for the cases enable() cannot cover: per
       application exclusions, how long to keep the history, clearing it. */
    function openSettings() {
        writer.connectSource("kcmshell6 kcm_recentFiles")
    }

    Plasma5Support.DataSource {
        id: probe
        engine: "executable"
        connectedSources: []

        onNewData: (source, data) => {
            disconnectSource(source)

            const lines = String(data["stdout"] || "").split("\n")
            const enabled = lines[0].trim().toLowerCase() !== "false"
            const remember = parseInt(lines[1], 10)

            root.whatToRemember = isNaN(remember) ? 0 : remember
            root.tracking = enabled && root.whatToRemember !== 2
            root.refreshed()
        }
    }

    Plasma5Support.DataSource {
        id: writer
        engine: "executable"
        connectedSources: []

        onNewData: source => {
            disconnectSource(source)
            /* Give the restarted daemon a moment before reading back. */
            settleTimer.restart()
        }
    }

    Timer {
        id: settleTimer
        interval: 1500
        onTriggered: {
            root.busy = false
            root.refresh()
        }
    }

    Component.onCompleted: root.refresh()
}
