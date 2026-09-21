/*
    SPDX-FileCopyrightText: 2026 BigLinux Team

    SPDX-License-Identifier: GPL-2.0-or-later

    SoftwareSearch — suggests software from the official repositories when the
    user searches for something that is not installed, and hands the chosen
    package to Pamac. It never installs anything itself: clicking a suggestion
    opens Pamac on that package so the user reviews and confirms there.

    Optional by design. When pamac-manager is missing (any non-Manjaro Plasma
    system) `available` stays false, nothing is queried and nothing is shown —
    the KRunner search is untouched.

    ── Security ───────────────────────────────────────────────────────────────
    Plasma5Support's "executable" engine runs its command through a SHELL. That
    was verified, not assumed: feeding it `echo A; touch /tmp/x` really does
    create the file, and `$(…)` and backticks are expanded. The search term
    comes from the user, so it is untrusted input and must never reach that
    engine unguarded. Two independent defences are used:

      1. isSearchableQuery() — an allowlist. Only letters, digits, spaces and
         the few characters that occur in package names get through. Every
         shell metacharacter (; & | $ ` ( ) < > ' " \ newline …) fails the test
         and the lookup is simply skipped.
      2. shellQuote() — single-quotes the argument anyway and escapes embedded
         quotes, so even a mistake in (1) cannot break out of the argument.

    Package names taken from Pamac's own output are re-validated against a
    stricter pattern before being passed back to Pamac.

    ── Cost ───────────────────────────────────────────────────────────────────
    `pamac search --repos --quiet` costs about 200 ms here and sorts by
    relevance. `pamac info`, which is the only way to get a description, costs
    about 1.7 s, so descriptions are deliberately not fetched — the package
    name plus its origin is what a suggestion shows.

    `--repos` also keeps AUR out of it: no network round trip per keystroke,
    and no results from a source the user may not have opted into.
*/

import QtQuick 2.15
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: root

    visible: false

    /* The user's raw query. Set it and forget it; everything below is
       debounced, cancellable and cached. */
    property string query: ""

    /* False until pamac-manager is found, and whenever it is missing. */
    property bool available: false

    /* Set by the search page: while an installed application already matches
       the query there is nothing to suggest, so no lookup is made at all. */
    property bool suppressed: false

    /* Package names, best match first. */
    property var packages: []

    readonly property int count: root.packages.length

    /* True only while a lookup is in flight and nothing is cached yet, so the
       UI can stay quiet for the common instant case. */
    property bool busy: false

    /* At most this many suggestions; they are an aside, not the main results. */
    readonly property int maxResults: 3

    readonly property int debounceInterval: 350
    readonly property int minimumQueryLength: 3

    /* Responses are matched against this. Anything older is a stale reply from
       a query the user has already moved on from, and is dropped. */
    property int generation: 0

    /* Small query → names cache. Repeated backspacing is free. */
    property var cache: ({})
    readonly property int maxCacheEntries: 40

    onQueryChanged: root.schedule()
    onSuppressedChanged: root.schedule()
    /* The availability probe is asynchronous, so the first query usually
       arrives while `available` is still false. Without this the lookup would
       be dropped and never retried. */
    onAvailableChanged: root.schedule()

    /* Only plain words reach the shell. Requiring at least one letter also
       skips arithmetic and unit conversions, which are never package names.

       Written with explicit ranges rather than \p{L}/\p{N}: Qt's V4 engine
       does not implement Unicode property escapes and silently evaluates them
       to false, which made every query — including "inkscape" — fail this
       test. Fail-closed, so it was never unsafe, but it did disable the
       feature entirely. The ranges below cover ASCII plus Latin-1 Supplement
       and Latin Extended-A, i.e. accented Portuguese input. */
    readonly property var allowedQueryPattern: /^[A-Za-z0-9À-ɏ ._+-]{3,64}$/
    readonly property var containsLetterPattern: /[A-Za-zÀ-ɏ]/

    function isSearchableQuery(text) {
        return root.allowedQueryPattern.test(text) && root.containsLetterPattern.test(text)
    }

    /* Package names as Pamac prints them. */
    function isPackageName(name) {
        return /^[a-zA-Z0-9][a-zA-Z0-9@._+-]{0,127}$/.test(name)
    }

    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\\''") + "'"
    }

    function clear() {
        if (root.packages.length > 0) {
            root.packages = []
        }
        root.busy = false
    }

    function schedule() {
        debounce.stop()
        /* Any in-flight reply is now stale. */
        root.generation++

        const text = root.query.trim()

        if (!root.available || root.suppressed
                || text.length < root.minimumQueryLength
                || !root.isSearchableQuery(text)) {
            root.clear()
            return
        }

        const cached = root.cache[text]
        if (cached !== undefined) {
            root.packages = cached
            root.busy = false
            return
        }

        root.busy = true
        debounce.restart()
    }

    function remember(text, names) {
        const keys = Object.keys(root.cache)
        if (keys.length >= root.maxCacheEntries) {
            delete root.cache[keys[0]]
        }
        root.cache[text] = names
    }

    /* Open Pamac on one package so the user can read it and decide. */
    function openPackage(name) {
        if (!root.available || !root.isPackageName(name)) {
            return
        }
        launcher.connectSource("pamac-manager --details=" + root.shellQuote(name))
    }

    /* Fallback when there is no single obvious package: Pamac's own search. */
    function openSearch(text) {
        if (!root.available || !root.isSearchableQuery(text)) {
            return
        }
        launcher.connectSource("pamac-manager --search=" + root.shellQuote(text))
    }

    Timer {
        id: debounce
        interval: root.debounceInterval
        onTriggered: {
            const text = root.query.trim()
            if (!root.available || root.suppressed || !root.isSearchableQuery(text)) {
                root.clear()
                return
            }
            finder.run(text, root.generation)
        }
    }

    /* Is Pamac here at all? One fixed command, no user input. */
    Plasma5Support.DataSource {
        id: probe
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            root.available = String(data["stdout"] || "").trim().length > 0
        }
    }

    Plasma5Support.DataSource {
        id: finder
        engine: "executable"
        connectedSources: []

        /* The query this source was started for, so a reply can be matched
           back to it without parsing the command string. */
        property string pendingQuery: ""
        property int pendingGeneration: -1

        function run(text, generation) {
            if (connectedSources.length > 0) {
                /* Abandon the previous lookup; its reply will be dropped by
                   the generation check below. */
                connectedSources = []
            }
            finder.pendingQuery = text
            finder.pendingGeneration = generation
            connectSource("pamac search --repos --quiet -- " + root.shellQuote(text))
        }

        onNewData: (source, data) => {
            disconnectSource(source)

            if (finder.pendingGeneration !== root.generation) {
                return // the user has typed on; this answer is for an old query
            }

            const names = String(data["stdout"] || "")
                .split("\n")
                .map(line => line.trim())
                .filter(name => name.length > 0 && root.isPackageName(name))
                .slice(0, root.maxResults)

            root.remember(finder.pendingQuery, names)
            root.packages = names
            root.busy = false
        }
    }

    Plasma5Support.DataSource {
        id: launcher
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }

    Component.onCompleted: probe.connectSource("command -v pamac-manager")
}
