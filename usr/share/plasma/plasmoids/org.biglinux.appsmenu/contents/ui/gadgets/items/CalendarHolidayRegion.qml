/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Holiday region helper, kept in its own file so the optional kholidays
    imports cannot break the calendar gadget when they are missing: it is
    loaded through a Loader and simply stays absent on error.

    Region codes are "<country>[-<state>]_<language>" (e.g. br_pt-br, de-by_de).
    The region list is shared with the Digital Clock, so auto-detection only
    ever fills it in when the user has never picked one.
*/

import QtQuick 2.15
import QtQml.Models 2.15
import org.kde.kholidays as KHolidays
import org.kde.plasma.private.holidayevents as HolidayEvents

Item {
    id: helper

    readonly property var selectedRegions: cfg.selectedRegions
    readonly property bool hasRegion: cfg.selectedRegions.length > 0

    HolidayEvents.HolidayRegionsConfig { id: cfg }

    Instantiator {
        id: regions
        model: KHolidays.HolidayRegionsModel {}
        delegate: QtObject {
            required property string region
            required property string name
        }
    }

    // Human-readable names of what is currently selected.
    function regionNames() {
        const sel = cfg.selectedRegions
        const out = []
        for (let i = 0; i < regions.count; i++) {
            const o = regions.objectAt(i)
            if (o && sel.indexOf(String(o.region)) >= 0) out.push(String(o.name))
        }
        return out
    }

    // Picks the region matching the system locale; returns the code it set, or "".
    function autoDetect() {
        if (cfg.selectedRegions.length > 0) return ""
        const parts = String(Qt.locale().name).split("_")
        const lang = String(parts[0] || "").toLowerCase()
        const country = String(parts[1] || "").toLowerCase()
        if (!country.length) return ""

        let exact = "", sameCountry = ""
        for (let i = 0; i < regions.count; i++) {
            const o = regions.objectAt(i)
            if (!o) continue
            const code = String(o.region || "")
            const seg = code.split("_")
            // country part may carry a state suffix: "de-by" -> "de"
            if (String(seg[0] || "").split("-")[0].toLowerCase() !== country) continue
            if (!sameCountry.length) sameCountry = code
            if (!exact.length && String(seg[1] || "").toLowerCase().indexOf(lang) === 0) exact = code
        }
        const pick = exact.length ? exact : sameCountry
        if (pick.length) {
            cfg.addRegion(pick)
            cfg.saveConfig()
        }
        return pick
    }
}
