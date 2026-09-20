/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Sports provider: TheSportsDB (https://www.thesportsdb.com), free v1 API.
    The gadget only knows the normalised shapes below; swap this file to
    change provider.

    live(sport, cb)        → cb(err, [event])     all live matches of a sport
    fixtures(leagueId, cb) → cb(err, [event])     next + recent events of a league

    event: { id, leagueId, date (ms), state: "pre"|"in"|"post", detail, clock,
             home: { name, abbr, logo, score }, away: {...} }
*/
.pragma library
.import "GadgetNet.js" as Net

var BASE = "https://www.thesportsdb.com/api/v1/json/3/"

var LEAGUES = [
    { id: "4351", name: "Brasileirão Série A",   sport: "Soccer",            icon: "⚽" },
    { id: "4480", name: "Champions League",      sport: "Soccer",            icon: "⚽" },
    { id: "4481", name: "Europa League",         sport: "Soccer",            icon: "⚽" },
    { id: "4328", name: "Premier League",        sport: "Soccer",            icon: "⚽" },
    { id: "4335", name: "La Liga",               sport: "Soccer",            icon: "⚽" },
    { id: "4332", name: "Serie A",               sport: "Soccer",            icon: "⚽" },
    { id: "4331", name: "Bundesliga",            sport: "Soccer",            icon: "⚽" },
    { id: "4334", name: "Ligue 1",               sport: "Soccer",            icon: "⚽" },
    { id: "4344", name: "Primeira Liga",         sport: "Soccer",            icon: "⚽" },
    { id: "4406", name: "Primera División (ARG)", sport: "Soccer",           icon: "⚽" },
    { id: "4346", name: "MLS",                   sport: "Soccer",            icon: "⚽" },
    { id: "4429", name: "FIFA World Cup",        sport: "Soccer",            icon: "🏆" },
    { id: "4387", name: "NBA",                   sport: "Basketball",        icon: "🏀" },
    { id: "4391", name: "NFL",                   sport: "American Football", icon: "🏈" },
    { id: "4424", name: "MLB",                   sport: "Baseball",          icon: "⚾" },
    { id: "4380", name: "NHL",                   sport: "Ice Hockey",        icon: "🏒" },
    { id: "4370", name: "Formula 1",             sport: "Motorsport",        icon: "🏎️" },
]

function leagueById(id) {
    for (var i = 0; i < LEAGUES.length; i++) if (LEAGUES[i].id === String(id)) return LEAGUES[i]
    return { id: String(id), name: String(id), sport: "Soccer", icon: "🏟️" }
}

function abbr(name) {
    var s = String(name || "").normalize("NFD").replace(/[̀-ͯ]/g, "")
    var words = s.split(/\s+/).filter(function(w) { return w.length > 2 && !/^(de|da|do|the|fc|sc|ec|cf|ac|club|clube|city|united)$/i.test(w) })
    var w = words.length ? words[0] : s
    return w.substring(0, 3).toUpperCase()
}
function ts(s) {
    if (!s) return 0
    var d = new Date(String(s).replace(" ", "T") + (String(s).indexOf("Z") < 0 && String(s).indexOf("+") < 0 ? "Z" : ""))
    return isNaN(d.getTime()) ? 0 : d.getTime()
}
function team(name, badge, score) {
    return { name: name || "?", abbr: abbr(name), logo: badge || "", score: score !== null && score !== undefined ? String(score) : "" }
}
function stateOf(status, hasScore, date) {
    var st = String(status || "").toUpperCase()
    if (/^(NS|NOT STARTED|TBD)$/.test(st) || (!st && !hasScore)) return date && date < Date.now() && hasScore ? "post" : "pre"
    if (/^(FT|AET|PEN|FINISHED|MATCH FINISHED|AOT|AP|POSTP|POSTPONED|CANC|CANCELLED|ABD)/.test(st)) return "post"
    if (/^(1H|2H|HT|ET|BT|P|LIVE|IN PROGRESS|Q[1-4]|OT|\d+)/.test(st)) return "in"
    return hasScore ? "post" : "pre"
}

function live(sport, cb) {
    Net.fetchJson(BASE + "livescore.php?s=" + encodeURIComponent(sport), function(err, d) {
        if (err) return cb(err, null)
        var out = []
        try {
            var list = (d && d.livescore) || []
            for (var i = 0; i < list.length; i++) {
                var e = list[i]
                var st = stateOf(e.strStatus, true, ts(e.strTimestamp))
                out.push({
                    id: e.idEvent, leagueId: String(e.idLeague), leagueName: e.strLeague,
                    date: ts(e.strTimestamp), state: st === "pre" ? "in" : st,
                    detail: e.strStatus || "", clock: e.strProgress ? e.strProgress + "'" : "",
                    home: team(e.strHomeTeam, e.strHomeTeamBadge, e.intHomeScore),
                    away: team(e.strAwayTeam, e.strAwayTeamBadge, e.intAwayScore)
                })
            }
        } catch (ex) { return cb("json", null) }
        cb(null, out)
    })
}

function fixtures(leagueId, cb) {
    var pending = 2, failed = null, next = [], past = []
    function done() {
        pending--
        if (pending > 0) return
        if (failed && !next.length && !past.length) return cb(failed, null)
        cb(null, next.concat(past))
    }
    function map(list, defaultState) {
        var out = []
        for (var i = 0; i < (list || []).length; i++) {
            var e = list[i]
            var hasScore = e.intHomeScore !== null && e.intHomeScore !== undefined && e.intHomeScore !== ""
            var date = ts(e.strTimestamp || (e.dateEvent + "T" + (e.strTime || "00:00:00")))
            var st = defaultState === "post" ? (hasScore ? "post" : stateOf(e.strStatus, hasScore, date)) : stateOf(e.strStatus, hasScore, date)
            out.push({
                id: e.idEvent, leagueId: String(e.idLeague), leagueName: e.strLeague,
                date: date, state: st, detail: e.strStatus || "", clock: "",
                home: team(e.strHomeTeam, e.strHomeTeamBadge, hasScore ? e.intHomeScore : null),
                away: team(e.strAwayTeam, e.strAwayTeamBadge, hasScore ? e.intAwayScore : null)
            })
        }
        return out
    }
    Net.fetchJson(BASE + "eventsnextleague.php?id=" + encodeURIComponent(leagueId), function(err, d) {
        if (err) failed = err; else try { next = map(d && d.events, "pre").filter(function(x) { return x.state !== "post" }).sort(function(a, b) { return a.date - b.date }).slice(0, 8) } catch (e) { failed = "json" }
        done()
    })
    Net.fetchJson(BASE + "eventspastleague.php?id=" + encodeURIComponent(leagueId), function(err, d) {
        if (err) failed = err; else try { past = map(d && d.events, "post").sort(function(a, b) { return b.date - a.date }).slice(0, 6) } catch (e) { failed = "json" }
        done()
    })
}
