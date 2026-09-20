/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Calendar — a compact month grid fed by Plasma's calendar backend and its
    event plugins (holidays, astronomical events, alternate calendars). Days
    with events get a colored dot; hovering a day shows a tooltip with the
    event names and the alternate-calendar date. Clicking the app button opens
    the system's default calendar application.

    cfg: { plugins: [enabled .so names], weekNumbers: bool, calendarApp: "" }
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
    // bumped whenever plugin data arrives, so tooltips re-read eventsForDate()
    property int dataRev: 0

    Component.onCompleted: {
        host.accent = "#ef4444"
        host.settingsComponent = settings
        plugins.populateEnabledPluginsList(host.cfg.plugins || [])
    }
    Connections {
        target: cal.host
        function onActiveChanged() { if (cal.host.active) { cal.today = new Date(); backend.updateData() } }
        function onCfgChanged() { plugins.populateEnabledPluginsList(cal.host.cfg.plugins || []); cal.reapply() }
    }
    Timer { interval: 60 * 60 * 1000; running: cal.host.active; repeat: true; onTriggered: cal.today = new Date() }

    PlasmaCalendar.EventPluginsManager { id: plugins }
    PlasmaCalendar.Calendar {
        id: backend
        days: 7
        weeks: 6
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: cal.today
        Component.onCompleted: daysModel.setPluginsManager(plugins)
    }
    // Plugin data is fetched asynchronously; refresh dots/labels when it lands.
    Connections {
        target: plugins
        function onDataReady() { cal.dataRev++ }
        function onSubLabelReady() { cal.dataRev++ }
        function onPluginsChanged() { backend.daysModel.setPluginsManager(plugins); cal.reapply() }
    }
    function reapply() {
        backend.daysModel.setPluginsManager(plugins)
        backend.updateData()
        cal.dataRev++
    }

    function tooltipFor(y, m, d) {
        cal.dataRev // dependency: re-evaluate when plugin data changes
        let lines = []
        try {
            const evs = backend.eventsForDate(new Date(y, m - 1, d))
            for (let i = 0; i < evs.length; i++) {
                const t = evs[i].title || evs[i].description || ""
                if (t && lines.indexOf(t) < 0) lines.push(t)
            }
        } catch (e) {}
        return lines
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        // ── header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            PC3.ToolButton {
                icon.name: "go-previous"
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                implicitWidth: Kirigami.Units.iconSizes.smallMedium + 4; implicitHeight: implicitWidth
                onClicked: backend.previousMonth()
                Accessible.name: i18n("Previous month")
            }
            PC3.Label {
                text: Qt.formatDate(backend.displayedDate, "MMMM yyyy")
                font.weight: Font.DemiBold
                font.pointSize: cal.host.compact ? Kirigami.Theme.smallFont.pointSize : Kirigami.Theme.defaultFont.pointSize
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                Layout.fillWidth: true
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: backend.resetToToday()
                    PC3.ToolTip.text: i18n("Back to today"); PC3.ToolTip.visible: containsMouse
                }
            }
            PC3.ToolButton {
                icon.name: "view-calendar-day"
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                implicitWidth: Kirigami.Units.iconSizes.smallMedium + 4; implicitHeight: implicitWidth
                opacity: cal.host.hovered ? 0.9 : 0.4
                onClicked: cal.openCalendarApp()
                Accessible.name: i18n("Open calendar application")
                PC3.ToolTip.text: i18n("Open calendar application"); PC3.ToolTip.visible: hovered
            }
            PC3.ToolButton {
                icon.name: "go-next"
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                implicitWidth: Kirigami.Units.iconSizes.smallMedium + 4; implicitHeight: implicitWidth
                onClicked: backend.nextMonth()
                Accessible.name: i18n("Next month")
            }
        }

        // ── weekday header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: 7
                delegate: PC3.Label {
                    required property int index
                    readonly property int dow: (Qt.locale().firstDayOfWeek + index) % 7
                    text: Qt.locale().dayName(dow === 0 ? 7 : dow, Locale.NarrowFormat)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    font.weight: Font.DemiBold
                    opacity: (dow === 0 || dow === 6) ? 0.45 : 0.6
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }

        // ── days ──
        GridLayout {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 0
            columnSpacing: 0

            Repeater {
                model: backend.daysModel
                delegate: Item {
                    id: cell
                    required property var model
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    readonly property bool inMonth: model.isCurrent === true
                    readonly property bool isToday: model.dayNumber === cal.today.getDate()
                        && model.monthNumber === (cal.today.getMonth() + 1)
                        && model.yearNumber === cal.today.getFullYear()
                    readonly property bool hasEvents: model.containsEventItems === true
                    readonly property bool isMajor: model.containsMajorEventItems === true
                    readonly property string sub: model.subLabel || ""
                    readonly property var events: cell.hovered ? cal.tooltipFor(model.yearNumber, model.monthNumber, model.dayNumber) : []
                    readonly property bool hovered: dayHover.hovered

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.max(16, Math.min(parent.width * 0.9, parent.height * 0.9, Kirigami.Units.gridUnit * 2.4))
                        height: width
                        radius: width / 2
                        color: cell.isToday ? cal.host.accent
                             : (cell.hovered && cell.inMonth ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12) : "transparent")
                        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                        PC3.Label {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: cell.sub.length ? -Math.round(parent.height * 0.10) : 0
                            text: cell.model.dayNumber
                            font.pointSize: Math.max(6, Math.min(Kirigami.Theme.defaultFont.pointSize, parent.height * 0.42))
                            font.weight: cell.isToday ? Font.Bold : Font.Normal
                            color: cell.isToday ? "white" : Kirigami.Theme.textColor
                            opacity: cell.inMonth ? 1 : 0.3
                        }
                        // alternate-calendar / short sublabel as a tiny secondary number
                        PC3.Label {
                            visible: cell.sub.length > 0 && cell.sub.length <= 4
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.height * 0.06 }
                            text: cell.sub
                            font.pointSize: Math.max(5, parent.height * 0.22)
                            color: cell.isToday ? "white" : Kirigami.Theme.textColor
                            opacity: cell.inMonth ? 0.6 : 0.25
                        }
                    }

                    // event dot (top-right)
                    Rectangle {
                        visible: cell.hasEvents
                        width: Math.max(4, Math.min(7, cell.height * 0.12)); height: width; radius: width / 2
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Math.max(2, (parent.height - Math.min(parent.width * 0.9, parent.height * 0.9, Kirigami.Units.gridUnit * 2.4)) / 2 - width) }
                        color: cell.isMajor ? Kirigami.Theme.negativeTextColor : cal.host.accent
                        opacity: cell.inMonth ? 1 : 0.4
                    }

                    HoverHandler { id: dayHover }
                    PC3.ToolTip.visible: cell.hovered && (cell.events.length > 0 || (cell.sub.length > 4))
                    PC3.ToolTip.text: {
                        let parts = []
                        if (cell.sub.length > 4) parts.push(cell.sub)
                        parts = parts.concat(cell.events)
                        return parts.join("\n")
                    }
                    PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }
    }

    // open the system's default calendar application (text/calendar handler)
    P5Support.DataSource {
        id: runner
        engine: "executable"
        onNewData: source => disconnectSource(source)
        function run(cmd) { connectSource(cmd) }
    }
    function openCalendarApp() {
        const custom = String(host.cfg.calendarApp || "").trim()
        if (custom.length) { runner.run(custom) }
        else runner.run('d=$(xdg-mime query default text/calendar); p=$(find /usr/share/applications "$HOME/.local/share/applications" -name "$d" 2>/dev/null | head -1); if [ -n "$p" ]; then kioclient exec "$p"; else app=$(find /usr/share/applications -iname "*korganizer*" -o -iname "*merkuro*calendar*" -o -iname "*gnome-calendar*" 2>/dev/null | head -1); [ -n "$app" ] && kioclient exec "$app"; fi')
        if (kickoff.hideOnWindowDeactivate) kickoff.expanded = false
    }

    // ── settings ──
    Component {
        id: settings
        ColumnLayout {
            id: se
            property var host
            spacing: Kirigami.Units.largeSpacing
            property Item pluginUi: null
            property int pluginRow: -1

            function persist() { host.setCfg("plugins", plugins.enabledPlugins) }

            PC3.Label { text: i18n("Show on the calendar"); font.weight: Font.DemiBold }
            Repeater {
                model: plugins.model
                delegate: ColumnLayout {
                    id: prow
                    required property var model
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        QQC2.CheckBox {
                            text: prow.model.display
                            checked: prow.model.checked === true
                            onToggled: {
                                prow.model.checked = checked
                                // enabledPlugins updates after the model settles
                                Qt.callLater(se.persist)
                            }
                            Layout.fillWidth: true
                        }
                        PC3.ToolButton {
                            icon.name: "configure"
                            visible: !!prow.model.configUi
                            checkable: true
                            checked: se.pluginRow === prow.index
                            onClicked: {
                                // close any open config first (saving it)
                                if (se.pluginUi) { if (se.pluginUi.saveConfig) se.pluginUi.saveConfig(); se.pluginUi.destroy(); se.pluginUi = null }
                                if (se.pluginRow === prow.index) { se.pluginRow = -1; Qt.callLater(function() { se.persist(); cal.reapply() }); return }
                                const c = Qt.createComponent(prow.model.configUi)
                                if (c.status === Component.Ready) {
                                    se.pluginUi = c.createObject(pluginHolder, { width: pluginHolder.width })
                                    se.pluginRow = prow.index
                                } else {
                                    console.warn("calendar plugin config:", c.errorString())
                                    se.pluginRow = -1
                                }
                            }
                            Accessible.name: i18n("Configure %1", prow.model.display)
                            PC3.ToolTip.text: i18n("Configure %1", prow.model.display); PC3.ToolTip.visible: hovered
                        }
                    }
                }
            }
            PC3.Label {
                text: i18n("Holidays and the alternate calendar only show something after you open their ⚙ settings and pick a country/region or calendar system.")
                opacity: 0.65; font.pointSize: Kirigami.Theme.smallFont.pointSize; wrapMode: Text.Wrap; Layout.fillWidth: true
            }

            Item {
                id: pluginHolder
                Layout.fillWidth: true
                Layout.preferredHeight: se.pluginUi ? Math.min(se.pluginUi.implicitHeight, Kirigami.Units.gridUnit * 18) : 0
                clip: true
                onWidthChanged: if (se.pluginUi) se.pluginUi.width = width
            }
            PC3.Button {
                visible: se.pluginUi !== null
                text: i18n("Apply plugin settings")
                icon.name: "dialog-ok-apply"
                onClicked: {
                    if (se.pluginUi && se.pluginUi.saveConfig) se.pluginUi.saveConfig()
                    if (se.pluginUi) { se.pluginUi.destroy(); se.pluginUi = null }
                    se.pluginRow = -1
                    Qt.callLater(function() { se.persist(); cal.reapply() })
                }
            }
            Component.onDestruction: {
                if (se.pluginUi && se.pluginUi.saveConfig) se.pluginUi.saveConfig()
                cal.reapply()
            }

            Kirigami.Separator { Layout.fillWidth: true }
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
                    placeholderText: i18n("automatic (system default)")
                    text: host.cfg.calendarApp || ""
                    onEditingFinished: host.setCfg("calendarApp", text.trim())
                }
            }
        }
    }
}
