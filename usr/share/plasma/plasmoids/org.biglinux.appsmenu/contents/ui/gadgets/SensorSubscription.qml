/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    SensorSubscription — the live values of a set of KSystemStats sensors,
    for as long as the gadget showing them is on screen.

    It exists because subscribing correctly is not obvious. `SensorDataModel`
    only builds its columns when the sensor list is assigned *while the model
    is enabled*: a list handed to a disabled model is remembered but never
    subscribed, and enabling it afterwards does nothing at all. A gadget
    naturally does exactly the wrong thing — the card is created off screen
    (so `enabled` is false) and the sensor list arrives a moment later, when
    discovery finishes — and then shows no values, for ever. Measured inside
    plasmashell: `enabled` true, eight ids in `sensors`, `columnCount()` 0
    twenty seconds later; re-assigning the same list turned all eight on in
    the same second. That is the bug behind "the sensors only appeared after
    I opened Configure" (opening it changes the list, which re-assigns it)
    and "they disappeared again" (scrolling the card out of view disables the
    model; scrolling back never re-subscribes).

    So the list is bound to `enabled` — assigned only while enabled, cleared
    when not — and a watchdog re-assigns it once if columns still have not
    appeared a few seconds later.

    Values survive the card leaving the screen: the last reading is kept and
    marked stale rather than dropped, so a row does not blank out and jump
    back. Only `forget()` clears them.
*/

import QtQuick 2.15
import org.kde.ksysguard.sensors as Sensors

Item {
    id: sub

    /*  The sensor ids to watch, and whether the gadget is on screen. */
    property var ids: []
    property bool active: false

    /*  id → last known numeric value. Split in two so that assigning to the
        map never overwrites a binding. */
    property var valuesData
    readonly property var values: valuesData !== undefined ? valuesData : ({})

    /*  True once at least one reading has arrived for the current ids, and
        true per id in `everRead` — a sensor that has never answered is not
        the same thing as one that reads zero. */
    property var everReadData
    readonly property var everRead: everReadData !== undefined ? everReadData : ({})
    readonly property bool hasAnyValue: Object.keys(values).length > 0
    /*  Readings are from before the card was last hidden, not from now. */
    readonly property bool stale: !active && hasAnyValue

    function valueOf(id) {
        const v = values[id]
        return v === undefined ? undefined : v
    }
    function hasValue(id) { return values[id] !== undefined }
    function wasEverRead(id) { return everRead[id] === true }
    function forget() {
        valuesData = ({})
        everReadData = ({})
    }

    readonly property bool wanted: active && ids.length > 0

    Sensors.SensorDataModel {
        id: model
        enabled: sub.wanted
        /*  The whole point: assigned only while enabled (see the note above),
            and re-assigned automatically whenever the model is enabled again. */
        sensors: enabled ? sub.ids : []
        updateRateLimit: 2000
        onDataChanged: sub.pull()
        onSensorsChanged: { watchdog.restart(); sub.pull() }
        onModelReset: sub.pull()
        onColumnsInserted: sub.pull()
    }

    /*  If the columns are still missing a few seconds after asking for them,
        ask once more. This is the documented failure above; re-assigning is
        what recovers from it. */
    Timer {
        id: watchdog
        interval: 4000
        onTriggered: {
            if (!sub.wanted || model.columnCount() > 0) {
                return
            }
            const again = sub.ids.slice()
            model.sensors = []
            model.sensors = again
        }
    }

    function pull() {
        if (!model.columnCount()) {
            return
        }
        const next = Object.assign({}, values)
        const seen = Object.assign({}, everRead)
        let changed = false
        for (let c = 0; c < model.columnCount(); c++) {
            const idx = model.index(0, c)
            const id = String(model.data(idx, Sensors.SensorDataModel.SensorId) || "")
            if (!id.length) {
                continue
            }
            const raw = model.data(idx, Sensors.SensorDataModel.Value)
            if (raw === undefined || raw === null || raw === "" || isNaN(Number(raw))) {
                continue
            }
            const v = Number(raw)
            if (next[id] !== v) {
                next[id] = v
                changed = true
            }
            if (seen[id] !== true) {
                seen[id] = true
                changed = true
            }
        }
        if (changed) {
            valuesData = next
            everReadData = seen
        }
    }

    /*  A different set of sensors means the old readings are not ours any
        more; anything still in the list keeps its value so the rows that
        stay do not flicker. */
    onIdsChanged: {
        const keep = {}, seen = {}
        for (const id of ids) {
            if (values[id] !== undefined) {
                keep[id] = values[id]
            }
            if (everRead[id] === true) {
                seen[id] = true
            }
        }
        valuesData = keep
        everReadData = seen
        watchdog.restart()
    }
}
