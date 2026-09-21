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
    /*  Exactly what the API publishes at /v1/currencies. The previous list
        included ARS, which it does not carry, so picking it yielded a silent
        blank row.  */
    readonly property var known: [
        "AUD", "BRL", "CAD", "CHF", "CNY", "CZK", "DKK", "EUR", "GBP", "HKD",
        "HUF", "IDR", "ILS", "INR", "ISK", "JPY", "KRW", "MXN", "MYR", "NOK",
        "NZD", "PHP", "PLN", "RON", "SEK", "SGD", "THB", "TRY", "USD", "ZAR"
    ]
    readonly property var flags: ({
        AUD: "🇦🇺", BRL: "🇧🇷", CAD: "🇨🇦", CHF: "🇨🇭", CNY: "🇨🇳", CZK: "🇨🇿",
        DKK: "🇩🇰", EUR: "🇪🇺", GBP: "🇬🇧", HKD: "🇭🇰", HUF: "🇭🇺", IDR: "🇮🇩",
        ILS: "🇮🇱", INR: "🇮🇳", ISK: "🇮🇸", JPY: "🇯🇵", KRW: "🇰🇷", MXN: "🇲🇽",
        MYR: "🇲🇾", NOK: "🇳🇴", NZD: "🇳🇿", PHP: "🇵🇭", PLN: "🇵🇱", RON: "🇷🇴",
        SEK: "🇸🇪", SGD: "🇸🇬", THB: "🇹🇭", TRY: "🇹🇷", USD: "🇺🇸", ZAR: "🇿🇦"
    })

    /*  The rates actually shown: never the base against itself, and never a
        code the API does not carry.  */
    readonly property var shown: targets.filter(t => t !== base && known.indexOf(t) !== -1)
    property var fx: null   // { base, date, rates: {} }
    property bool busy: false

    Component.onCompleted: {
        host.accentColor = "#16a34a"
        host.settingsComponent = settings
        const cached = cachedRates()
        if (cached) fx = cached.v
        refreshIfStale()
    }
    Connections {
        target: currency.host
        function onActiveChanged() { if (currency.host.active) currency.refreshIfStale() }
        function onCfgChanged() { currency.refresh() }
    }
    Timer { interval: currency.refreshMs; running: currency.host.active; repeat: true; onTriggered: currency.refreshIfStale() }

    /*  A cached quote is only usable if it covers every currency currently on
        screen. Checking the base alone was not enough: adding a currency left
        the old payload looking fresh, so the new rows sat empty for up to an
        hour with no request ever being made. Removing a currency does not
        invalidate anything, since the payload still covers what is shown.  */
    function cachedRates() {
        const e = host.cacheGet("rates")
        if (!e || !e.v || e.v.base !== base || !e.v.rates) {
            return null
        }
        for (const t of shown) {
            if (e.v.rates[t] === undefined) {
                return null
            }
        }
        return e
    }

    function refreshIfStale() {
        if (!Net.cacheFresh(cachedRates(), refreshMs)) {
            refresh()
        }
    }
    /*  Requests supersede one another instead of being dropped while one is
        in flight: changing the base twice quickly used to lose the second
        change, and cfgChanged arrives twice per save (see 00-audit).  */
    property int requestId: 0

    function refresh() {
        const id = ++requestId
        const to = shown
        if (!to.length) {
            busy = false; host.loading = false; host.clearError()
            return
        }
        busy = true; host.loading = true; host.clearError()
        /*  api.frankfurter.app now answers 301 to api.frankfurter.dev/v1;
            calling the canonical host directly saves the extra round trip. */
        const url = "https://api.frankfurter.dev/v1/latest?" + Net.query({ from: base, to: to.join(",") })
        Net.fetchJson(url, (err, d) => {
            if (id !== currency.requestId) return
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
        visible: currency.fx !== null && currency.shown.length > 0

        PC3.Label {
            text: i18n("1 %1 %2", currency.base, currency.flags[currency.base] || "")
            font.weight: Font.DemiBold
            opacity: 0.8
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
        /*  The base line above stays put while the rates scroll under it.
            This used to be a Repeater over `.slice(0, compact ? 4 : 8)`, so
            picking more currencies than that simply hid them.  */
        ListView {
            id: rateList

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: currency.shown
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            reuseItems: true

            QQC2.ScrollBar.vertical: PC3.ScrollBar {
                policy: rateList.contentHeight > rateList.height ? QQC2.ScrollBar.AsNeeded
                                                                 : QQC2.ScrollBar.AlwaysOff
            }

            delegate: RowLayout {
                required property string modelData
                width: rateList.width
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
    }

    PC3.Label {
        anchors.centerIn: parent
        width: parent.width - 2 * Kirigami.Units.largeSpacing
        visible: currency.shown.length === 0
        text: i18n("No currencies selected. Choose some in the settings.")
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        opacity: 0.6
        font.pointSize: Kirigami.Theme.smallFont.pointSize
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: currency.shown.length > 0 && currency.fx === null && currency.host.errorText.length === 0
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
                RowLayout {
                    Kirigami.FormData.label: i18n("Show:")
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    PC3.Button {
                        text: i18nc("@action:button select every currency", "Select all")
                        icon.name: "edit-select-all"
                        /*  Everything except the base: it is the unit the
                            rates are quoted in, so listing it against itself
                            would only ever print 1. */
                        onClicked: host.setCfg("targets",
                            currency.known.filter(c => c !== (host.cfg.base || "USD")))
                    }
                    PC3.Button {
                        text: i18nc("@action:button unselect every currency", "Clear")
                        icon.name: "edit-clear-all"
                        onClicked: host.setCfg("targets", [])
                    }
                    Item { Layout.fillWidth: true }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: currency.known
                        delegate: QQC2.CheckBox {
                            required property string modelData
                            readonly property bool isBase: modelData === (host.cfg.base || "USD")
                            text: (currency.flags[modelData] || "") + " " + modelData
                            /*  The base cannot also be a target — an invalid
                                pairing the UI simply does not offer. */
                            enabled: !isBase
                            checked: !isBase && (host.cfg.targets || ["BRL", "EUR", "GBP"]).indexOf(modelData) >= 0
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
