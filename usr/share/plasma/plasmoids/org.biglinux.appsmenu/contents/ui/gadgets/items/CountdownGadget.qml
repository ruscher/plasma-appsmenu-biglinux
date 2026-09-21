/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Countdown — events and quick timers. When one finishes: a sound plays and
    a persistent system notification (stays until you close it) shows the
    title and duration. cfg: { events: [{ name, when: "yyyy-MM-dd HH:mm",
    created, quick, fired }] }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.notification as KNotification

Item {
    id: cd
    required property var host

    property date now: new Date()
    readonly property var events: (host.cfg.events || []).map(e => Object.assign({}, e, { ts: cd.parseWhen(e.when) }))
        .filter(e => e.ts !== null).sort((a, b) => a.ts - b.ts)
    readonly property var pending: events.filter(e => !e.fired)
    readonly property var next: pending.length ? pending[0] : null

    Component.onCompleted: {
        host.accentColor = "#a855f7"
        host.settingsComponent = settings
    }
    Timer { interval: 1000; running: cd.host.active && cd.next !== null; repeat: true; triggeredOnStart: true; onTriggered: cd.tick() }
    // Also catch timers that elapsed while the menu was closed
    Connections { target: cd.host; function onActiveChanged() { if (cd.host.active) cd.tick() } }

    function tick() {
        now = new Date()
        for (const e of events) {
            if (!e.fired && e.ts <= now.getTime()) fire(e)
        }
    }
    function parseWhen(s) {
        if (!s) return null
        const m = /^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?/.exec(String(s).trim())
        if (!m) return null
        const d = new Date(+m[1], +m[2] - 1, +m[3], m[4] !== undefined ? +m[4] : 0, m[5] !== undefined ? +m[5] : 0, 0)
        return isNaN(d.getTime()) ? null : d.getTime()
    }
    function fmtWhen(d) {
        const p = n => (n < 10 ? "0" : "") + n
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + " " + p(d.getHours()) + ":" + p(d.getMinutes())
    }
    function parts(ts) {
        let diff = Math.max(0, Math.floor((ts - now.getTime()) / 1000))
        const days = Math.floor(diff / 86400); diff -= days * 86400
        const h = Math.floor(diff / 3600); diff -= h * 3600
        const m = Math.floor(diff / 60); const s = diff - m * 60
        return { days: days, h: h, m: m, s: s }
    }
    function pad(n) { return (n < 10 ? "0" : "") + n }
    function durationText(ms) {
        const m = Math.round(ms / 60000)
        if (m < 60) return i18np("%1 minute", "%1 minutes", m)
        const h = Math.floor(m / 60), r = m % 60
        if (h < 48) return r ? i18n("%1h %2min", h, r) : i18np("%1 hour", "%1 hours", h)
        return i18np("%1 day", "%1 days", Math.round(h / 24))
    }
    function saveEvents(list) { host.setCfg("events", list) }
    function addQuick(minutes) {
        const list = (host.cfg.events || []).slice()
        const end = new Date(Date.now() + minutes * 60000)
        list.push({ name: i18n("%1 min timer", minutes), when: fmtWhen(end), created: Date.now(), quick: true })
        saveEvents(list)
        pop.restart()
    }
    function remove(ev) {
        saveEvents((host.cfg.events || []).filter(e => !(e.name === ev.name && e.when === ev.when)))
    }
    function fire(ev) {
        // mark first so it never fires twice
        const list = (host.cfg.events || []).map(e => (e.name === ev.name && e.when === ev.when) ? Object.assign({}, e, { fired: true }) : e)
        saveEvents(list)
        const started = ev.created ? new Date(ev.created) : null
        const dur = ev.created ? durationText(ev.ts - ev.created) : ""
        const text = started
            ? i18n("“%1” finished.\nDuration: %2 (started at %3, ended at %4).", ev.name, dur, Qt.formatTime(started, "HH:mm"), Qt.formatTime(new Date(ev.ts), "HH:mm"))
            : i18n("“%1” is here — %2.", ev.name, Qt.formatDateTime(new Date(ev.ts), Qt.locale().dateTimeFormat(Locale.ShortFormat)))
        const n = notificationComponent.createObject(cd, { title: i18n("Countdown finished"), text: text })
        if (n) n.sendEvent()
        sound.run("canberra-gtk-play -i alarm-clock-elapsed 2>/dev/null || paplay /usr/share/sounds/ocean/stereo/alarm-clock-elapsed.oga 2>/dev/null || pw-play /usr/share/sounds/ocean/stereo/alarm-clock-elapsed.oga")
    }

    Component {
        id: notificationComponent
        KNotification.Notification {
            componentName: "plasma_workspace"
            eventId: "notification"
            iconName: "chronometer"
            flags: KNotification.Notification.Persistent
            urgency: KNotification.Notification.HighUrgency
            autoDelete: true
        }
    }
    P5Support.DataSource {
        id: sound
        engine: "executable"
        onNewData: source => disconnectSource(source)
        function run(cmd) { connectSource(cmd) }
    }

    SequentialAnimation {
        id: pop
        NumberAnimation { target: mainCol; property: "scale"; to: 1.03; duration: 90 }
        NumberAnimation { target: mainCol; property: "scale"; to: 1.0; duration: 160; easing.type: Easing.OutBack }
    }

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        spacing: 2

        // Big countdown of the next event
        ColumnLayout {
            visible: cd.next !== null
            Layout.fillWidth: true
            spacing: 2
            PC3.Label {
                text: cd.next ? cd.next.name : ""
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                readonly property var p: cd.next ? cd.parts(cd.next.ts) : { days: 0, h: 0, m: 0, s: 0 }
                component Unit : ColumnLayout {
                    property string value: ""
                    property string label: ""
                    spacing: 0
                    PC3.Label {
                        text: value
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * (cd.host.compact ? 1.8 : 2.4)
                        font.weight: Font.Light
                        font.family: "monospace"
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                    PC3.Label { text: label; opacity: 0.55; font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                }
                Unit { visible: parent.p.days > 0; value: String(parent.p.days); label: i18nc("countdown unit", "days"); Layout.fillWidth: true }
                Unit { value: cd.pad(parent.p.h); label: i18nc("countdown unit", "hrs"); Layout.fillWidth: true }
                Unit { value: cd.pad(parent.p.m); label: i18nc("countdown unit", "min"); Layout.fillWidth: true }
                Unit { value: cd.pad(parent.p.s); label: i18nc("countdown unit", "sec"); Layout.fillWidth: true }
            }
            PC3.Label {
                text: cd.next ? Qt.formatDateTime(new Date(cd.next.ts), Qt.locale().dateTimeFormat(Locale.ShortFormat)) : ""
                opacity: 0.5
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Finished events waiting to be dismissed
        Repeater {
            model: cd.events.filter(e => e.fired).slice(0, cd.host.compact ? 1 : 3)
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon { source: "dialog-ok"; color: cd.host.accent; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small }
                PC3.Label { text: i18n("%1 — done", modelData.name); font.pointSize: Kirigami.Theme.smallFont.pointSize; elide: Text.ElideRight; Layout.fillWidth: true }
                PC3.ToolButton { icon.name: "dialog-close"; icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small; onClicked: cd.remove(modelData); Accessible.name: i18n("Dismiss") }
            }
        }

        // Empty state
        ColumnLayout {
            visible: cd.next === null && cd.events.filter(e => e.fired).length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            Item { Layout.fillHeight: true }
            Kirigami.Icon { source: "chronometer"; Layout.preferredWidth: Kirigami.Units.iconSizes.medium; Layout.preferredHeight: Kirigami.Units.iconSizes.medium; Layout.alignment: Qt.AlignHCenter; opacity: 0.45 }
            PC3.Label { text: i18n("Start a quick timer or add an event"); opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; Layout.fillWidth: true }
            Item { Layout.fillHeight: true }
        }
        Item { Layout.fillHeight: true; visible: cd.next !== null }

        // Quick timers
        RowLayout {
            Layout.fillWidth: true
            spacing: 3
            Repeater {
                model: [5, 15, 30, 60]
                delegate: PC3.ToolButton {
                    required property int modelData
                    text: i18nc("quick timer minutes", "%1 min", modelData)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    implicitHeight: Kirigami.Units.iconSizes.smallMedium + 2
                    Layout.fillWidth: true
                    onClicked: cd.addQuick(modelData)
                    Accessible.name: i18n("Start a %1 minute timer", modelData)
                }
            }
            PC3.ToolButton {
                icon.name: "list-add"
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.smallMedium + 2
                onClicked: cd.host.openSettings()
                Accessible.name: i18n("Add event")
                PC3.ToolTip.text: i18n("Add an event with date and time"); PC3.ToolTip.visible: hovered
            }
        }
    }

    // ── settings: events with separate date / time fields ──
    Component {
        id: settings
        ColumnLayout {
            id: se
            property var host
            spacing: Kirigami.Units.largeSpacing
            readonly property var list: host.cfg.events || []
            function save(l) { host.setCfg("events", l) }
            function whenOf(day, month, year, hour, minute) { return year + "-" + cd.pad(month) + "-" + cd.pad(day) + " " + cd.pad(hour) + ":" + cd.pad(minute) }
            function partsOf(when) {
                const m = /^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?/.exec(String(when || ""))
                if (!m) { const d = new Date(); return { y: d.getFullYear(), mo: d.getMonth() + 1, d: d.getDate(), h: d.getHours(), mi: d.getMinutes() } }
                return { y: +m[1], mo: +m[2], d: +m[3], h: m[4] !== undefined ? +m[4] : 0, mi: m[5] !== undefined ? +m[5] : 0 }
            }

            component DateTimeRow : RowLayout {
                property int day: 1
                property int month: 1
                property int year: 2026
                property int hour: 0
                property int minute: 0
                signal changed()
                spacing: Kirigami.Units.smallSpacing
                PC3.Label { text: i18nc("date fields", "Date"); opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                QQC2.SpinBox { from: 1; to: 31; value: day; onValueModified: { day = value; changed() } Accessible.name: i18n("Day") }
                QQC2.SpinBox { from: 1; to: 12; value: month; onValueModified: { month = value; changed() } Accessible.name: i18n("Month") }
                QQC2.SpinBox { from: 2024; to: 2100; value: year; textFromValue: v => String(v); onValueModified: { year = value; changed() } Accessible.name: i18n("Year"); implicitWidth: Kirigami.Units.gridUnit * 5.5 }
                PC3.Label { text: i18nc("time fields", "Time"); opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize; Layout.leftMargin: Kirigami.Units.smallSpacing }
                QQC2.SpinBox { from: 0; to: 23; value: hour; textFromValue: v => cd.pad(v); onValueModified: { hour = value; changed() } Accessible.name: i18n("Hour") }
                PC3.Label { text: ":" }
                QQC2.SpinBox { from: 0; to: 59; value: minute; textFromValue: v => cd.pad(v); onValueModified: { minute = value; changed() } Accessible.name: i18n("Minute") }
            }

            PC3.Label { text: i18n("Events"); font.weight: Font.DemiBold }
            PC3.Label { visible: se.list.length === 0; text: i18n("No events yet."); opacity: 0.6 }
            Repeater {
                model: se.list
                delegate: ColumnLayout {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property var p: se.partsOf(modelData.when)
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        QQC2.TextField {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            placeholderText: i18n("Event name")
                            onEditingFinished: { const l = se.list.map(e => Object.assign({}, e)); l[row.index].name = text; se.save(l) }
                        }
                        PC3.Label { visible: row.modelData.fired === true; text: i18n("finished"); opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                        PC3.ToolButton { icon.name: "list-remove"; onClicked: se.save(se.list.filter((e, i) => i !== row.index)); Accessible.name: i18n("Remove event") }
                    }
                    DateTimeRow {
                        day: row.p.d; month: row.p.mo; year: row.p.y; hour: row.p.h; minute: row.p.mi
                        onChanged: { const l = se.list.map(e => Object.assign({}, e)); l[row.index].when = se.whenOf(day, month, year, hour, minute); l[row.index].fired = false; se.save(l) }
                    }
                    Kirigami.Separator { Layout.fillWidth: true; opacity: 0.3 }
                }
            }

            PC3.Label { text: i18n("New event"); font.weight: Font.DemiBold }
            QQC2.TextField { id: newName; Layout.fillWidth: true; placeholderText: i18n("Event name") }
            DateTimeRow {
                id: newWhen
                readonly property date d0: new Date(Date.now() + 3600000)
                day: d0.getDate(); month: d0.getMonth() + 1; year: d0.getFullYear(); hour: d0.getHours(); minute: 0
            }
            PC3.Button {
                icon.name: "list-add"; text: i18n("Add event")
                enabled: newName.text.trim().length > 0
                onClicked: {
                    const l = se.list.map(e => Object.assign({}, e))
                    l.push({ name: newName.text.trim(), when: se.whenOf(newWhen.day, newWhen.month, newWhen.year, newWhen.hour, newWhen.minute), created: Date.now() })
                    se.save(l); newName.text = ""
                }
            }
            PC3.Label {
                text: i18n("When a countdown ends you'll hear a bell and get a notification that stays until you close it.")
                opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize; wrapMode: Text.Wrap; Layout.fillWidth: true
            }
        }
    }
}
