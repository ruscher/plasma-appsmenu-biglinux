/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Quote of the Day — a local collection (works offline); optional online
    quote via ZenQuotes when cfg.online is true.
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components 3.0 as PC3
import org.kde.kirigami 2.20 as Kirigami
import "../lib/GadgetNet.js" as Net

Item {
    id: quotes
    required property var host

    /*  Written for this project, so they carry no third-party licence and —
        unlike the quotations that used to be here — they can be translated.
        Themes follow the brief: motivation, productivity, learning,
        perseverance, creativity, free software and technology.  */
    readonly property var local: [
        { q: i18nc("motivational message shown by the Quote gadget", "A problem written down is already half understood."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Small steps taken today outrun big plans saved for tomorrow."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "The code you can delete is worth more than the code you can add."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "You do not have to be fast. You have to not stop."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Reading someone else's code is how you learn to write your own."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Every expert was once stuck on exactly what has you stuck now."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Software you are allowed to study is software you can trust."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Sharing what you built costs nothing and multiplies everything."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "The best tool is the one you actually understand."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Curiosity is a skill, and it gets stronger with use."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Finish something small today; it teaches more than starting something large."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "A bug you can reproduce is a bug you can fix."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Free software makes you a participant rather than a product."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Ask the question. Someone else is wondering the same thing."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Progress is usually the same effort applied one more time."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Write it down: memory is a poor version control system."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Understanding why beats memorising how."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "The hard part is rarely the typing."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "A system nobody can explain is a system nobody can repair."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Rest is part of the work, not an interruption of it."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Documentation is a message to the person you will be next year."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Break the problem up until the pieces stop being frightening."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Learning in the open is the fastest way to learn."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "If it is worth doing twice, it is worth automating once."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Simplicity takes longer to reach and less time to keep."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Open formats keep your work yours."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Consistency beats intensity, and it is kinder to you as well."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "The community that answers you today is the one you will answer tomorrow."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "You are allowed to build something only you will ever use."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "An error is not a failure; it is information arriving on time."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "This desktop is yours. Change it until it fits you."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Copying in order to learn is fine. Understanding in order to build is better."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Start with the boring version that works."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Two hours of thinking can save two weeks of typing."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Give the problem a name and it gets smaller."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "A first attempt is a draft, not a verdict."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Tools should adapt to people, not people to tools."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "A computer you control is a computer that serves you."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Attention is the scarcest resource you have. Spend it on purpose."), a: "" },
        { q: i18nc("motivational message shown by the Quote gadget", "Teaching something is how you find out whether you know it."), a: "" }
    ]
    /*  "local" or "online". Older configuration used a boolean, which is
        still honoured so nobody's setting is lost.  */
    readonly property string mode: host.cfg.mode ? String(host.cfg.mode)
                                                 : (host.cfg.online === true ? "online" : "local")
    readonly property bool online: mode === "online"
    property int index: 0
    /*  A literal, not a binding on `local`, so onCompleted may set it. */
    property var current: null

    Component.onCompleted: {
        host.accentColor = "#f59e0b"
        host.settingsComponent = settings
        /*  A local message is put up before anything else is attempted, so
            the card is never blank and an online failure has something to
            fall back to by construction rather than by error handling.  */
        showLocal()
        if (online) {
            fetchOnline()
        }
    }

    Connections {
        target: quotes.host
        function onCfgChanged() {
            if (quotes.online) {
                quotes.fetchOnline()
            } else {
                /*  Switching back to local used to leave the last online
                    quote on screen indefinitely. */
                quotes.host.offline = false
                quotes.showLocal()
            }
        }
    }

    /*  The same message all day, and the same one on every machine that
        shares the date — a "quote of the day" rather than a random one. */
    function showLocal() {
        const day = Math.floor(Date.now() / 86400000)
        index = day % local.length
        current = local[index]
    }
    function next() {
        index = (index + 1 + Math.floor(Math.random() * (local.length - 1))) % local.length
        current = local[index]
        pop.restart()
    }
    /*  ZenQuotes is the only online source offered. It is free, needs no
        account and answers reliably; the obvious alternatives were checked
        and rejected rather than added for the sake of a longer list —
        api.quotable.io and forismatic no longer resolve, and quotes.rest
        answers 401 without an API key, which this project does not ship.
        A single trustworthy provider is why there is no provider picker.  */
    readonly property string provider: "https://zenquotes.io/api/today"

    function fetchOnline() {
        const cached = host.cacheGet("today")
        if (Net.cacheFresh(cached, 6 * 60 * 60 * 1000)) {
            current = cached.v
            host.offline = false
            return
        }
        host.loading = true
        Net.fetchJson(provider, (err, d) => {
            host.loading = false
            if (err || !Array.isArray(d) || !d.length || !d[0].q) {
                /*  No error is shown and nothing is cleared: the local
                    message already on screen is the fallback, so an offline
                    machine simply keeps reading local ones.  */
                host.offline = true
                return
            }
            host.offline = false
            current = { q: d[0].q, a: d[0].a }
            host.cacheSet("today", Net.cacheEntry(current))
        })
    }

    SequentialAnimation {
        id: pop
        NumberAnimation { target: quoteCol; property: "opacity"; to: 0; duration: 120 }
        NumberAnimation { target: quoteCol; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: quoteCol
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        PC3.Label {
            text: "“"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.4
            font.family: "serif"
            color: quotes.host.accent
            opacity: 0.8
            Layout.preferredHeight: implicitHeight * 0.55
        }
        PC3.Label {
            text: quotes.current ? quotes.current.q : ""
            wrapMode: Text.Wrap
            font.italic: true
            font.pointSize: quotes.host.compact ? Kirigami.Theme.defaultFont.pointSize : Kirigami.Theme.defaultFont.pointSize * 1.15
            elide: Text.ElideRight
            maximumLineCount: quotes.host.compact ? 5 : 6
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignTop
        }
        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                visible: !!(quotes.current && quotes.current.a && quotes.current.a.length)
                text: quotes.current && quotes.current.a ? "— " + quotes.current.a : ""
                opacity: 0.65
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PC3.ToolButton {
                icon.name: "edit-copy"
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                onClicked: {
                        if (!quotes.current) return
                        copyHelper.text = quotes.current.a && quotes.current.a.length
                            ? "“" + quotes.current.q + "” — " + quotes.current.a
                            : quotes.current.q
                        copyHelper.selectAll(); copyHelper.copy()
                    }
                Accessible.name: i18n("Copy quote")
                PC3.ToolTip.text: i18n("Copy"); PC3.ToolTip.visible: hovered
            }
            PC3.ToolButton {
                icon.name: "view-refresh"
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                onClicked: quotes.next()
                Accessible.name: i18n("Another quote")
                PC3.ToolTip.text: i18n("Another quote"); PC3.ToolTip.visible: hovered
            }
        }
    }
    TextEdit { id: copyHelper; visible: false }

    Component {
        id: settings
        ColumnLayout {
            property var host
            spacing: Kirigami.Units.largeSpacing

            QQC2.ButtonGroup { id: sourceGroup }

            Kirigami.FormLayout {
                Layout.fillWidth: true

                QQC2.RadioButton {
                    QQC2.ButtonGroup.group: sourceGroup
                    Kirigami.FormData.label: i18n("Source:")
                    text: i18nc("@option:radio quote source", "Local collection only")
                    checked: !quotes.online
                    onToggled: if (checked) host.setCfg("mode", "local")
                }
                QQC2.RadioButton {
                    QQC2.ButtonGroup.group: sourceGroup
                    text: i18nc("@option:radio quote source", "Online, falling back to the local collection")
                    checked: quotes.online
                    onToggled: if (checked) host.setCfg("mode", "online")
                }
            }

            PC3.Label {
                text: i18np("The local collection holds %1 message written for BigLinux, so it works offline and is translated with the rest of the interface.",
                            "The local collection holds %1 messages written for BigLinux, so it works offline and is translated with the rest of the interface.",
                            quotes.local.length)
                opacity: 0.6
                wrapMode: Text.Wrap
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }
            PC3.Label {
                visible: quotes.online
                text: i18n("Online quotes come from zenquotes.io, which needs no account. If it cannot be reached, today's local message stays on screen.")
                opacity: 0.6
                wrapMode: Text.Wrap
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }
        }
    }
}
