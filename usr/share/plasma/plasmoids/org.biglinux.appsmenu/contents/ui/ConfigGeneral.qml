/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    ConfigGeneral — Configurações detalhadas para Home e Info
*/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    id: root

    // ─── SEÇÃO HOME ───
    Kirigami.Separator { Kirigami.FormData.label: i18n("Home Dashboard") }
    
    CheckBox {
        Kirigami.FormData.label: i18n("Recent Sections:")
        text: i18n("Show Recent Applications")
        id: showRecentSection
    }
    CheckBox {
        text: i18n("Show Recent Files")
        id: showRecentFiles
    }
    CheckBox {
        text: i18n("Show Recent Folders")
        id: showRecentFolders
    }
    
    SpinBox {
        Kirigami.FormData.label: i18n("Max Items (Apps):")
        id: recentAppsMax
        from: 1; to: 20
    }
    SpinBox {
        Kirigami.FormData.label: i18n("Max Items (Files):")
        id: recentFilesMax
        from: 1; to: 20
    }

    // ─── SEÇÃO INFO ───
    Kirigami.Separator { Kirigami.FormData.label: i18n("Info Page Widgets") }

    CheckBox {
        Kirigami.FormData.label: i18n("Visible Widgets:")
        text: i18n("Hardware Monitor (CPU, RAM, etc.)")
        id: infoShowHardwareMonitor
    }
    CheckBox {
        text: i18n("System Information (Kernel, Shell, etc.)")
        id: infoShowSystemInfo
    }
    CheckBox {
        text: i18n("Calendar & Clock")
        id: infoShowCalendar
    }
    CheckBox {
        text: i18n("Weather Information")
        id: infoShowWeather
    }
    CheckBox {
        text: i18n("Quick Links")
        id: infoShowQuickLinks
    }
    CheckBox {
        text: i18n("Phoronix News Feed")
        id: infoShowNews
    }

    // ─── OUTROS ───
    Kirigami.Separator { Kirigami.FormData.label: i18n("General Interface") }

    CheckBox {
        Kirigami.FormData.label: i18n("Aesthetics:")
        text: i18n("Use Symbolic Icons")
        id: useSymbolicIcons
    }
    
    CheckBox {
        text: i18n("Show Smart Suggestions (AI)")
        id: showSmartSection
    }
}
