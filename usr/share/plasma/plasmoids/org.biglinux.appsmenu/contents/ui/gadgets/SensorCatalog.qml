/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    SensorCatalog — which temperature and fan sensors this machine has,
    found once and shared by every gadget that shows them.

    Everything comes from KSystemStats, the daemon Plasma's own System
    Monitor uses: it already reads hwmon, libsensors and the GPU drivers,
    localises the names, and reports the hardware's critical limit as each
    sensor's Maximum. There is no /sys walking and no `sensors` process.

    What decides that a sensor is a temperature or a fan is its **unit**
    (KSysGuard's enum: 1000 °C, 1004 RPM) and nothing else. An earlier
    version narrowed the candidates by matching names like "temp" or "fan"
    first, which is a guess about how drivers happen to name things: a fan
    whose id spells neither would simply not exist as far as the gadget was
    concerned. Every real sensor is asked for its unit instead.

    Two rules this catalogue follows, both learned from the previous one:

    * **A sensor is not dropped for having no reading at that instant.**
      Existence comes from the unit; whether a value has arrived is the
      gadget's business and changes minute to minute. Dropping on a
      momentary blank is what made sensors vanish and never come back, since
      classification ran once and its verdict was permanent.
    * **An empty result is never published as "ready".** If the tree is not
      up yet (the daemon may still be starting), discovery is retried with a
      growing delay instead of declaring the machine sensorless, and the
      previous catalogue is kept meanwhile.

    Discovery repeats when the tree changes (a card powering up, an external
    enclosure), debounced, so hardware that appears or disappears is picked
    up without a restart.
*/

pragma Singleton

import QtQuick 2.15
import org.kde.ksysguard.sensors as Sensors

QtObject {
    id: catalog

    /*  False until a discovery has actually produced a verdict. */
    property bool ready: false
    /*  [{ id, name, shortName, group, groupId, category, max }] */
    property var temperatures: []
    property var fans: []
    /*  gpu/gpuN → its marketing name, so GPU groups read "Radeon RX …". */
    property var gpuNames: ({})

    readonly property int unitCelsius: 1000
    readonly property int unitRpm: 1004

    /*  Ids in the tree are sometimes patterns rather than sensors —
        `disk/(?!all).*​/free`, `gpu/gpu\d+/name`. They carry regular
        expression syntax, which no real sensor id does. */
    readonly property var templatePattern: /[\\()\[\]|*?^$]/

    readonly property var tree: Sensors.SensorTreeModel {
        onRowsInserted: catalog.rediscover.restart()
        onRowsRemoved: catalog.rediscover.restart()
        onModelReset: catalog.rediscover.restart()
    }

    /*  Subscribed to every candidate only for as long as it takes to read
        their metadata, then emptied again. */
    readonly property var probe: Sensors.SensorDataModel {
        enabled: false
        updateRateLimit: 2000
    }

    readonly property var rediscover: Timer {
        interval: 1500
        onTriggered: catalog.scan()
    }
    readonly property var kick: Timer {
        interval: 600
        running: true
        onTriggered: catalog.scan()
    }
    /*  Retry when the tree is not up yet: 1s, 2s, 4s, 8s, then every 15s.
        Bounded work, no spinning. */
    property int emptyTries: 0
    readonly property var retry: Timer {
        onTriggered: catalog.scan()
    }
    function scheduleRetry() {
        emptyTries++
        retry.interval = Math.min(15000, 1000 * Math.pow(2, Math.min(3, emptyTries - 1)))
        retry.restart()
    }

    function walk(parent, out, depth) {
        if (depth > 8) {
            return
        }
        for (let i = 0; i < tree.rowCount(parent); i++) {
            const idx = tree.index(i, 0, parent)
            if (tree.canFetchMore(idx)) {
                tree.fetchMore(idx)
            }
            const id = String(tree.data(idx, Sensors.SensorTreeModel.SensorId) || "")
            if (id.length && !templatePattern.test(id)) {
                out.push(id)
            }
            if (tree.rowCount(idx) > 0) {
                walk(idx, out, depth + 1)
            }
        }
    }

    function scan() {
        const ids = []
        try {
            walk(tree.index(-1, -1), ids, 0)
        } catch (e) {
            scheduleRetry()
            return
        }
        if (!ids.length) {
            /*  The daemon is not answering yet. Keep whatever is already on
                screen and ask again shortly. */
            scheduleRetry()
            return
        }
        emptyTries = 0
        probe.sensors = ids
        probe.enabled = true
        stableFor = 0
        lastUnitCount = -1
        settle.restart()
    }

    /*  Metadata arrives asynchronously. Rather than classifying after a
        fixed wait and hoping, the probe is watched until the number of
        sensors reporting a unit stops growing — two quiet rounds, or five
        seconds, whichever comes first. */
    property int stableFor: 0
    property int lastUnitCount: -1
    readonly property int settleStep: 300
    property int settleWaited: 0
    readonly property var settle: Timer {
        interval: 300
        repeat: true
        onTriggered: {
            catalog.settleWaited += catalog.settleStep
            let withUnit = 0
            for (let c = 0; c < catalog.probe.columnCount(); c++) {
                const u = Number(catalog.probe.data(catalog.probe.index(0, c), Sensors.SensorDataModel.Unit))
                if (!isNaN(u) && u > 0) {
                    withUnit++
                }
            }
            if (withUnit > 0 && withUnit === catalog.lastUnitCount) {
                catalog.stableFor++
            } else {
                catalog.stableFor = 0
            }
            catalog.lastUnitCount = withUnit
            if ((withUnit > 0 && catalog.stableFor >= 2) || catalog.settleWaited >= 5000) {
                stop()
                catalog.settleWaited = 0
                catalog.classify()
            }
        }
        onRunningChanged: if (running) catalog.settleWaited = 0
    }

    function groupOf(id) {
        const parts = id.split("/")
        if (parts[0] === "cpu") {
            return { groupId: "cpu", group: i18nc("@title sensor group", "CPU") }
        }
        if (parts[0] === "gpu") {
            const name = gpuNames[parts[1]]
            return { groupId: parts[1], group: name && name.length ? name : i18nc("@title sensor group", "GPU") }
        }
        if (parts[0] === "lmsensors") {
            const chip = parts[1] || ""
            if (/nvme/i.test(chip)) return { groupId: chip, group: i18nc("@title sensor group", "NVMe") }
            if (/drivetemp|sata|ata/i.test(chip)) return { groupId: chip, group: i18nc("@title sensor group", "Drive") }
            if (/k10temp|coretemp|zenpower/i.test(chip)) return { groupId: "cpu", group: i18nc("@title sensor group", "CPU") }
            if (/amdgpu|nouveau|radeon|nvidia/i.test(chip)) return { groupId: chip, group: i18nc("@title sensor group", "GPU") }
            if (/acpitz|thinkpad|dell|asus|it87|nct|w836|f718|pch|wmi/i.test(chip)) return { groupId: chip, group: i18nc("@title sensor group", "Motherboard") }
            return { groupId: chip, group: chip.replace(/-(pci|isa|virtual|acpi)-.*$/, "") }
        }
        if (parts[0] === "disk") {
            return { groupId: parts[1] || "disk", group: i18nc("@title sensor group", "Drive") }
        }
        return { groupId: parts[0], group: parts[0] }
    }

    /*  The kind of hardware decides both the default thresholds and the
        icon the row carries. */
    function categoryOf(id, groupId) {
        if (groupId === "cpu") return "cpu"
        if (/^gpu\//.test(id) || /amdgpu|nouveau|radeon|nvidia/i.test(groupId)) return "gpu"
        if (/nvme/i.test(groupId)) return "nvme"
        if (/drivetemp|sata|ata|^disk/i.test(groupId)) return "hdd"
        return "board"
    }

    function classify() {
        const temps = [], fansOut = [], names = {}
        const cols = probe.columnCount()
        for (let c = 0; c < cols; c++) {
            const idx = probe.index(0, c)
            const id = String(probe.data(idx, Sensors.SensorDataModel.SensorId) || "")
            const m = /^gpu\/(gpu\d+)\/name$/.exec(id)
            if (m) {
                names[m[1]] = String(probe.data(idx, Sensors.SensorDataModel.Value) || "")
            }
        }
        gpuNames = names
        for (let c = 0; c < cols; c++) {
            const idx = probe.index(0, c)
            const id = String(probe.data(idx, Sensors.SensorDataModel.SensorId) || "")
            if (!id.length) {
                continue
            }
            const unit = Number(probe.data(idx, Sensors.SensorDataModel.Unit))
            if (unit !== unitCelsius && unit !== unitRpm) {
                continue
            }
            const g = groupOf(id)
            let short = String(probe.data(idx, Sensors.SensorDataModel.ShortName) || "")
            const name = String(probe.data(idx, Sensors.SensorDataModel.Name) || short || id)
            /*  GPU sensors repeat the card's name in every label. */
            if (g.group.length && short.indexOf(g.group) === 0) {
                short = short.substring(g.group.length).trim()
            }
            if (!short.length) {
                short = name
            }
            const entry = {
                id: id, name: name, shortName: short,
                group: g.group, groupId: g.groupId,
                category: categoryOf(id, g.groupId),
                max: Number(probe.data(idx, Sensors.SensorDataModel.Maximum)) || 0
            }
            if (unit === unitCelsius) {
                temps.push(entry)
            } else {
                fansOut.push(entry)
            }
        }

        probe.enabled = false
        probe.sensors = []

        /*  Columns but no units yet means the answer is not in — try again
            rather than publishing "this machine has no sensors". */
        if (!temps.length && !fansOut.length && ready && (temperatures.length || fans.length)) {
            scheduleRetry()
            return
        }
        temps.sort(byGroupThenName)
        fansOut.sort(byGroupThenName)
        temperatures = temps
        fans = fansOut
        ready = true
    }

    function byGroupThenName(a, b) {
        const order = { cpu: 0 }
        const ga = a.groupId in order ? order[a.groupId] : 1
        const gb = b.groupId in order ? order[b.groupId] : 1
        if (ga !== gb) return ga - gb
        if (a.group !== b.group) return a.group.localeCompare(b.group)
        return a.id.localeCompare(b.id, undefined, { numeric: true })
    }

    /*  The symbolic icon for a category, used by the gadgets so a row says
        what kind of hardware it is without reading the name. */
    function iconFor(category) {
        switch (category) {
        case "cpu": return Qt.resolvedUrl("icons/cpu-symbolic.svg")
        case "gpu": return Qt.resolvedUrl("icons/gpu-symbolic.svg")
        case "nvme": return "media-flash-symbolic"
        case "hdd": return "drive-harddisk-symbolic"
        }
        return "computer-symbolic"
    }
}
