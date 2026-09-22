/*
    SPDX-FileCopyrightText: 2026 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Formula 1 provider — season calendar, race winners, drivers' and
    constructors' standings, and the next race.

    Why a provider of its own. The rest of Live Scores comes from
    TheSportsDB, which for Motorsport carries the session list of a weekend
    but no standings at all: `lookuptable.php?l=4370` answers with an empty
    document. A championship with no points table is not a championship, so
    Formula 1 gets its own source rather than a screen full of blanks.

    The source is the Ergast API as continued by jolpica-f1
    (https://api.jolpi.ca/ergast/f1/), the community successor to the
    original Ergast service, which retired at the end of 2024. It is free,
    needs no key, and answers the five questions above directly. Nothing
    here scrapes formula1.com: a page layout is not an interface, and a
    scraper would break silently on the first redesign.

    Everything is read from the API. The season is whatever `current`
    resolves to, never a year written into the code, and a field the API
    does not send is simply absent — no placeholder is invented for it.

    Requests are small and few: five endpoints, each fetched at most once
    per refresh, and the gadget caches the answers (standings change only
    after a race). jolpica asks for modest use — four requests a second,
    and a few hundred a day — which one card refreshing on a half-hour
    timer while the menu is open stays far inside.

    Shapes returned to the gadget:

      season(cb)  → { season, races: [race] }
      winners(cb) → { season, races: [race with .winner] }
      drivers(cb) → { season, round, list: [{ pos, code, name, given, family,
                                              nationality, team, teamId,
                                              points, wins }] }
      teams(cb)   → { season, list: [{ pos, name, teamId, nationality,
                                       points, wins }] }
      next(cb)    → race | null

      race: { round, name, date (ms, 0 when unknown), circuit, locality,
              country, url, sessions: [{ key, label, date }],
              winner: { name, team, teamId, laps, time } (winners only) }
*/
.pragma library
.import "GadgetNet.js" as Net

var BASE = "https://api.jolpi.ca/ergast/f1/"

/*  Team colours. These are presentation, not data: the API says which
    constructor, and this says what colour that constructor is on screen.
    An unknown id falls back to the gadget's accent, so a new team does not
    break anything — it just looks generic until this list learns it. */
var TEAM_COLOURS = {
    mercedes: "#27F4D2",
    ferrari: "#E8002D",
    red_bull: "#3671C6",
    mclaren: "#FF8000",
    aston_martin: "#229971",
    alpine: "#FF87BC",
    williams: "#64C4FF",
    rb: "#6692FF",
    alphatauri: "#6692FF",
    sauber: "#52E252",
    audi: "#52E252",
    haas: "#B6BABD",
    cadillac: "#C8A063",
    alfa: "#C92D4B",
    renault: "#FFF500"
}

/*  Nationality as Ergast spells it → the flag of that country. Used only
    to decorate a name; anything not listed simply shows no flag. */
var NATION_FLAGS = {
    British: "🇬🇧", German: "🇩🇪", Italian: "🇮🇹", French: "🇫🇷", Spanish: "🇪🇸",
    Dutch: "🇳🇱", Belgian: "🇧🇪", Finnish: "🇫🇮", Danish: "🇩🇰", Swedish: "🇸🇪",
    Monegasque: "🇲🇨", Swiss: "🇨🇭", Austrian: "🇦🇹", Australian: "🇦🇺",
    "New Zealander": "🇳🇿", Brazilian: "🇧🇷", Argentine: "🇦🇷", Mexican: "🇲🇽",
    American: "🇺🇸", Canadian: "🇨🇦", Japanese: "🇯🇵", Chinese: "🇨🇳",
    Thai: "🇹🇭", Russian: "🇷🇺", Polish: "🇵🇱", Portuguese: "🇵🇹",
    Hungarian: "🇭🇺", Indian: "🇮🇳", Indonesian: "🇮🇩", Malaysian: "🇲🇾",
    "South African": "🇿🇦", Irish: "🇮🇪", Czech: "🇨🇿", Colombian: "🇨🇴",
    Venezuelan: "🇻🇪", Chilean: "🇨🇱", Uruguayan: "🇺🇾", Bulgarian: "🇧🇬",
    Israeli: "🇮🇱", Emirati: "🇦🇪", Saudi: "🇸🇦", Qatari: "🇶🇦",
    Azerbaijani: "🇦🇿", Singaporean: "🇸🇬", Korean: "🇰🇷", Turkish: "🇹🇷",
    Greek: "🇬🇷", Norwegian: "🇳🇴", Estonian: "🇪🇪", Rhodesian: "🇿🇼",
    Liechtensteiner: "🇱🇮", "East German": "🇩🇪", Malaysian_: "🇲🇾"
}

function teamColour(id) { return TEAM_COLOURS[String(id || "").toLowerCase()] || "" }
function flagOf(nationality) { return NATION_FLAGS[String(nationality || "")] || "" }

function ts(date, time) {
    if (!date) return 0
    var iso = String(date) + "T" + (time ? String(time) : "00:00:00Z")
    if (iso.indexOf("Z") < 0 && iso.indexOf("+") < 0) iso += "Z"
    var d = new Date(iso)
    return isNaN(d.getTime()) ? 0 : d.getTime()
}

