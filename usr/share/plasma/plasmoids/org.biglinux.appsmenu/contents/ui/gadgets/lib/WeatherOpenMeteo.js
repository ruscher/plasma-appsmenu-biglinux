/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    Weather provider: Open-Meteo (https://open-meteo.com) — free, no API key.
    Exposes: geocode(name, cb), locateByIp(cb), forecast(lat, lon, unit, cb).
    Normalised result:
      { location, temp, feels, hi, lo, code, icon, text, humidity, wind,
        isDay, daily: [{ date, hi, lo, code, icon, text }], fetchedAt }
*/
.pragma library
.import "GadgetNet.js" as Net

function iconFor(code, isDay) {
    var day = isDay !== 0
    if (code === 0) return day ? "weather-clear" : "weather-clear-night"
    if (code === 1) return day ? "weather-few-clouds" : "weather-few-clouds-night"
    if (code === 2) return day ? "weather-few-clouds" : "weather-few-clouds-night"
    if (code === 3) return "weather-many-clouds"
    if (code === 45 || code === 48) return "weather-fog"
    if (code >= 51 && code <= 57) return day ? "weather-showers-scattered-day" : "weather-showers-scattered-night"
    if (code >= 61 && code <= 67) return "weather-showers"
    if (code >= 71 && code <= 77) return "weather-snow"
    if (code >= 80 && code <= 82) return day ? "weather-showers-day" : "weather-showers-night"
    if (code === 85 || code === 86) return "weather-snow-scattered"
    if (code >= 95) return "weather-storm"
    return "weather-none-available"
}

// Returned keys are translated by the gadget via i18n(); keep them stable.
function textFor(code) {
    if (code === 0) return "Clear sky"
    if (code === 1) return "Mainly clear"
    if (code === 2) return "Partly cloudy"
    if (code === 3) return "Overcast"
    if (code === 45 || code === 48) return "Fog"
    if (code >= 51 && code <= 57) return "Drizzle"
    if (code >= 61 && code <= 67) return "Rain"
    if (code >= 71 && code <= 77) return "Snow"
    if (code >= 80 && code <= 82) return "Rain showers"
    if (code === 85 || code === 86) return "Snow showers"
    if (code === 95) return "Thunderstorm"
    if (code >= 96) return "Thunderstorm with hail"
    return "Unknown"
}

function geocode(name, cb) {
    var url = "https://geocoding-api.open-meteo.com/v1/search?" + Net.query({ name: name, count: 1, language: Qt.locale().name.split("_")[0], format: "json" })
    Net.fetchJson(url, function(err, data) {
        if (err) return cb(err, null)
        if (!data || !data.results || !data.results.length) return cb("notfound", null)
        var r = data.results[0]
        var label = r.name + (r.admin1 ? ", " + r.admin1 : "") + (r.country_code ? " · " + r.country_code : "")
        cb(null, { lat: r.latitude, lon: r.longitude, name: label, timezone: r.timezone })
    })
}

/*  Approximate location from the public IP.

    HTTPS only, on purpose: the previous fallback used cleartext
    http://ip-api.com, which puts the user's city on the wire for every device
    along the path to read. ip-api.com offers no HTTPS on its free tier, so it
    was replaced rather than upgraded. None of these providers needs an
    account or an API key, and the request body carries nothing but the IP the
    connection already reveals.

    They are tried in order with a short timeout, so one dead provider costs a
    few seconds rather than the full 12 s default.  */
var IP_PROVIDERS = [
    { url: "https://ipwho.is/", parse: function(d) {
        if (!d || d.success !== true || typeof d.latitude !== "number") return null
        return { lat: d.latitude, lon: d.longitude, name: placeLabel(d.city, d.region, d.country_code) }
    } },
    { url: "https://get.geojs.io/v1/ip/geo.json", parse: function(d) {
        if (!d) return null
        var lat = parseFloat(d.latitude), lon = parseFloat(d.longitude)
        if (isNaN(lat) || isNaN(lon)) return null
        return { lat: lat, lon: lon, name: placeLabel(d.city, d.region, d.country_code) }
    } },
    { url: "https://ipapi.co/json/", parse: function(d) {
        if (!d || typeof d.latitude !== "number") return null
        return { lat: d.latitude, lon: d.longitude, name: placeLabel(d.city, d.region, d.country_code) }
    } }
]

function placeLabel(city, region, cc) {
    var s = city || ""
    if (region && region !== city) s += (s ? ", " : "") + region
    if (cc) s += (s ? " \u00b7 " : "") + cc
    return s
}

function locateByIp(cb) {
    var i = 0
    var lastErr = null
    function attempt() {
        if (i >= IP_PROVIDERS.length) return cb(lastErr || "notfound", null)
        var p = IP_PROVIDERS[i++]
        Net.fetchJson(p.url, function(err, data) {
            if (!err) {
                var loc = p.parse(data)
                if (loc && loc.name) return cb(null, loc)
            }
            lastErr = err || "notfound"
            attempt()
        }, 6000)
    }
    attempt()
}

function forecast(lat, lon, unit, cb) {
    var params = {
        latitude: lat, longitude: lon,
        current: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m",
        daily: "weather_code,temperature_2m_max,temperature_2m_min",
        timezone: "auto", forecast_days: 5
    }
    if (unit === "f") { params.temperature_unit = "fahrenheit"; params.wind_speed_unit = "mph" }
    var url = "https://api.open-meteo.com/v1/forecast?" + Net.query(params)
    Net.fetchJson(url, function(err, d) {
        if (err) return cb(err, null)
        try {
            var c = d.current, dl = d.daily
            var daily = []
            for (var i = 0; i < dl.time.length; i++) {
                daily.push({ date: dl.time[i], hi: Math.round(dl.temperature_2m_max[i]), lo: Math.round(dl.temperature_2m_min[i]),
                             code: dl.weather_code[i], icon: iconFor(dl.weather_code[i], 1), text: textFor(dl.weather_code[i]) })
            }
            cb(null, {
                temp: Math.round(c.temperature_2m), feels: Math.round(c.apparent_temperature),
                hi: daily.length ? daily[0].hi : null, lo: daily.length ? daily[0].lo : null,
                code: c.weather_code, isDay: c.is_day, icon: iconFor(c.weather_code, c.is_day), text: textFor(c.weather_code),
                humidity: Math.round(c.relative_humidity_2m), wind: Math.round(c.wind_speed_10m),
                windUnit: unit === "f" ? "mph" : "km/h", unit: unit === "f" ? "°F" : "°C",
                unitKey: unit === "f" ? "f" : "c", lat: lat, lon: lon,
                daily: daily, fetchedAt: Date.now()
            })
        } catch (e) {
            cb("json", null)
        }
    })
}
