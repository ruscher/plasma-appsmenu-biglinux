/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Live Scores gadget — live matches, upcoming fixtures and recent results
    for the leagues you follow (provider: lib/SportsTheSportsDB.js).
    cfg: { leagues: ["4351", ...], current: 0 }
    Live scores refresh every 60 s and fixtures every 30 min — only while the
    gadget is visible; nothing runs when the menu is closed.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import "../lib/GadgetNet.js" as Net
import "../lib/SportsTheSportsDB.js" as Provider

Item {
    id: sports
    required property var host

    readonly property var defaultLeagues: ["4351", "4480", "4387"]
    readonly property var leagues: host.cfg.leagues && host.cfg.leagues.length ? host.cfg.leagues.map(String) : defaultLeagues
    readonly property int current: Math.max(0, Math.min(leagues.length - 1, host.cfg.current || 0))
    readonly property string leagueId: leagues[current]
    readonly property var league: Provider.leagueById(leagueId)
    readonly property int liveMs: 60 * 1000
    readonly property int fixturesMs: 30 * 60 * 1000

    property var liveEvents: []      // this league's live matches
    property var fixtureEvents: []   // upcoming + recent
    property bool busy: false
    readonly property var events: {
        const liveIds = {}
        liveEvents.forEach(e => liveIds[e.id] = true)
        const rest = fixtureEvents.filter(e => !liveIds[e.id])
        const pre = rest.filter(e => e.state === "pre").sort((a, b) => a.date - b.date)
        const post = rest.filter(e => e.state !== "pre").sort((a, b) => b.date - a.date)
        return liveEvents.concat(pre, post)
    }
    readonly property bool hasLive: liveEvents.length > 0

    Component.onCompleted: {
        host.accent = "#22c55e"
        host.settingsComponent = settings
        load()
    }
    Connections {
        target: sports.host
        function onActiveChanged() { if (sports.host.active) sports.refreshIfStale() }
        function onCfgChanged() { sports.load() }
    }
    Timer { interval: sports.liveMs; running: sports.host.active; repeat: true; onTriggered: sports.refreshIfStale() }

    function liveKey() { return "live:" + league.sport }
    function fxKey() { return "fx:" + leagueId }
    function load() {
        const l = host.sharedCacheGet(liveKey()), f = host.sharedCacheGet(fxKey())
        liveEvents = l && l.v ? l.v.filter(e => e.leagueId === leagueId) : []
        fixtureEvents = f && f.v ? f.v : []
        host.subtitle = league.name
        refreshIfStale()
    }
    function refreshIfStale() {
        if (!Net.cacheFresh(host.sharedCacheGet(fxKey()), fixturesMs)) refreshFixtures()
        if (!Net.cacheFresh(host.sharedCacheGet(liveKey()), liveMs)) refreshLive()
    }
    function refreshLive() {
        const id = leagueId, sport = league.sport
        Provider.live(sport, (err, list) => {
            if (id !== sports.leagueId) return
            if (err) { host.offline = true; return }
            host.offline = false
            host.sharedCacheSet(liveKey(), Net.cacheEntry(list))
            liveEvents = list.filter(e => e.leagueId === id)
        })
    }
    function refreshFixtures() {
        if (busy) return
        busy = true; host.loading = true; host.clearError()
        const id = leagueId
        Provider.fixtures(id, (err, list) => {
            busy = false; host.loading = false
            if (id !== sports.leagueId) return
            if (err || !list) {
                host.offline = true
                if (!fixtureEvents.length && !liveEvents.length) host.setError(i18n("Could not load matches (%1).", Net.describeError(err || "json")))
                return
            }
            host.offline = false
            fixtureEvents = list
            host.sharedCacheSet(fxKey(), Net.cacheEntry(list))
        })
    }
    function when(ev) {
        if (ev.state === "in") return ev.clock ? ev.clock : (ev.detail || i18n("Live"))
        if (ev.state === "post") return ev.detail && ev.detail.length <= 5 ? ev.detail : i18nc("match finished", "FT")
        const d = new Date(ev.date)
        const sameDay = d.toDateString() === new Date().toDateString()
        return sameDay ? Qt.formatTime(d, "HH:mm") : Qt.formatDateTime(d, "ddd HH:mm")
    }
    function dateLabel(ev) { return Qt.formatDate(new Date(ev.date), "dd/MM") }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        // League switcher
        RowLayout {
            Layout.fillWidth: true
            visible: sports.leagues.length > 1
            spacing: 2
            Repeater {
                model: sports.leagues.slice(0, sports.host.wide ? 4 : 3)
                delegate: PC3.ToolButton {
                    required property string modelData
                    required property int index
                    readonly property var lg: Provider.leagueById(modelData)
                    text: lg.icon + " " + (sports.host.wide ? lg.name : lg.name.split(" ")[0])
                    checkable: true
                    checked: index === sports.current
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    implicitHeight: Kirigami.Units.iconSizes.smallMedium
                    onClicked: sports.host.setCfg("current", index)
                }
            }
            Item { Layout.fillWidth: true }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: sports.events
            boundsBehavior: Flickable.StopAtBounds
            section.property: "state"
            section.criteria: ViewSection.FullString
            section.delegate: PC3.Label {
                required property string section
                width: list.width
                text: section === "in" ? i18n("Live now") : (section === "pre" ? i18n("Upcoming") : i18n("Results"))
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                font.weight: Font.DemiBold
                opacity: 0.55
                topPadding: 2
                color: section === "in" ? sports.host.accent : Kirigami.Theme.textColor
            }
            delegate: Rectangle {
                id: row
                required property var modelData
                width: list.width
                height: Kirigami.Units.gridUnit * (modelData.state === "pre" ? 2.1 : 2.6)
                radius: Kirigami.Units.smallSpacing
                color: modelData.state === "in" ? Qt.rgba(sports.host.accent.r, sports.host.accent.g, sports.host.accent.b, 0.12)
                                                : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Kirigami.Units.smallSpacing
                    anchors.rightMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    component Team : RowLayout {
                        property var team: ({})
                        property bool alignRight: false
                        spacing: 4
                        layoutDirection: alignRight ? Qt.RightToLeft : Qt.LeftToRight
                        Layout.fillWidth: true
                        Image {
                            source: team && team.logo ? team.logo : ""
                            asynchronous: true
                            sourceSize.width: 32; sourceSize.height: 32
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            visible: status === Image.Ready
                        }
                        PC3.Label {
                            text: team ? (sports.host.wide ? team.name : team.abbr) : ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            horizontalAlignment: alignRight ? Text.AlignRight : Text.AlignLeft
                        }
                    }
                    Team { team: row.modelData.home }
                    Rectangle {
                        Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 3.2, scoreLabel.implicitWidth + Kirigami.Units.smallSpacing * 2)
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                        radius: height / 2
                        color: row.modelData.state === "in" ? sports.host.accent : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                        PC3.Label {
                            id: scoreLabel
                            anchors.centerIn: parent
                            text: row.modelData.state === "pre" ? sports.when(row.modelData)
                                                                : ((row.modelData.home.score || "0") + " – " + (row.modelData.away.score || "0"))
                            font.weight: Font.Bold
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: row.modelData.state === "in" ? "white" : Kirigami.Theme.textColor
                        }
                    }
                    Team { team: row.modelData.away; alignRight: true }
                }
                Rectangle {
                    visible: row.modelData.state === "in"
                    width: 6; height: 6; radius: 3
                    color: sports.host.accent
                    anchors { left: parent.left; top: parent.top; margins: 3 }
                    SequentialAnimation on opacity {
                        running: row.modelData.state === "in" && sports.host.active
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 700 }
                        NumberAnimation { to: 1; duration: 700 }
                    }
                }
                // minute (live) or date (result) centred under the score pill
                PC3.Label {
                    visible: row.modelData.state !== "pre"
                    text: row.modelData.state === "in" ? sports.when(row.modelData) : sports.dateLabel(row.modelData)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
                    opacity: 0.6
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent ? parent.width : 0
        visible: sports.events.length === 0 && sports.host.errorText.length === 0
        PC3.BusyIndicator { running: sports.busy; visible: running; Layout.alignment: Qt.AlignHCenter }
        PC3.Label {
            text: sports.busy ? i18n("Loading matches…") : i18n("No matches found")
            opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize; Layout.alignment: Qt.AlignHCenter
        }
    }

    Component {
        id: settings
        ColumnLayout {
            property var host
            spacing: Kirigami.Units.largeSpacing
            PC3.Label { text: i18n("Leagues to follow"); font.weight: Font.DemiBold }
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: Provider.LEAGUES
                    delegate: QQC2.CheckBox {
                        required property var modelData
                        text: modelData.icon + " " + modelData.name
                        checked: (host.cfg.leagues || sports.defaultLeagues).map(String).indexOf(modelData.id) >= 0
                        onToggled: {
                            let l = (host.cfg.leagues || sports.defaultLeagues).map(String)
                            if (checked && l.indexOf(modelData.id) < 0) l.push(modelData.id)
                            if (!checked) l = l.filter(x => x !== modelData.id)
                            if (l.length === 0) l = [modelData.id]
                            host.saveCfg(Object.assign({}, host.cfg, { leagues: l, current: 0 }))
                        }
                    }
                }
            }
            PC3.Label {
                text: i18n("Data from TheSportsDB (free API). Live scores refresh every minute and fixtures every 30 minutes, only while this page is open.")
                opacity: 0.6; wrapMode: Text.Wrap; font.pointSize: Kirigami.Theme.smallFont.pointSize; Layout.fillWidth: true
            }
        }
    }
}