/*  The weekend's sessions, in the order they run, skipping any the API
    does not carry for that event (a sprint weekend has one set, a normal
    weekend another). */
var SESSION_KEYS = [
    { key: "FirstPractice", label: "fp1" },
    { key: "SecondPractice", label: "fp2" },
    { key: "ThirdPractice", label: "fp3" },
    { key: "SprintQualifying", label: "sq" },
    { key: "SprintShootout", label: "sq" },
    { key: "Sprint", label: "sprint" },
    { key: "Qualifying", label: "quali" }
]

function mapRace(r) {
    if (!r) return null
    var sessions = []
    for (var i = 0; i < SESSION_KEYS.length; i++) {
        var s = r[SESSION_KEYS[i].key]
        if (s && s.date) {
            sessions.push({ key: SESSION_KEYS[i].label, date: ts(s.date, s.time) })
        }
    }
    var c = r.Circuit || {}
    var loc = c.Location || {}
    return {
        round: Number(r.round) || 0,
        name: String(r.raceName || ""),
        date: ts(r.date, r.time),
        circuit: String(c.circuitName || ""),
        locality: String(loc.locality || ""),
        country: String(loc.country || ""),
        url: String(r.url || ""),
        sessions: sessions
    }
}

function get(path, cb) {
    Net.fetchJson(BASE + path, function(err, d) {
        if (err) return cb(err, null)
        if (!d || !d.MRData) return cb("json", null)
        cb(null, d.MRData)
    })
}

/** The season's calendar: every round, with its weekend sessions. */
function season(cb) {
    get("current.json?limit=100", function(err, m) {
        if (err) return cb(err, null)
        try {
            var t = m.RaceTable || {}
            var out = (t.Races || []).map(mapRace).filter(function(r) { return r })
            cb(null, { season: String(t.season || ""), races: out })
        } catch (e) { cb("json", null) }
    })
}

/** Every race that has been run, with who won it. */
function winners(cb) {
    /*  Position 1 only: the whole season's winners in one small answer
        instead of every classified car of every race. */
    get("current/results/1.json?limit=100", function(err, m) {
        if (err) return cb(err, null)
        try {
            var t = m.RaceTable || {}
            var out = []
            var races = t.Races || []
            for (var i = 0; i < races.length; i++) {
                var race = mapRace(races[i])
                var res = (races[i].Results || [])[0]
                if (res) {
                    var d = res.Driver || {}, c = res.Constructor || {}
                    race.winner = {
                        name: String(d.givenName || "") + " " + String(d.familyName || ""),
                        family: String(d.familyName || ""),
                        code: String(d.code || ""),
                        nationality: String(d.nationality || ""),
                        team: String(c.name || ""),
                        teamId: String(c.constructorId || ""),
                        laps: Number(res.laps) || 0,
                        time: res.Time && res.Time.time ? String(res.Time.time) : ""
                    }
                }
                out.push(race)
            }
            out.sort(function(a, b) { return b.round - a.round })
            cb(null, { season: String(t.season || ""), races: out })
        } catch (e) { cb("json", null) }
    })
}

function drivers(cb) {
    get("current/driverstandings.json?limit=100", function(err, m) {
        if (err) return cb(err, null)
        try {
            var t = m.StandingsTable || {}
            var lists = t.StandingsLists || []
            if (!lists.length) return cb(null, { season: String(t.season || ""), round: 0, list: [] })
            var L = lists[0]
            var out = (L.DriverStandings || []).map(function(s) {
                var d = s.Driver || {}, c = (s.Constructors || [])[0] || {}
                return {
                    pos: Number(s.position) || 0,
                    code: String(d.code || ""),
                    given: String(d.givenName || ""),
                    family: String(d.familyName || ""),
                    name: String(d.givenName || "") + " " + String(d.familyName || ""),
                    nationality: String(d.nationality || ""),
                    team: String(c.name || ""),
                    teamId: String(c.constructorId || ""),
                    points: Number(s.points) || 0,
                    wins: Number(s.wins) || 0
                }
            })
            cb(null, { season: String(L.season || t.season || ""), round: Number(L.round) || 0, list: out })
        } catch (e) { cb("json", null) }
    })
}

function teams(cb) {
    get("current/constructorstandings.json?limit=100", function(err, m) {
        if (err) return cb(err, null)
        try {
            var t = m.StandingsTable || {}
            var lists = t.StandingsLists || []
            if (!lists.length) return cb(null, { season: String(t.season || ""), list: [] })
            var L = lists[0]
            var out = (L.ConstructorStandings || []).map(function(s) {
                var c = s.Constructor || {}
                return {
                    pos: Number(s.position) || 0,
                    name: String(c.name || ""),
                    teamId: String(c.constructorId || ""),
                    nationality: String(c.nationality || ""),
                    points: Number(s.points) || 0,
                    wins: Number(s.wins) || 0
                }
            })
            cb(null, { season: String(L.season || t.season || ""), list: out })
        } catch (e) { cb("json", null) }
    })
}

/** The next race, or null once the season is over. */
function next(cb) {
    get("current/next.json", function(err, m) {
        if (err) return cb(err, null)
        try {
            var races = (m.RaceTable || {}).Races || []
            cb(null, races.length ? mapRace(races[0]) : null)
        } catch (e) { cb("json", null) }
    })
}
