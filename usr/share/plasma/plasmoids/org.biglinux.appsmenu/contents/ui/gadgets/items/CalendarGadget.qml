/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Calendar — a compact month grid fed by Plasma's calendar backend and its
    event plugins (holidays, astronomical events, alternate calendars), the
    very same ones the Digital Clock uses. Days carrying an event get a small
    dot under the number and a tooltip naming it; the alternate calendar shows
    its date as a secondary number.

    Two things that are easy to get wrong and were:
      * plugins are loaded by the `enabledPlugins` property —
        populateEnabledPluginsList() only fills the config model's checkboxes;
      * events are read from `daysModel.eventsForDate()`, not from the Calendar.

    cfg: { plugins: [plugin ids], weekNumbers: bool, calendarApp: "" }
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
    // bumped whenever plugin data lands, so day tooltips re-read their events
    property int dataRev: 0
    readonly property var enabledIds: host.cfg.plugins || []

    Component.onCompleted: {
        host.accentColor = "#ef4444"
        host.settingsComponent = settings
        host.titleActions = [todayAction]
    }

    /*  Returning to the current month used to be hidden behind a click on the
        month label, which nobody discovers. It is now a real button in the
        title bar, published through the generic `titleActions` slot so the
        shared component needs no knowledge of the calendar.  */
    QQC2.Action {
        id: todayAction
        text: i18nc("@action:button jump the calendar back to the current day", "Today")
        icon.name: "go-jump-today"
        onTriggered: cal.goToToday()
    }

    /*  `today` is re-read first: the gadget may have been open across
        midnight, and resetToToday() would otherwise return to yesterday's
        month. Everything highlighting the current day is bound to `today`, so
        the selection follows without further work.  */
    function goToToday() {
        cal.today = new Date()
        backend.resetToToday()
    }
    Connections {
        target: cal.host
        function onActiveChanged() {
            if (cal.host.active) { cal.today = new Date(); backend.updateData() }
        }
    }
    Timer { interval: 60 * 60 * 1000; running: cal.host.active; repeat: true; onTriggered: cal.today = new Date() }

    // Loading the plugins is what `enabledPlugins` does — see the file header.
    PlasmaCalendar.EventPluginsManager {
        id: plugins
        enabledPlugins: cal.enabledIds
    }
    PlasmaCalendar.Calendar {
        id: backend
        days: 7
        weeks: 6
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: cal.today
        Component.onCompleted: daysModel.setPluginsManager(plugins)
    }
    // Plugin data arrives asynchronously; refresh dots and tooltips when it does.
    // DaysModel already follows the manager on its own — re-seating it here
    // would reset the very data that just arrived.
    Connections {
        target: plugins
        function onDataReady() { cal.dataRev++ }
        function onSubLabelReady() { cal.dataRev++ }
    }

    // Holidays need a region; without one the plugin has nothing to show, so
    // derive it from the system locale the first time it is switched on.
    Loader {
        id: holidayHelper
        source: Qt.resolvedUrl("CalendarHolidayRegion.qml")
        onLoaded: cal.maybeAutoDetectRegion()
    }
    property string autoRegion: ""
    function maybeAutoDetectRegion() {
        if (!holidayHelper.item) return
        const wantsHolidays = cal.enabledIds.some(p => String(p).indexOf("holiday") >= 0)
        if (!wantsHolidays || holidayHelper.item.hasRegion) return
        autoRegion = holidayHelper.item.autoDetect()
        if (autoRegion.length) backend.updateData()
    }
    onEnabledIdsChanged: Qt.callLater(cal.maybeAutoDetectRegion)

    function eventsFor(y, m, d) {
        cal.dataRev // dependency: re-read when plugin data changes
        const out = []
        try {
            const evs = backend.daysModel.eventsForDate(new Date(y, m - 1, d))
            for (let i = 0; i < evs.length; i++) {
                const t = String(evs[i].title || evs[i].description || "")
                if (t.length && out.indexOf(t) < 0) out.push(t)
            }
        } catch (e) {}
        return out
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
            Item {
                visible: cal.host.cfg.weekNumbers === true
                Layout.preferredWidth: weekColumn.width
            }
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
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // week numbers
            ColumnLayout {
                id: weekColumn
                visible: cal.host.cfg.weekNumbers === true
                Layout.fillHeight: true
                // nested Layouts default to fillWidth: true, which would let
                // this column eat the grid's width
                Layout.fillWidth: false
                Layout.preferredWidth: visible ? Kirigami.Units.gridUnit * 1.2 : 0
                Layout.maximumWidth: Layout.preferredWidth
                spacing: 0
                Repeater {
                    model: cal.host.cfg.weekNumbers === true ? backend.weeksModel : null
                    delegate: PC3.Label {
                        required property int modelData
                        text: modelData
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                        font.italic: true
                        opacity: 0.45
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
            }

            GridLayout {
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
                        readonly property int eventCount: Number(model.eventCount) || 0
                        readonly property bool isMajor: model.containsMajorEventItems === true
                        readonly property string sub: String(model.subDayLabel || model.alternateDayNumber || "")
                        readonly property string subFull: String(model.subLabel || "")
                        readonly property bool hovered: dayHover.hovered
                        readonly property var events: cell.hovered ? cal.eventsFor(model.yearNumber, model.monthNumber, model.dayNumber) : []
                        readonly property real circleSize: Math.max(16, Math.min(width * 0.92, height * 0.74, Kirigami.Units.gridUnit * 2.2))

                        Column {
                            anchors.centerIn: parent
                            spacing: 1

                            Rectangle {
                                width: cell.circleSize
                                height: cell.circleSize
                                radius: width / 2
                                color: cell.isToday ? cal.host.accent
                                     : (cell.hovered && cell.inMonth ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12) : "transparent")
                                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                                PC3.Label {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: cell.sub.length ? -Math.round(parent.height * 0.11) : 0
                                    text: cell.model.dayNumber
                                    font.pointSize: Math.max(6, Math.min(Kirigami.Theme.defaultFont.pointSize, parent.height * 0.42))
                                    font.weight: cell.isToday ? Font.Bold : Font.Normal
                                    color: cell.isToday ? "white" : Kirigami.Theme.textColor
                                    opacity: cell.inMonth ? 1 : 0.3
                                }
                                // alternate-calendar date as a small secondary number
                                PC3.Label {
                                    visible: cell.sub.length > 0 && cell.sub.length <= 4
                                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.height * 0.05 }
                                    text: cell.sub
                                    font.pointSize: Math.max(5, parent.height * 0.2)
                                    color: cell.isToday ? "white" : Kirigami.Theme.textColor
                                    opacity: cell.inMonth ? 0.65 : 0.25
                                }
                            }

                            // event dot, right under the day number
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.max(5, Math.min(7, cell.circleSize * 0.17))
                                height: width
                                radius: width / 2
                                antialiasing: true
                                opacity: cell.eventCount > 0 ? (cell.inMonth ? 1 : 0.4) : 0
                                color: cell.model.eventColor && String(cell.model.eventColor).length
                                     ? String(cell.model.eventColor)
                                     : (cell.isMajor ? cal.host.accent : Kirigami.Theme.highlightColor)
                                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                            }
                        }

                        HoverHandler { id: dayHover }
                        PC3.ToolTip.visible: cell.hovered && cell.tip.length > 0
                        PC3.ToolTip.text: cell.tip
                        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                        readonly property string tip: {
                            let parts = []
                            if (cell.subFull.length) parts.push(cell.subFull)
                            parts = parts.concat(cell.events)
                            return parts.join("\n")
                        }
                    }
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

            // A manager of its own: this one only drives the checkbox list, so
            // toggling here never fights the gadget's own enabledPlugins binding.
            PlasmaCalendar.EventPluginsManager {
                id: cfgPlugins
                Component.onCompleted: populateEnabledPluginsList(se.host.cfg.plugins || [])
            }
            function persist() { se.host.setCfg("plugins", cfgPlugins.enabledPlugins) }

            PC3.Label { text: i18n("Show on the calendar"); font.weight: Font.DemiBold }
            Repeater {
                model: cfgPlugins.model
                delegate: RowLayout {
                    id: prow
                    required property var model
                    required property int index
                    Layout.fillWidth: true
                    QQC2.CheckBox {
                        text: prow.model.display
                        checked: prow.model.checked === true
                        onToggled: {
                            prow.model.checked = checked
                            // enabledPlugins only settles after the model updates
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
                            if (se.pluginUi) {
                                if (se.pluginUi.saveConfig) se.pluginUi.saveConfig()
                                se.pluginUi.destroy(); se.pluginUi = null
                            }
                            if (se.pluginRow === prow.index) {
                                se.pluginRow = -1
                                Qt.callLater(se.refresh)
                                return
                            }
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

            // What the holiday plugin is actually using right now.
            PC3.Label {
                readonly property var names: holidayHelper.item ? holidayHelper.item.regionNames() : []
                visible: names.length > 0
                text: i18n("Holidays: %1", names.join(", "))
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            PC3.Label {
                text: i18n("The holiday region follows your system locale and can be changed with the ⚙ button. The alternate calendar needs a system picked there too.")
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                wrapMode: Text.Wrap
                Layout.fillWidth: true
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
                    Qt.callLater(se.refresh)
                }
            }
            function refresh() {
                se.persist()
                backend.updateData()
                cal.dataRev++
            }
            Component.onDestruction: {
                if (se.pluginUi && se.pluginUi.saveConfig) se.pluginUi.saveConfig()
                se.refresh()
            }

            Kirigami.Separator { Layout.fillWidth: true }
            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.CheckBox {
                    Kirigami.FormData.label: i18n("Options:")
                    text: i18n("Show week numbers")
                    checked: se.host.cfg.weekNumbers === true
                    onToggled: se.host.setCfg("weekNumbers", checked)
                }
                QQC2.TextField {
                    Kirigami.FormData.label: i18n("Calendar app:")
                    placeholderText: i18n("automatic (system default)")
                    text: se.host.cfg.calendarApp || ""
                    onEditingFinished: se.host.setCfg("calendarApp", text.trim())
                }
            }
        }
    }
}
