/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Calendar — Plasma's own month view (the one behind the Digital Clock)
    with its event plugins: holidays, astronomical events and alternate
    calendars (Chinese lunar, Islamic, …). cfg: { plugins: [paths],
    weekNumbers: bool, calendarApp: "" (auto) }
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.plasma.workspace.calendar 2.0 as PlasmaCalendar

Item {
    id: cal
    required property var host

    property date today: new Date()
    Component.onCompleted: {
        host.accent = "#ef4444"
        host.settingsComponent = settings
        plugins.populateEnabledPluginsList(host.cfg.plugins || [])
    }
    Connections {
        target: cal.host
        function onActiveChanged() { if (cal.host.active) cal.today = new Date() }
        function onCfgChanged() { plugins.populateEnabledPluginsList(cal.host.cfg.plugins || []) }
    }
    Timer { interval: 60 * 60 * 1000; running: cal.host.active; repeat: true; onTriggered: cal.today = new Date() }

    PlasmaCalendar.EventPluginsManager { id: plugins }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: source => disconnectSource(source)
        function run(cmd) { connectSource(cmd) }
    }
    function openCalendarApp() {
        const custom = String(host.cfg.calendarApp || "").trim()
        if (custom.length) { runner.run(custom); return }
        // default handler for text/calendar (what the system defines as the calendar app)
        runner.run('d=$(xdg-mime query default text/calendar); p=$(find /usr/share/applications "$HOME/.local/share/applications" -name "$d" 2>/dev/null | head -1); if [ -n "$p" ]; then kioclient exec "$p"; else kioclient exec "$(find /usr/share/applications -iname "*korganizer*" -o -iname "*merkuro*calendar*" 2>/dev/null | head -1)"; fi')
        if (kickoff.hideOnWindowDeactivate) kickoff.expanded = false
    }

    PlasmaCalendar.MonthView {
        id: month
        anchors.fill: parent
        eventPluginsManager: plugins
        today: cal.today
        showWeekNumbers: cal.host.cfg.weekNumbers === true
        showDigitalClockHeader: false
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        borderOpacity: 0.15
        Kirigami.Theme.inherit: true
    }

    // Open the calendar application (default handler for text/calendar)
    PC3.ToolButton {
        anchors { right: parent.right; top: parent.top; margins: 1 }
        icon.name: "view-calendar-day"
        icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
        opacity: cal.host.hovered ? 0.9 : 0.35
        onClicked: cal.openCalendarApp()
        Accessible.name: i18n("Open calendar application")
        PC3.ToolTip.text: i18n("Open calendar application"); PC3.ToolTip.visible: hovered
    }

    // ── settings ──
    Component {
        id: settings
        ColumnLayout {
            id: se
            property var host
            spacing: Kirigami.Units.largeSpacing
            property Item pluginUi: null

            PC3.Label { text: i18n("Show on the calendar"); font.weight: Font.DemiBold }
            Repeater {
                model: plugins.model
                delegate: RowLayout {
                    id: prow
                    required property var model
                    Layout.fillWidth: true
                    QQC2.CheckBox {
                        text: prow.model.display
                        checked: prow.model.checked === true
                        onToggled: {
                            prow.model.checked = checked
                            host.setCfg("plugins", plugins.enabledPlugins)
                        }
                        Layout.fillWidth: true
                    }
                    PC3.ToolButton {
                        icon.name: "configure"
                        visible: !!prow.model.configUi
                        onClicked: {
                            if (se.pluginUi) { if (se.pluginUi.saveConfig) se.pluginUi.saveConfig(); se.pluginUi.destroy(); se.pluginUi = null }
                            const comp = Qt.createComponent(prow.model.configUi)
                            if (comp.status === Component.Ready) se.pluginUi = comp.createObject(pluginHolder, { width: pluginHolder.width })
                            else console.warn("calendar plugin config:", comp.errorString())
                        }
                        Accessible.name: i18n("Configure %1", prow.model.display)
                        PC3.ToolTip.text: i18n("Configure %1", prow.model.display); PC3.ToolTip.visible: hovered
                    }
                }
            }
            PC3.Label {
                text: i18n("Holidays: choose your country/state in its settings. Alternate calendar: pick Chinese lunar, Islamic, Hebrew, Indian…")
                opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize; wrapMode: Text.Wrap; Layout.fillWidth: true
            }
            Item {
                id: pluginHolder
                Layout.fillWidth: true
                Layout.preferredHeight: se.pluginUi ? Kirigami.Units.gridUnit * 16 : 0
                onWidthChanged: if (se.pluginUi) se.pluginUi.width = width
                clip: true
            }
            PC3.Button {
                visible: se.pluginUi !== null
                text: i18n("Save plugin settings")
                icon.name: "document-save"
                onClicked: { if (se.pluginUi && se.pluginUi.saveConfig) se.pluginUi.saveConfig(); se.pluginUi.destroy(); se.pluginUi = null; host.setCfg("plugins", plugins.enabledPlugins) }
            }
            Component.onDestruction: { if (se.pluginUi && se.pluginUi.saveConfig) se.pluginUi.saveConfig() }

            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.CheckBox {
                    Kirigami.FormData.label: i18n("Options:")
                    text: i18n("Show week numbers")
                    checked: host.cfg.weekNumbers === true
                    onToggled: host.setCfg("weekNumbers", checked)
                }
                QQC2.TextField {
                    Kirigami.FormData.label: i18n("Calendar app:")
                    placeholderText: i18n("automatic (system default for calendars)")
                    text: host.cfg.calendarApp || ""
                    onEditingFinished: host.setCfg("calendarApp", text.trim())
                }
            }
        }
    }
}
