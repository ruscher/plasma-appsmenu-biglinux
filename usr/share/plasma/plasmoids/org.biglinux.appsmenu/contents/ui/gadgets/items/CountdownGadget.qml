/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Countdown gadget — time left until your events. cfg: { events: [{name, when}] }
    `when` is "yyyy-MM-dd HH:mm" (local time).
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: cd
    required property var host

    property date now: new Date()
    readonly property var events: (host.cfg.events || []).map(e => Object.assign({}, e, { ts: cd.parseWhen(e.when) }))
        .filter(e => e.ts !== null).sort((a, b) => a.ts - b.ts)
    readonly property var upcoming: events.filter(e => e.ts > now.getTime())
    readonly property var next: upcoming.length ? upcoming[0] : (events.length ? events[events.length - 1] : null)

    Component.onCompleted: {
        host.accent = "#a855f7"
        host.settingsComponent = settings
    }
    Timer { interval: 1000; running: cd.host.active; repeat: true; triggeredOnStart: true; onTriggered: cd.now = new Date() }

    function parseWhen(s) {
        if (!s) return null
        const m = /^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?/.exec(String(s).trim())
        if (!m) return null
        const d = new Date(+m[1], +m[2] - 1, +m[3], m[4] !== undefined ? +m[4] : 0, m[5] !== undefined ? +m[5] : 0, 0)
        return isNaN(d.getTime()) ? null : d.getTime()
    }
    function parts(ts) {
        let diff = Math.max(0, Math.floor((ts - now.getTime()) / 1000))
        const days = Math.floor(diff / 86400); diff -= days * 86400
        const h = Math.floor(diff / 3600); diff -= h * 3600
        const m = Math.floor(diff / 60); const s = diff - m * 60
        return { days: days, h: h, m: m, s: s }
    }
    function pad(n) { return (n < 10 ? "0" : "") + n }

    Binding { target: cd.host; property: "subtitle"; value: cd.upcoming.length > 1 ? i18np("%1 event", "%1 events", cd.upcoming.length) : "" }

    ColumnLayout {
        anchors.fill: parent
        spacing: 2
        visible: cd.next !== null

        PC3.Label {
            text: cd.next ? cd.next.name : ""
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        // Big numbers
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            readonly property var p: cd.next ? cd.parts(cd.next.ts) : { days: 0, h: 0, m: 0, s: 0 }
            readonly property bool past: cd.next && cd.next.ts <= cd.now.getTime()
            component Unit : ColumnLayout {
                property string value: ""
                property string label: ""
                spacing: 0
                PC3.Label {
                    text: value
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * (cd.host.compact ? 1.9 : 2.4)
                    font.weight: Font.Light
                    font.family: "monospace"
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                PC3.Label {
                    text: label
                    opacity: 0.55
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
            Unit { value: String(parent.p.days); label: i18nc("countdown unit", "days"); Layout.fillWidth: true }
            Unit { value: cd.pad(parent.p.h); label: i18nc("countdown unit", "hrs"); Layout.fillWidth: true }
            Unit { value: cd.pad(parent.p.m); label: i18nc("countdown unit", "min"); Layout.fillWidth: true }
            Unit { value: cd.pad(parent.p.s); label: i18nc("countdown unit", "sec"); Layout.fillWidth: true; visible: !cd.host.compact || cd.width > 200 }
        }
        PC3.Label {
            visible: cd.next && cd.next.ts <= cd.now.getTime()
            text: i18n("It's here! 🎉")
            color: cd.host.accent
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignHCenter
        }
        PC3.Label {
            text: cd.next ? Qt.formatDateTime(new Date(cd.next.ts), Qt.locale().dateTimeFormat(Locale.ShortFormat)) : ""
            opacity: 0.55
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        // More events when wide
        Repeater {
            model: cd.host.wide ? cd.upcoming.slice(1, 4) : []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                PC3.Label { text: modelData.name; elide: Text.ElideRight; Layout.fillWidth: true; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                PC3.Label {
                    text: i18np("in %1 day", "in %1 days", cd.parts(modelData.ts).days)
                    opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
        }
        Item { Layout.fillHeight: true }
    }

    // Empty state
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        visible: cd.next === null
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon { source: "chronometer"; Layout.preferredWidth: Kirigami.Units.iconSizes.large; Layout.preferredHeight: Kirigami.Units.iconSizes.large; Layout.alignment: Qt.AlignHCenter; opacity: 0.5 }
        PC3.Label { text: i18n("No events yet"); opacity: 0.7; Layout.alignment: Qt.AlignHCenter }
        PC3.Button { text: i18n("Add event"); icon.name: "list-add"; Layout.alignment: Qt.AlignHCenter; onClicked: cd.host.openSettings() }
    }

    Component {
        id: settings
        ColumnLayout {
            id: se
            property var host
            spacing: Kirigami.Units.largeSpacing
            readonly property var list: host.cfg.events || []
            function save(l) { host.setCfg("events", l) }

            PC3.Label { text: i18n("Events"); font.weight: Font.DemiBold }
            Repeater {
                model: se.list
                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    QQC2.TextField {
                        Layout.fillWidth: true
                        text: modelData.name
                        placeholderText: i18n("Event name")
                        onEditingFinished: { const l = se.list.map(e => Object.assign({}, e)); l[index].name = text; se.save(l) }
                    }
                    QQC2.TextField {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                        text: modelData.when
                        placeholderText: "2026-12-25 00:00"
                        onEditingFinished: { const l = se.list.map(e => Object.assign({}, e)); l[index].when = text.trim(); se.save(l) }
                    }
                    PC3.ToolButton {
                        icon.name: "list-remove"
                        onClicked: se.save(se.list.filter((e, i) => i !== index))
                        Accessible.name: i18n("Remove event")
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                QQC2.TextField { id: newName; Layout.fillWidth: true; placeholderText: i18n("Event name") }
                QQC2.TextField { id: newWhen; Layout.preferredWidth: Kirigami.Units.gridUnit * 9; placeholderText: "yyyy-mm-dd hh:mm" }
                PC3.Button {
                    icon.name: "list-add"; text: i18n("Add")
                    enabled: newName.text.trim().length > 0 && cd.parseWhen(newWhen.text) !== null
                    onClicked: {
                        const l = se.list.map(e => Object.assign({}, e))
                        l.push({ name: newName.text.trim(), when: newWhen.text.trim() })
                        se.save(l); newName.text = ""; newWhen.text = ""
                    }
                }
            }
            PC3.Label {
                text: i18n("Date format: year-month-day, optionally followed by hour:minute (24h).")
                opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize; wrapMode: Text.Wrap; Layout.fillWidth: true
            }
        }
    }
}
