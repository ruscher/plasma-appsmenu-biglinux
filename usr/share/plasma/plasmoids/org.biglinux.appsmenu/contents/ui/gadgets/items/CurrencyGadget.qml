/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Currency gadget — exchange rates from Frankfurter (ECB fx, no API key).
    cfg: { base: "USD", targets: ["BRL","EUR","GBP"] }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import "../lib/GadgetNet.js" as Net

Item {
    id: currency
    required property var host

    readonly property int refreshMs: 60 * 60 * 1000
    readonly property string base: host.cfg.base || "USD"
    readonly property var targets: host.cfg.targets && host.cfg.targets.length ? host.cfg.targets : ["BRL", "EUR", "GBP"]
    readonly property var known: ["USD", "EUR", "BRL", "GBP", "JPY", "CHF", "CAD", "AUD", "CNY", "ARS", "MXN", "INR", "KRW", "SEK", "NOK", "PLN", "TRY", "ZAR"]
    readonly property var flags: ({ USD: "🇺🇸", EUR: "🇪🇺", BRL: "🇧🇷", GBP: "🇬🇧", JPY: "🇯🇵", CHF: "🇨🇭", CAD: "🇨🇦", AUD: "🇦🇺", CNY: "🇨🇳", ARS: "🇦🇷", MXN: "🇲🇽", INR: "🇮🇳", KRW: "🇰🇷", SEK: "🇸🇪", NOK: "🇳🇴", PLN: "🇵🇱", TRY: "🇹🇷", ZAR: "🇿🇦" })
    property var fx: null   // { base, date, rates: {} }
    property bool busy: false

    Component.onCompleted: {
        host.accent = "#16a34a"
        host.settingsComponent = settings
        const cached = host.cacheGet("rates")
        if (cached && cached.v && cached.v.base === base) fx = cached.v
        refreshIfStale()
    }
    Connections {
        target: currency.host
        function onActiveChanged() { if (currency.host.active) currency.refreshIfStale() }
        function onCfgChanged() { currency.refresh() }
    }
    Timer { interval: currency.refreshMs; running: currency.host.active; repeat: true; onTriggered: currency.refreshIfStale() }

    function refreshIfStale() {
        const cached = host.cacheGet("rates")
        if (!Net.cacheFresh(cached, refreshMs) || !cached.v || cached.v.base !== base) refresh()
    }
    function refresh() {
        if (busy) return
        busy = true; host.loading = true; host.clearError()
        const to = targets.filter(t => t !== base)
        const url = "https://api.frankfurter.app/latest?" + Net.query({ from: base, to: to.join(",") })
        Net.fetchJson(url, (err, d) => {
            busy = false; host.loading = false
            if (err || !d || !d.rates) {
                host.offline = true
                if (!fx) host.setError(i18n("Could not load exchange rates (%1).", Net.describeError(err || "json")))
                return
            }
            host.offline = false
            fx = { base: d.base, date: d.date, rates: d.rates, fetchedAt: Date.now() }
            host.cacheSet("rates", Net.cacheEntry(fx))
        })
    }
    Binding {
        target: currency.host; property: "subtitle"
        value: currency.fx ? i18nc("rates date", "ECB %1", currency.fx.date) : ""
    }
    function fmt(v) {
        if (v === undefined || v === null) return "—"
        return Number(v).toLocaleString(Qt.locale(), "f", v < 1 ? 4 : 2)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 2
        visible: currency.fx !== null

        PC3.Label {
            text: i18n("1 %1 %2", currency.base, currency.flags[currency.base] || "")
            font.weight: Font.DemiBold
            opacity: 0.8
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
        Repeater {
            model: currency.targets.filter(t => t !== currency.base).slice(0, currency.host.compact ? 4 : 8)
            delegate: RowLayout {
                required property string modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                PC3.Label { text: currency.flags[modelData] || "•"; font.pointSize: Kirigami.Theme.defaultFont.pointSize }
                PC3.Label { text: modelData; font.weight: Font.DemiBold; Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2 }
                Item { Layout.fillWidth: true }
                PC3.Label {
                    text: currency.fmt(currency.fx && currency.fx.rates ? currency.fx.rates[modelData] : null)
                    font.family: "monospace"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * (currency.host.compact ? 1.0 : 1.1)
                }
            }
        }
        Item { Layout.fillHeight: true }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: currency.fx === null && currency.host.errorText.length === 0
        PC3.BusyIndicator { running: currency.busy; Layout.alignment: Qt.AlignHCenter }
        PC3.Label { text: i18n("Fetching rates…"); opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize }
    }

    Component {
        id: settings
        ColumnLayout {
            property var host
            spacing: Kirigami.Units.largeSpacing
            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.ComboBox {
                    Kirigami.FormData.label: i18n("Base currency:")
                    model: currency.known
                    currentIndex: Math.max(0, currency.known.indexOf(host.cfg.base || "USD"))
                    onActivated: host.setCfg("base", currentText)
                }
                Flow {
                    Kirigami.FormData.label: i18n("Show:")
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: currency.known
                        delegate: QQC2.CheckBox {
                            required property string modelData
                            text: (currency.flags[modelData] || "") + " " + modelData
                            checked: (host.cfg.targets || ["BRL", "EUR", "GBP"]).indexOf(modelData) >= 0
                            onToggled: {
                                let t = (host.cfg.targets || ["BRL", "EUR", "GBP"]).slice()
                                if (checked && t.indexOf(modelData) < 0) t.push(modelData)
                                if (!checked) t = t.filter(x => x !== modelData)
                                host.setCfg("targets", t)
                            }
                        }
                    }
                }
            }
            PC3.Label {
                text: i18n("Reference rates from the European Central Bank via frankfurter.app, updated on working days.")
                opacity: 0.6; wrapMode: Text.Wrap; font.pointSize: Kirigami.Theme.smallFont.pointSize; Layout.fillWidth: true
            }
        }
    }
}
