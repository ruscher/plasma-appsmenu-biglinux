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
import ".." as G
import "../lib/GadgetNet.js" as Net
import org.kde.notification as KNotification
import "../lib/SportsTheSportsDB.js" as Provider

Item {
    id: sports
    required property var host

    readonly property var defaultLeagues: ["4351", "4480", "4387"]
    readonly property var leagues: host.cfg.leagues && host.cfg.leagues.length ? host.cfg.leagues.map(String) : defaultLeagues
    readonly property int current: Math.max(0, Math.min(leagues.length - 1, host.cfg.current || 0))
    readonly property string leagueId: leagues[current]
    readonly property var league: Provider.leagueById(leagueId)
    /*  How often live scores are polled while the gadget is on screen. The
        provider's free tier is modest, so 30 s is the floor offered and the
        list is deliberately short. Fixtures stay on their own slow timer.  */
    readonly property var liveIntervals: [30, 60, 120, 300]
    readonly property int liveSeconds: {
        const v = Number(host.cfg.liveInterval)
        return liveIntervals.indexOf(v) !== -1 ? v : 60
    }
    readonly property int liveMs: liveSeconds * 1000
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

    readonly property bool notify: host.cfg.notify === true

    /*  Last state seen per match, so a notification is sent on a *change* and
        never twice for the same one. This only runs while the gadget is on
        screen — the menu is not a background service, and adding a daemon for
        score alerts is not a trade this project makes. The settings text says
        so plainly.  */
    property var seenData
    readonly property var seen: seenData !== undefined ? seenData : ({})

    function notifyChanges(events) {
        if (!notify) {
            /*  Keep following the state anyway, so switching notifications on
                does not immediately announce matches that were already live. */
            seenData = snapshot(events)
            return
        }
        const before = seen
        const after = snapshot(events)
        for (const e of events) {
            const was = before[e.id]
            const now = after[e.id]
            if (!was) {
                if (e.state === "in") {
                    send(i18nc("@title:window a match has kicked off", "Match started"), matchLine(e))
                }
                continue
            }
            if (was.state !== "in" && now.state === "in") {
                send(i18nc("@title:window a match has kicked off", "Match started"), matchLine(e))
            } else if (was.state === "in" && now.state !== "in" && now.state !== "pre") {
                send(i18nc("@title:window a match is over", "Match finished"), matchLine(e))
            } else if (now.state === "in" && was.score !== now.score) {
                send(i18nc("@title:window the score changed", "Goal"), matchLine(e))
            }
        }
        seenData = after
    }

    function snapshot(events) {
        const m = {}
        for (const e of events) {
            m[e.id] = { state: e.state, score: (e.home.score || "") + "-" + (e.away.score || "") }
        }
        return m
    }

    function matchLine(e) {
        return i18nc("@info:status home team, score, away team",
                     "%1 %2 – %3 %4", e.home.name, e.home.score || "0",
                     e.away.score || "0", e.away.name)
    }

    function send(title, text) {
        const n = notificationComponent.createObject(sports, { title: title, text: text })
        if (n) {
            n.sendEvent()
        }
    }

    Component {
        id: notificationComponent
        KNotification.Notification {
            componentName: "plasma_workspace"
            eventId: "notification"
            iconName: "applications-sports"
            autoDelete: true
        }
    }

    Component.onCompleted: {
        host.accentColor = "#22c55e"
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
            sports.notifyChanges(sports.liveEvents)
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

        /*  Every followed league stays reachable. This was
            `leagues.slice(0, wide ? 4 : 3)`, so following five leagues hid two
            of them with no way to get at them — the same defect the news
            sources had.  */
        G.GadgetTabStrip {
            Layout.fillWidth: true
            visible: sports.leagues.length > 1
            model: sports.leagues.map(id => {
                const lg = Provider.leagueById(id)
                return { name: lg.icon + " " + (sports.host.wide ? lg.name : lg.name.split(" ")[0]) }
            })
            currentIndex: sports.current
            onActivated: index => sports.host.setCfg("current", index)
        }

        ListView {
            id: list

            /*  Following several leagues easily exceeds the card; the list
                scrolls rather than cutting matches off. */
            QQC2.ScrollBar.vertical: PC3.ScrollBar {
                policy: list.contentHeight > list.height ? QQC2.ScrollBar.AsNeeded
                                                         : QQC2.ScrollBar.AlwaysOff
            }
            flickableDirection: Flickable.VerticalFlick
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

                    /*  Both sides are laid out identically and share the
                        leftover width equally: `preferredWidth: 0` gives them
                        the same base, so the remainder splits evenly and the
                        score pill sits in the true centre of the row whatever
                        the names are. They used to be plain fillWidth items,
                        whose base widths differed with the name lengths, which
                        is what pushed the score off centre.  */
                    component Team : RowLayout {
                        id: teamRow
                        property var team: ({})
                        property bool alignRight: false
                        readonly property int logoSize: sports.host.wide ? Kirigami.Units.iconSizes.medium
                                                                         : Kirigami.Units.iconSizes.smallMedium
                        spacing: Kirigami.Units.smallSpacing
                        layoutDirection: alignRight ? Qt.RightToLeft : Qt.LeftToRight
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        Layout.minimumWidth: 0

                        /*  A fixed slot, so rows line up whether or not a
                            badge exists, and the fallback fills it when the
                            provider has no logo or the download fails. */
                        Item {
                            Layout.preferredWidth: teamRow.logoSize
                            Layout.preferredHeight: teamRow.logoSize
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                id: badge
                                anchors.fill: parent
                                source: team && team.logo ? team.logo : ""
                                asynchronous: true
                                fillMode: Image.PreserveAspectFit
                                sourceSize.width: 64
                                sourceSize.height: 64
                                visible: status === Image.Ready
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: !badge.visible
                                radius: width / 2
                                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                               Kirigami.Theme.textColor.b, 0.12)
                                PC3.Label {
                                    anchors.centerIn: parent
                                    text: teamRow.team ? teamRow.team.abbr : ""
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.8
                                    font.weight: Font.Bold
                                    opacity: 0.7
                                }
                            }
                        }

                        PC3.Label {
                            text: team ? (sports.host.wide ? team.name : team.abbr) : ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: alignRight ? Text.AlignRight : Text.AlignLeft

                            /*  The full name stays available once it elides. */
                            PC3.ToolTip.text: teamRow.team ? teamRow.team.name : ""
                            PC3.ToolTip.visible: nameHover.hovered && truncated
                            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                            HoverHandler { id: nameHover }
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
                /*  A live match is marked with a dot and the word, not a pulse:
                    the blink forced a full repaint every frame for every live
                    row, and colour alone is not a signal everybody can read.  */
                Row {
                    visible: row.modelData.state === "in"
                    spacing: 3
                    anchors { left: parent.left; top: parent.top; margins: 3 }
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: sports.host.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    PC3.Label {
                        text: i18nc("@label marks a match in progress", "LIVE")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.7
                        font.weight: Font.Bold
                        color: sports.host.accent
                        anchors.verticalCenter: parent.verticalCenter
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
            id: se

            PC3.Label { text: i18n("Leagues to follow"); font.weight: Font.DemiBold }

            /*  A Flow left ragged rows and pushed the last leagues out of
                sight. A grid with a column count chosen from the real width
                keeps every league inside the dialog: three abreast when there
                is room, two at medium width, one only when there is no other
                option. The dialog itself scrolls vertically, so a long list
                stays reachable.  */
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: 0
                columns: se.width > Kirigami.Units.gridUnit * 28 ? 3
                       : (se.width > Kirigami.Units.gridUnit * 17 ? 2 : 1)

                Repeater {
                    model: Provider.LEAGUES
                    delegate: QQC2.CheckBox {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: modelData.icon + " " + modelData.name
                        checked: (host.cfg.leagues || sports.defaultLeagues).map(String).indexOf(modelData.id) >= 0
                        onToggled: {
                            let l = (host.cfg.leagues || sports.defaultLeagues).map(String)
                            if (checked && l.indexOf(modelData.id) < 0) l.push(modelData.id)
                            if (!checked) l = l.filter(x => x !== modelData.id)
                            /*  Following nothing would leave the card blank,
                                so the last league cannot be unticked. */
                            if (l.length === 0) l = [modelData.id]
                            host.saveCfg(Object.assign({}, host.cfg, { leagues: l, current: 0 }))
                        }
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; opacity: 0.3 }

            Kirigami.FormLayout {
                Layout.fillWidth: true

                QQC2.ComboBox {
                    Kirigami.FormData.label: i18n("Refresh live scores:")
                    model: [
                        i18nc("@item:inlistbox refresh interval", "Every 30 seconds"),
                        i18nc("@item:inlistbox refresh interval", "Every minute"),
                        i18nc("@item:inlistbox refresh interval", "Every 2 minutes"),
                        i18nc("@item:inlistbox refresh interval", "Every 5 minutes")
                    ]
                    currentIndex: Math.max(0, sports.liveIntervals.indexOf(sports.liveSeconds))
                    onActivated: host.setCfg("liveInterval", sports.liveIntervals[currentIndex])
                }

                QQC2.CheckBox {
                    Kirigami.FormData.label: i18n("Notifications:")
                    text: i18n("Notify me about live matches")
                    checked: host.cfg.notify === true
                    onToggled: host.setCfg("notify", checked)
                }
            }

            PC3.Label {
                visible: host.cfg.notify === true
                text: i18n("Kick-off, goals and full time are announced. They can only be noticed while this page is open — the menu does not run in the background, so no alerts arrive while it is closed.")
                opacity: 0.6
                wrapMode: Text.Wrap
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }
            PC3.Label {
                text: i18n("Data from TheSportsDB (free API). Fixtures refresh every 30 minutes, and nothing is fetched while this page is closed.")
                opacity: 0.6; wrapMode: Text.Wrap; font.pointSize: Kirigami.Theme.smallFont.pointSize; Layout.fillWidth: true
            }
        }
    }
}
