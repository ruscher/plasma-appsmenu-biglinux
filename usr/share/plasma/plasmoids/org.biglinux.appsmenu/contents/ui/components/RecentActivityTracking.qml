/*
    SPDX-FileCopyrightText: 2024 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later

    RecentActivityTracking — reads, and can turn on, the KDE activity history
    ("Recent Files & Locations") that feeds every Kicker RecentUsageModel:
    recent apps, recent files, recent folders and frequently used items.

    All of the knowledge about *what* makes the feature work lives in one
    place, contents/tools/recent-activity, which biglinux-settings ships a
    byte-identical copy of.  That is deliberate: before this, the menu and the
    settings switch each had their own idea of "enabled" and disagreed, so the
    menu hid its call to action while the history stayed empty.

    The short version of what the helper checks (details in its header and in
    docs/recent-files-02-root-cause.md):

        what-to-remember == 2                     → nothing is recorded
        off-the-record-activities ∋ current one   → nothing is recorded
        kdeglobals RecentDocuments/UseRecent      → XDG recent documents

    The second one is what used to be missed.  Note that the "enabled" key in
    kactivitymanagerd-pluginsrc does NOT gate anything on Plasma 6 — the
    daemon loads every plugin unconditionally — so it can never be used on its
    own to decide whether the feature works.

    Do NOT probe this over D-Bus with org.kde.ActivityManager.Features:
    IsFeatureOperational() makes kactivitymanagerd exit when it is passed a
    plugin name (reproduced on 6.7.4), and for the scoring plugin it returns
    false even while recording works. Reading the configuration is both safe
    and authoritative.
*/

import QtQuick 2.15
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: root

    visible: false

    /* Path to the canonical helper, resolved from this file so it keeps
       working wherever the plasmoid is installed. */
    readonly property string helper: {
        const url = Qt.resolvedUrl("../../tools/recent-activity")
        return url.toString().replace(/^file:\/\//, "")
    }

    /* "unknown" until the first probe answers, so the call to action never
       flashes on a working system.
       "on"      — everything the models need is in place
       "limited" — recording, but only for specific applications
       "off"     — positively disabled; show the call to action
       "error"   — the last enable() attempt failed; let the user retry */
    property string trackingState: "unknown"

    /* Why it is not "on": ok | do-not-remember | off-the-record |
       plugin-disabled | specific-applications | daemon-unreachable */
    property string reason: "ok"

    /* XDG recent documents (Dolphin's recent files, file dialogs). */
    property bool documents: true

    /* true while enabling. */
    property bool busy: false

    signal refreshed()

    function refresh() {
        probe.connectSource("bash " + shellQuote(root.helper) + " status")
    }

    function enable() {
        if (root.busy) {
            return
        }
        root.busy = true
        /* The helper re-reads and verifies the state itself and exits
           non-zero if the change did not take, so a zero exit really does
           mean the feature is on. */
        writer.connectSource("bash " + shellQuote(root.helper) + " enable")
    }

    /* Open System Settings for what enable() deliberately does not touch:
       per-application exclusions, how long to keep the history, clearing it. */
    function openSettings() {
        launcher.connectSource("kcmshell6 kcm_recentFiles")
    }

    function shellQuote(path) {
        return "'" + String(path).replace(/'/g, "'\\''") + "'"
    }

    function applyStatus(text) {
        const values = {}
        const lines = String(text).split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const sep = lines[i].indexOf("=")
            if (sep > 0) {
                values[lines[i].substring(0, sep)] = lines[i].substring(sep + 1).trim()
            }
        }

        if (values["tracking"] === undefined) {
            /* The helper is missing or unreadable. Assume the history works
               rather than nagging about something we cannot verify. */
            root.trackingState = "unknown"
            root.reason = "probe-failed"
            root.refreshed()
            return
        }

        root.documents = values["documents"] !== "off"
        root.reason = values["reason"] || "ok"

        switch (values["tracking"]) {
        case "on":
            /* Tracking works, but the feature is only fully on when the XDG
               recent documents list is on too. */
            root.trackingState = root.documents ? "on" : "off"
            if (!root.documents) {
                root.reason = "recent-documents-off"
            }
            break
        case "limited":
            root.trackingState = root.documents ? "limited" : "off"
            break
        case "off":
            root.trackingState = "off"
            break
        default:
            root.trackingState = "unknown"
            break
        }

        root.refreshed()
    }

    Plasma5Support.DataSource {
        id: probe
        engine: "executable"
        connectedSources: []

        onNewData: (source, data) => {
            disconnectSource(source)
            root.applyStatus(data["stdout"] || "")
        }
    }

    Plasma5Support.DataSource {
        id: writer
        engine: "executable"
        connectedSources: []

        onNewData: (source, data) => {
            disconnectSource(source)
            root.busy = false

            if (data["exit code"] !== 0) {
                /* Never claim success because a command ran. Keep the call to
                   action on screen so the user can retry or open the KCM. */
                root.trackingState = "error"
                root.reason = "enable-failed"
                root.refreshed()
                return
            }

            /* enable prints the verified state it ended up in. */
            root.applyStatus(data["stdout"] || "")
        }
    }

    Plasma5Support.DataSource {
        id: launcher
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }

    Component.onCompleted: root.refresh()
}
