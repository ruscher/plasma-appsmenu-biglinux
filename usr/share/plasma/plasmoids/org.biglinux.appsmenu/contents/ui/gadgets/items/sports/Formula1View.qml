/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Formula 1 — the championship, not a football match with different words.

    A grand prix has no home and away side and no running score, so the
    match row the rest of Live Scores uses says nothing useful about it.
    This view answers what a season actually consists of: who won each
    round, where the drivers' and constructors' championships stand, what
    the calendar looks like, and which race is next. Four tabs over a
    standing next-race strip, in the shape a broadcast graphic uses —
    position, name, team colour, figure — rather than a table of cells.

    Everything comes from lib/Formula1Provider.js (jolpica/Ergast). Fields
    the API does not carry are left out rather than filled in, images are
    never required for the layout to work (there are none: team colour and
    the country flag of a nationality carry the identity), and each answer
    is cached in the gadget's shared cache so switching tabs costs nothing.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import "../.." as G
import "../../lib/GadgetNet.js" as Net
import "../../lib/Formula1Provider.js" as F1

Item {
    id: f1
    required property var host

    readonly property bool compact: host.compact
    readonly property bool wide: host.wide

    /*  Standings and results only change when a race finishes; the
        calendar, hardly ever. */
    readonly property int standingsMs: 30 * 60 * 1000
    readonly property int seasonMs: 12 * 60 * 60 * 1000

    property int tab: 0
    readonly property var tabs: [
        { name: i18nc("@title:tab results of the races run so far", "Results") },
        { name: i18nc("@title:tab drivers' championship", "Drivers") },
        { name: i18nc("@title:tab constructors' championship", "Teams") },
        { name: i18nc("@title:tab the season's race calendar", "Calendar") }
    ]

    property var winners: []
    property var driverList: []
    property var teamList: []
    property var calendar: []
    /*  The calendar groups by month. A ListView section reads a property
        off the model item, so the month travels with the row; the key is
        sortable and the part after the colon is what the header shows. */
    readonly property var calendarRows: calendar.map(r => Object.assign({}, r, {
        monthKey: (r.date > 0 ? Qt.formatDate(new Date(r.date), "yyyy-MM") : "9999-99") + ":" + f1.monthName(r.date)
    }))
    property var nextRace: null
    property string season: ""
    property int pending: 0

    function colourOf(teamId) {
        const c = F1.teamColour(teamId)
        return c.length ? c : host.accent
    }
    function flag(nat) { return F1.flagOf(nat) }

    function localDate(ms) { return ms > 0 ? Qt.formatDate(new Date(ms), Qt.locale(), Locale.ShortFormat) : "" }
    function localDayMonth(ms) { return ms > 0 ? Qt.formatDate(new Date(ms), "dd MMM").toUpperCase() : "" }
    function localTime(ms) { return ms > 0 ? Qt.formatTime(new Date(ms), Qt.locale(), Locale.ShortFormat) : "" }
    function monthName(ms) { return ms > 0 ? Qt.formatDate(new Date(ms), "MMMM").toUpperCase() : "" }

    Component.onCompleted: load()
    Connections {
        target: f1.host
        function onActiveChanged() { if (f1.host.active) f1.refresh(false) }
    }
    Timer { interval: f1.standingsMs; running: f1.host.active; repeat: true; onTriggered: f1.refresh(false) }

    function cached(key) { return host.sharedCacheGet("f1:" + key) }
    function store(key, value) { host.sharedCacheSet("f1:" + key, Net.cacheEntry(value)) }

    function load() {
        const w = cached("winners"), d = cached("drivers"), t = cached("teams"), s = cached("season"), n = cached("next")
        if (w && w.v) { winners = w.v.races || []; season = w.v.season || season }
        if (d && d.v) driverList = d.v.list || []
        if (t && t.v) teamList = t.v.list || []
        if (s && s.v) { calendar = s.v.races || []; season = season.length ? season : (s.v.season || "") }
        if (n && n.v !== undefined) nextRace = n.v
        refresh(false)
    }

    /*  `force` ignores the cache — used by the reload action in the title
        bar. Otherwise each piece is fetched only when its own entry has
        aged out, so switching tabs never costs a request. */
    function refresh(force) {
        if (!host.active) {
            return
        }
        const jobs = []
        if (force || !Net.cacheFresh(cached("winners"), standingsMs)) jobs.push(["winners", F1.winners, r => { f1.winners = r.races || []; if (r.season) f1.season = r.season }])
        if (force || !Net.cacheFresh(cached("drivers"), standingsMs)) jobs.push(["drivers", F1.drivers, r => { f1.driverList = r.list || []; if (r.season) f1.season = r.season }])
        if (force || !Net.cacheFresh(cached("teams"), standingsMs)) jobs.push(["teams", F1.teams, r => f1.teamList = r.list || []])
        if (force || !Net.cacheFresh(cached("season"), seasonMs)) jobs.push(["season", F1.season, r => { f1.calendar = r.races || []; if (r.season) f1.season = r.season }])
        if (force || !Net.cacheFresh(cached("next"), standingsMs)) jobs.push(["next", F1.next, r => f1.nextRace = r])
        if (!jobs.length) {
            return
        }
        pending += jobs.length
        host.loading = true
        host.clearError()
        for (const [key, fn, apply] of jobs) {
            fn((err, result) => {
                f1.pending--
                if (f1.pending <= 0) {
                    f1.pending = 0
                    f1.host.loading = false
                }
                if (err || result === undefined) {
                    f1.host.offline = true
                    if (!f1.winners.length && !f1.driverList.length && !f1.calendar.length) {
                        f1.host.setError(i18n("Could not load the Formula 1 season (%1).", Net.describeError(err || "json")))
                    }
                    return
                }
                f1.host.offline = false
                f1.host.clearError()
                apply(result)
                f1.store(key, result)
            })
        }
    }

    Binding {
        target: f1.host
        property: "subtitle"
        value: f1.season.length ? i18nc("@info:status the championship season, e.g. 2026 season", "%1 season", f1.season) : ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        /*  The one thing anyone wants at a glance between races. */
        Rectangle {
            visible: f1.nextRace !== null && f1.nextRace !== undefined
            Layout.fillWidth: true
            Layout.preferredHeight: nextCol.implicitHeight + Kirigami.Units.smallSpacing * 2
            radius: Kirigami.Units.smallSpacing
            color: Qt.rgba(f1.host.accent.r, f1.host.accent.g, f1.host.accent.b, 0.13)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    Layout.preferredWidth: 3
                    Layout.fillHeight: true
                    radius: 1.5
                    color: f1.host.accent
                }

                ColumnLayout {
                    id: nextCol
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    PC3.Label {
                        text: f1.nextRace && f1.nextRace.round > 0
                            ? i18nc("@label the upcoming grand prix, with its round number", "NEXT RACE · ROUND %1", f1.nextRace.round)
                            : i18nc("@label the upcoming grand prix", "NEXT RACE")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
                        font.weight: Font.DemiBold
                        color: f1.host.accent
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    PC3.Label {
                        text: f1.nextRace ? f1.nextRace.name : ""
                        font.weight: Font.Bold
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * (f1.compact ? 0.95 : 1.05)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    PC3.Label {
                        visible: text.length > 0
                        text: {
                            if (!f1.nextRace) return ""
                            const parts = []
                            if (!f1.compact && f1.nextRace.circuit.length) parts.push(f1.nextRace.circuit)
                            if (f1.nextRace.date > 0) parts.push(f1.localDate(f1.nextRace.date) + " · " + f1.localTime(f1.nextRace.date))
                            return parts.join(" · ")
                        }
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.75
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            PC3.ToolTip.text: {
                if (!f1.nextRace) return ""
                let s = f1.nextRace.name
                if (f1.nextRace.circuit.length) s += "\n" + f1.nextRace.circuit
                if (f1.nextRace.locality.length || f1.nextRace.country.length) s += "\n" + [f1.nextRace.locality, f1.nextRace.country].filter(x => x.length).join(", ")
                for (const ses of (f1.nextRace.sessions || [])) {
                    s += "\n" + f1.sessionLabel(ses.key) + ": " + f1.localDate(ses.date) + " " + f1.localTime(ses.date)
                }
                return s
            }
            PC3.ToolTip.visible: nextHover.hovered
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            HoverHandler { id: nextHover }
            Accessible.role: Accessible.StaticText
            Accessible.name: f1.nextRace
                ? i18nc("@info accessible next race", "Next race: %1, %2", f1.nextRace.name, f1.localDate(f1.nextRace.date))
                : ""
        }

        G.GadgetTabStrip {
            Layout.fillWidth: true
            model: f1.tabs
            currentIndex: f1.tab
            onActivated: index => f1.tab = index
        }

        // ── Results ──
        ListView {
            visible: f1.tab === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Kirigami.Units.smallSpacing
            model: f1.winners
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true
            QQC2.ScrollBar.vertical: PC3.ScrollBar { policy: parent.contentHeight > parent.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff }

            delegate: RowLayout {
                required property var modelData
                width: ListView.view.width - Kirigami.Units.gridUnit * 0.7
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    Layout.preferredWidth: 3
                    Layout.preferredHeight: resultCol.implicitHeight
                    radius: 1.5
                    color: modelData.winner ? f1.colourOf(modelData.winner.teamId) : f1.host.accent
                }

                ColumnLayout {
                    id: resultCol
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        PC3.Label {
                            text: (modelData.country.length ? modelData.country : modelData.name).toUpperCase()
                            font.weight: Font.Bold
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PC3.Label {
                            text: f1.localDayMonth(modelData.date)
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                            opacity: 0.6
                        }
                    }
                    PC3.Label {
                        visible: modelData.winner !== undefined
                        text: modelData.winner
                            ? modelData.winner.name + (f1.compact ? "" : " · " + modelData.winner.team)
                            : ""
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        visible: modelData.winner !== undefined && !f1.compact
                        Layout.fillWidth: true
                        PC3.Label {
                            text: modelData.winner && modelData.winner.laps > 0
                                ? i18ncp("@info number of laps of a race", "%1 LAP", "%1 LAPS", modelData.winner.laps) : ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                            opacity: 0.6
                            Layout.fillWidth: true
                        }
                        PC3.Label {
                            text: modelData.winner ? modelData.winner.time : ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                            font.family: "monospace"
                            opacity: 0.75
                        }
                    }
                }

                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.winner
                    ? i18nc("@info accessible race result", "%1, won by %2 of %3", modelData.name, modelData.winner.name, modelData.winner.team)
                    : modelData.name
            }
        }

        // ── Drivers ──
        ListView {
            visible: f1.tab === 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Kirigami.Units.smallSpacing
            model: f1.driverList
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true
            QQC2.ScrollBar.vertical: PC3.ScrollBar { policy: parent.contentHeight > parent.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff }

            delegate: RowLayout {
                required property var modelData
                width: ListView.view.width - Kirigami.Units.gridUnit * 0.7
                spacing: Kirigami.Units.smallSpacing

                PC3.Label {
                    text: modelData.pos
                    font.weight: Font.Bold
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * (f1.compact ? 0.95 : 1.1)
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.2
                    opacity: modelData.pos <= 3 ? 1 : 0.65
                }

                Rectangle {
                    Layout.preferredWidth: 3
                    Layout.preferredHeight: driverCol.implicitHeight
                    radius: 1.5
                    color: f1.colourOf(modelData.teamId)
                }

                ColumnLayout {
                    id: driverCol
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0
                    PC3.Label {
                        text: f1.compact && modelData.code.length
                            ? modelData.code + " " + modelData.family
                            : modelData.name
                        font.weight: Font.DemiBold
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    PC3.Label {
                        text: (f1.flag(modelData.nationality).length ? f1.flag(modelData.nationality) + "  " : "") + modelData.team
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                        opacity: 0.7
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    spacing: 0
                    PC3.Label {
                        text: modelData.points.toLocaleString(Qt.locale(), "f", 0)
                        font.weight: Font.Bold
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight
                    }
                    PC3.Label {
                        text: i18nc("@label championship points, abbreviated", "PTS")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.75
                        opacity: 0.55
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight
                    }
                }

                Accessible.role: Accessible.ListItem
                Accessible.name: i18nc("@info accessible driver standing", "%1. %2, %3, %4 points",
                                       modelData.pos, modelData.name, modelData.team, modelData.points)
            }
        }

        // ── Teams ──
        ListView {
            id: teamsView
            visible: f1.tab === 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Kirigami.Units.smallSpacing
            model: f1.teamList
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true
            readonly property real leaderPoints: f1.teamList.length ? Math.max(1, f1.teamList[0].points) : 1
            QQC2.ScrollBar.vertical: PC3.ScrollBar { policy: teamsView.contentHeight > teamsView.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff }

            delegate: RowLayout {
                required property var modelData
                width: teamsView.width - Kirigami.Units.gridUnit * 0.7
                spacing: Kirigami.Units.smallSpacing

                PC3.Label {
                    text: modelData.pos
                    font.weight: Font.Bold
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * (f1.compact ? 0.95 : 1.1)
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.2
                    opacity: modelData.pos <= 3 ? 1 : 0.65
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 2
                    PC3.Label {
                        text: modelData.name
                        font.weight: Font.DemiBold
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    /*  How far behind the leader, without a second number
                        to read: the bar is the share of the leader's total. */
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        radius: 2
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
                        Rectangle {
                            width: parent.width * Math.max(0.02, Math.min(1, modelData.points / teamsView.leaderPoints))
                            height: parent.height
                            radius: parent.radius
                            color: f1.colourOf(modelData.teamId)
                        }
                    }
                }

                PC3.Label {
                    text: modelData.points.toLocaleString(Qt.locale(), "f", 0)
                    font.weight: Font.Bold
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
                }

                Accessible.role: Accessible.ListItem
                Accessible.name: i18nc("@info accessible constructor standing", "%1. %2, %3 points",
                                       modelData.pos, modelData.name, modelData.points)
            }
        }

        // ── Calendar ──
        ListView {
            id: calendarView
            visible: f1.tab === 3
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 1
            model: f1.calendarRows
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true
            QQC2.ScrollBar.vertical: PC3.ScrollBar { policy: calendarView.contentHeight > calendarView.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff }

            section.property: "monthKey"
            section.criteria: ViewSection.FullString
            section.delegate: PC3.Label {
                required property string section
                width: calendarView.width
                text: section.substring(section.indexOf(":") + 1)
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
                font.weight: Font.Bold
                opacity: 0.55
                topPadding: Kirigami.Units.smallSpacing
                Accessible.role: Accessible.Heading
            }

            delegate: RowLayout {
                required property var modelData
                readonly property bool isNext: f1.nextRace && f1.nextRace.round === modelData.round
                readonly property bool done: modelData.date > 0 && modelData.date < Date.now() && !isNext
                width: calendarView.width - Kirigami.Units.gridUnit * 0.7
                spacing: Kirigami.Units.smallSpacing

                PC3.Label {
                    text: modelData.date > 0 ? Qt.formatDate(new Date(modelData.date), "dd") : "--"
                    font.family: "monospace"
                    font.weight: isNext ? Font.Bold : Font.Normal
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: done ? 0.45 : 1
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
                }
                PC3.Label {
                    text: modelData.country.length ? modelData.country : modelData.name
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: isNext ? Font.DemiBold : Font.Normal
                    color: isNext ? f1.host.accent : Kirigami.Theme.textColor
                    opacity: done ? 0.5 : 1
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
                /*  Three states, told by a word and a mark rather than by
                    colour alone. */
                PC3.Label {
                    visible: done || isNext
                    text: isNext ? i18nc("@label the next race of the season", "NEXT") : "✓"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
                    font.weight: Font.Bold
                    color: isNext ? f1.host.accent : Kirigami.Theme.textColor
                    opacity: isNext ? 1 : 0.45
                }

                Accessible.role: Accessible.ListItem
                Accessible.name: i18nc("@info accessible calendar row", "Round %1, %2, %3",
                                       modelData.round, modelData.name, f1.localDate(modelData.date))
            }
        }

        // ── empty / loading ──
        ColumnLayout {
            visible: f1.tab === 0 ? f1.winners.length === 0
                   : f1.tab === 1 ? f1.driverList.length === 0
                   : f1.tab === 2 ? f1.teamList.length === 0
                   : f1.calendar.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            PC3.Label {
                text: f1.host.loading ? i18n("Loading the season…")
                    : f1.host.offline ? i18n("No connection to the Formula 1 data.")
                    : i18n("Nothing to show for this season yet.")
                opacity: 0.6
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    function sessionLabel(key) {
        switch (key) {
        case "fp1": return i18nc("@label free practice session 1", "Practice 1")
        case "fp2": return i18nc("@label free practice session 2", "Practice 2")
        case "fp3": return i18nc("@label free practice session 3", "Practice 3")
        case "sq": return i18nc("@label sprint qualifying session", "Sprint qualifying")
        case "sprint": return i18nc("@label sprint race", "Sprint")
        case "quali": return i18nc("@label qualifying session", "Qualifying")
        }
        return key
    }
}
