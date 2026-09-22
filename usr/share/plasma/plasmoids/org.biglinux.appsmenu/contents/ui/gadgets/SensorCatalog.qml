/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    SensorCatalog — which temperature and fan sensors this machine has, found
    once and shared by every gadget that shows them.

    Everything comes from KSystemStats, the daemon Plasma's own System
    Monitor uses: it already reads hwmon, libsensors and the GPU drivers,
    localises the names, and reports the hardware's critical limit as each
    sensor's Maximum. So there is no /sys walking and no `sensors` process
    here — a single SensorTreeModel walk to list candidate ids, one short-
    lived SensorDataModel to read their units, and the result is kept as two
    plain arrays. Gadgets then subscribe only to the sensors they display,
    for as long as they are on screen.

    Units are KSysGuard's enum: 1000 is °C, 1004 is RPM. Ids containing `\\d`
    are templates in the tree, not sensors.

    Discovery repeats when the tree changes (a card powering up, an external
    enclosure), debounced, so appearing hardware shows up and vanished
    hardware disappears without a restart.
*/

pragma Singleton

import QtQuick 2.15
import org.kde.ksysguard.sensors as Sensors

QtObject {
    id: catalog

    property bool ready: false
    /*  [{ id, name, shortName, group, groupId, max }] */
    property var temperatures: []
    property var fans: []
    /*  gpu/gpuN → its marketing name, so GPU groups read "Radeon RX …". */
    property var gpuNames: ({})

    readonly property int unitCelsius: 1000
    readonly property int unitRpm: 1004

    readonly property var tree: Sensors.SensorTreeModel {
        onRowsInserted: catalog.rediscover.restart()
        onRowsRemoved: catalog.rediscover.restart()
        onModelReset: catalog.rediscover.restart()
    }

    /*  Subscribed to the candidate ids only for as long as it takes to read
        their metadata; then emptied again.  */
    readonly property var probe: Sensors.SensorDataModel {
        enabled: false
        updateRateLimit: 1000
    }

    readonly property var rediscover: Timer {
        interval: 1500
        onTriggered: catalog.discover()
    }
    readonly property var settle: Timer {
        interval: 1800
        onTriggered: catalog.classify()
    }
    readonly property var kick: Timer {
        interval: 1200
        running: true
        onTriggered: catalog.discover()
    }

    function walk(parent, out) {
        for (let i = 0; i < tree.rowCount(parent); i++) {
            const idx = tree.index(i, 0, parent)
            if (tree.canFetchMore(idx)) {
                tree.fetchMore(idx)
            }
            const id = String(tree.data(idx, Sensors.SensorTreeModel.SensorId) || "")
            if (id.length && id.indexOf("\\d") === -1) {
                out.push(id)
            }
            if (tree.rowCount(idx) > 0) {
                walk(idx, out)
            }
        }
    }

    function discover() {
        const ids = []
        try {
            walk(tree.index(-1, -1), ids)
        } catch (e) {
            return
        }
        /*  Anything that might be a temperature or a fan, plus GPU names for
            grouping. The unit read afterwards is what actually decides.  */
        const cand = ids.filter(s => /temp|therm|fan|rpm|hotspot|junction|edge|composite|lmsensors\//i.test(s)
                                     || /^gpu\/gpu\d+\/name$/.test(s))
        if (!cand.length) {
            temperatures = []
            fans = []
            ready = true
            return
        }
        probe.sensors = cand
        probe.enabled = true
        settle.restart()
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
        return { groupId: parts[0], group: parts[0] }
    }

    /*  The kind of hardware decides the default thresholds when the sensor
        reports no limit of its own.  */
    function categoryOf(id, groupId) {
        if (groupId === "cpu") return "cpu"
        if (/^gpu\//.test(id) || /amdgpu|nouveau|radeon|nvidia/i.test(groupId)) return "gpu"
        if (/nvme/i.test(groupId)) return "nvme"
        if (/drivetemp|sata|ata/i.test(groupId)) return "hdd"
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
            const unit = Number(probe.data(idx, Sensors.SensorDataModel.Unit))
            if (unit !== unitCelsius && unit !== unitRpm) {
                continue
            }
            /*  KSystemStats lists a CPU temperature for every core even on a
                machine with no thermal sensor at all (a VM, say); those never
                carry a value. A temperature with no reading, or a flat 0 °C —
                what lmsensors reports for an unconnected header — is not a
                sensor worth a row. Fans keep their 0: a stopped fan is real. */
            const value = probe.data(idx, Sensors.SensorDataModel.Value)
            const num = Number(value)
            if (unit === unitCelsius && (value === undefined || value === null || isNaN(num) || num <= 0)) {
                continue
            }
            if (unit === unitRpm && (value === undefined || value === null || isNaN(num))) {
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
        temps.sort(byGroupThenName)
        fansOut.sort(byGroupThenName)
        temperatures = temps
        fans = fansOut
        ready = true
        probe.enabled = false
        probe.sensors = []
    }

    function byGroupThenName(a, b) {
        const order = { cpu: 0 }
        const ga = a.groupId in order ? order[a.groupId] : 1
        const gb = b.groupId in order ? order[b.groupId] : 1
        if (ga !== gb) return ga - gb
        if (a.group !== b.group) return a.group.localeCompare(b.group)
        return a.id.localeCompare(b.id, undefined, { numeric: true })
    }
}
