/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    News feed gadget — RSS/Atom with pictures, several feeds, configurable.
    cfg: { feeds: [{name, url}], current: 0, maxItems: 10 }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import ".." as G
import "../lib/GadgetNet.js" as Net
import "../lib/RssParser.js" as Rss

Item {
    id: rss
    required property var host

    readonly property int refreshMs: 30 * 60 * 1000
    readonly property var defaultFeeds: [
        { name: "Phoronix", url: "https://www.phoronix.com/rss.php" },
        { name: "DistroWatch", url: "https://distrowatch.com/news/dw.xml" },
        { name: "Linux Kernel", url: "https://www.kernel.org/feeds/kdist.xml" },
    ]
    readonly property var feeds: host.cfg.feeds && host.cfg.feeds.length ? host.cfg.feeds : defaultFeeds
    onFeedsChanged: forgetRemovedFeeds()
    readonly property int current: Math.max(0, Math.min(feeds.length - 1, host.cfg.current || 0))
    readonly property var feed: feeds[current] || defaultFeeds[0]
    readonly property int maxItems: host.cfg.maxItems || 10
    property var items: []
    property bool busy: false
    property var xhr: null

    Component.onCompleted: {
        host.accentColor = "#f97316"
        host.settingsComponent = settings
        forgetRemovedFeeds()
        loadFromCacheOrFetch()
    }
    Connections {
        target: rss.host
        function onActiveChanged() { if (rss.host.active) rss.refreshIfStale() }
        function onCfgChanged() { rss.loadFromCacheOrFetch() }
    }
    Timer { interval: rss.refreshMs; running: rss.host.active; repeat: true; onTriggered: rss.refreshIfStale() }

    function cacheKey() { return "feed:" + feed.url }

    /*  Articles are cached per source URL into the plasmoid config. A source
        the user removed — or one dropped from the defaults — would otherwise
        keep its articles there for good, so the stale entries are swept on
        load and whenever the list changes.  */
    function forgetRemovedFeeds() {
        const live = {}
        for (const f of feeds) {
            live["feed:" + f.url] = true
        }
        for (const key of host.sharedCacheKeys("feed:")) {
            if (!live[key]) {
                host.sharedCacheRemove(key)
            }
        }
    }
    function loadFromCacheOrFetch() {
        const cached = host.sharedCacheGet(cacheKey())
        items = cached && cached.v && cached.v.items ? cached.v.items : []
        host.subtitle = feed.name || ""
        refreshIfStale()
    }
    function refreshIfStale() {
        if (!Net.cacheFresh(host.sharedCacheGet(cacheKey()), refreshMs)) refresh()
    }
    function refresh() {
        if (busy) return
        busy = true; host.loading = true; host.clearError()
        const url = feed.url
        // Fetch as text and parse it ourselves: many servers send feeds with a
        // non-XML Content-Type (responseXML would be null) and dead feeds return
        // an HTML page — we tell those apart in the error message.
        xhr = Net.fetchText(url, (err, text) => {
            busy = false; host.loading = false
            if (url !== rss.feed.url) return   // feed switched meanwhile
            if (err) {
                host.offline = err === "network" || err === "timeout"
                if (!items.length) host.setError(err.indexOf("http") === 0
                    ? i18n("\"%1\" answered %2. The feed address may be wrong or discontinued.", feed.name, err.toUpperCase())
                    : i18n("Could not reach \"%1\" (%2).", feed.name, Net.describeError(err)))
                return
            }
            host.offline = false
            let doc = null
            if (Rss.looksLikeXml(text) || !Rss.looksLikeHtml(text)) doc = Rss.parseText(text)
            if (!doc) {
                if (!items.length) host.setError(Rss.looksLikeHtml(text)
                    ? i18n("\"%1\" returns a web page, not a feed. Open the site and copy its RSS/Atom link.", feed.name)
                    : i18n("\"%1\" is not a valid RSS/Atom feed.", feed.name))
                return
            }
            const parsed = Rss.parse(doc, maxItems)
            if (!parsed.items.length && !items.length) {
                host.setError(i18n("No entries found in this feed."))
                return
            }
            items = parsed.items
            host.sharedCacheSet(cacheKey(), Net.cacheEntry({ title: parsed.title, items: parsed.items }))
        })
    }
    function ago(ts) {
        if (!ts) return ""
        const s = Math.max(0, (Date.now() - ts) / 1000)
        if (s < 3600) return i18np("%1 min ago", "%1 min ago", Math.max(1, Math.round(s / 60)))
        if (s < 86400) return i18np("%1 hour ago", "%1 hours ago", Math.round(s / 3600))
        return i18np("%1 day ago", "%1 days ago", Math.round(s / 86400))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        // Feed switcher (when more than one)
        /*  Every source stays reachable. This used to be
            `rss.feeds.slice(0, wide ? 5 : 3)`, which simply hid the rest.  */
        G.GadgetTabStrip {
            Layout.fillWidth: true
            visible: rss.feeds.length > 1
            model: rss.feeds
            currentIndex: rss.current
            onActivated: index => rss.host.setCfg("current", index)
        }

        // Wide layout: horizontal cards with pictures
        ListView {
            id: cardsView
            QQC2.ScrollBar.horizontal: PC3.ScrollBar {
                policy: cardsView.contentWidth > cardsView.width ? QQC2.ScrollBar.AsNeeded
                                                                 : QQC2.ScrollBar.AlwaysOff
            }
            visible: rss.host.wide && !rss.host.tall
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: Kirigami.Units.smallSpacing
            clip: true
            model: rss.items
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                required property var modelData
                width: Math.round(cardsView.height * 1.15)
                height: cardsView.height
                G.RoundedImage {
                    anchors.fill: parent
                    source: modelData.image || ""
                    radius: Kirigami.Units.largeSpacing
                    fallbackIcon: "news-subscribe"
                }
                // gradient + title overlay
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: parent.height * 0.62
                    radius: Kirigami.Units.largeSpacing
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.85) }
                    }
                }
                ColumnLayout {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Kirigami.Units.smallSpacing }
                    spacing: 0
                    PC3.Label {
                        text: modelData.title
                        color: "white"
                        font.weight: Font.DemiBold
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    PC3.Label {
                        text: rss.ago(modelData.date)
                        color: "white"; opacity: 0.7
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: if (modelData.link) Qt.openUrlExternally(modelData.link)
                    onEntered: parent.scale = 1.02
                    onExited: parent.scale = 1
                }
                Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                Accessible.role: Accessible.Link
                Accessible.name: modelData.title
            }
        }

        // Compact / tall layout: rows with small thumbnails
        ListView {
            id: rowsView
            QQC2.ScrollBar.vertical: PC3.ScrollBar {
                policy: rowsView.contentHeight > rowsView.height ? QQC2.ScrollBar.AsNeeded
                                                                 : QQC2.ScrollBar.AlwaysOff
            }
            visible: !cardsView.visible
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            clip: true
            model: rss.items
            boundsBehavior: Flickable.StopAtBounds
            delegate: PC3.ItemDelegate {
                required property var modelData
                width: rowsView.width
                height: Math.max(Kirigami.Units.gridUnit * 2.4, rowText.implicitHeight + Kirigami.Units.smallSpacing * 2)
                onClicked: if (modelData.link) Qt.openUrlExternally(modelData.link)
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    G.RoundedImage {
                        visible: !!modelData.image
                        source: modelData.image || ""
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.0
                        radius: Kirigami.Units.smallSpacing
                    }
                    ColumnLayout {
                        id: rowText
                        Layout.fillWidth: true
                        spacing: 0
                        PC3.Label {
                            text: modelData.title
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PC3.Label {
                            text: rss.ago(modelData.date)
                            opacity: 0.55
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                        }
                    }
                }
                Accessible.role: Accessible.Link
                Accessible.name: modelData.title
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: rss.items.length === 0 && rss.host.errorText.length === 0
        PC3.BusyIndicator { running: rss.busy; Layout.alignment: Qt.AlignHCenter }
        PC3.Label { text: i18n("Loading feed…"); opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize }
    }

    // ── settings: feed list editor ──
    Component {
        id: settings
        ColumnLayout {
            id: se
            property var host
            spacing: Kirigami.Units.largeSpacing
            readonly property var list: host.cfg.feeds && host.cfg.feeds.length ? host.cfg.feeds : rss.defaultFeeds
            function save(l) { host.saveCfg(Object.assign({}, host.cfg, { feeds: l, current: Math.min(host.cfg.current || 0, Math.max(0, l.length - 1)) })) }

            PC3.Label { text: i18n("Feeds"); font.weight: Font.DemiBold }
            Repeater {
                model: se.list
                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    QQC2.TextField {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                        text: modelData.name
                        placeholderText: i18n("Name")
                        onEditingFinished: { const l = se.list.map(f => Object.assign({}, f)); l[index].name = text; se.save(l) }
                    }
                    QQC2.TextField {
                        Layout.fillWidth: true
                        text: modelData.url
                        placeholderText: i18nc("@info:placeholder example feed address", "https://…/feed.xml")
                        onEditingFinished: { const l = se.list.map(f => Object.assign({}, f)); l[index].url = text.trim(); se.save(l) }
                    }
                    PC3.ToolButton {
                        icon.name: "list-remove"
                        enabled: se.list.length > 1
                        onClicked: { const l = se.list.filter((f, i) => i !== index); se.save(l) }
                        Accessible.name: i18n("Remove feed")
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                QQC2.TextField { id: newName; placeholderText: i18n("Name"); Layout.preferredWidth: Kirigami.Units.gridUnit * 7 }
                QQC2.TextField { id: newUrl; placeholderText: i18nc("@info:placeholder example feed address", "https://…"); Layout.fillWidth: true }
                PC3.Button {
                    icon.name: "list-add"; text: i18n("Add")
                    enabled: newUrl.text.trim().length > 8
                    onClicked: {
                        const l = se.list.map(f => Object.assign({}, f))
                        l.push({ name: newName.text.trim() || i18n("Feed"), url: newUrl.text.trim() })
                        se.save(l); newName.text = ""; newUrl.text = ""
                    }
                }
            }
            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.SpinBox {
                    Kirigami.FormData.label: i18n("Max items:")
                    from: 3; to: 30
                    value: host.cfg.maxItems || 10
                    onValueModified: host.setCfg("maxItems", value)
                }
            }
        }
    }
}
