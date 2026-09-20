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

// Approximate location from the public IP (only the request's IP is sent).
function locateByIp(cb) {
    Net.fetchJson("https://ipapi.co/json/", function(err, data) {
        if (err || !data || typeof data.latitude !== "number") {
            // fallback provider
            Net.fetchJson("http://ip-api.com/json/?fields=status,city,regionName,countryCode,lat,lon", function(err2, d2) {
                if (err2 || !d2 || d2.status !== "success") return cb(err || err2 || "notfound", null)
                cb(null, { lat: d2.lat, lon: d2.lon, name: d2.city + (d2.regionName ? ", " + d2.regionName : "") + " · " + d2.countryCode })
            })
            return
        }
        cb(null, { lat: data.latitude, lon: data.longitude, name: data.city + (data.region ? ", " + data.region : "") + " · " + data.country_code })
    })
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
                daily: daily, fetchedAt: Date.now()
            })
        } catch (e) {
            cb("json", null)
        }
    })
}
