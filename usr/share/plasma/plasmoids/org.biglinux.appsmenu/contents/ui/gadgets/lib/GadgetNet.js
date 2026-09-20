/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    GadgetNet — one small networking helper shared by every online gadget:
    GET with timeout, JSON/XML/text decoding, and uniform error strings.
    Never throws; errors always arrive through the callback.

    Error strings: "timeout", "network", "http <code>", "json", "xml", "open".
*/
.pragma library

var DEFAULT_TIMEOUT_MS = 12000
var USER_AGENT = "BigLinuxAppsMenu/1.0 (KDE Plasma gadget)"

/**
 * fetch(url, options, callback)
 *   options.type: "json" | "xml" | "text" (default text)
 *   options.timeout: ms
 *   callback(error, data, xhr)
 * Returns the XMLHttpRequest (call .abort() to cancel).
 */
function fetch(url, options, callback) {
    options = options || {}
    var xhr = new XMLHttpRequest()
    var finished = false
    function finish(err, data) {
        if (finished) return
        finished = true
        try { callback(err, data, xhr) } catch (e) { console.warn("GadgetNet callback error:", e) }
    }
    try { xhr.timeout = options.timeout || DEFAULT_TIMEOUT_MS } catch (e) { /* older engines */ }
    xhr.ontimeout = function() { finish("timeout", null) }
    xhr.onerror = function() { finish("network", null) }
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return
        if (xhr.status >= 200 && xhr.status < 300) {
            if (options.type === "json") {
                try { finish(null, JSON.parse(xhr.responseText)) } catch (e) { finish("json", null) }
            } else if (options.type === "xml") {
                var doc = xhr.responseXML
                if (doc && doc.documentElement) finish(null, doc)
                else finish("xml", null)
            } else {
                finish(null, xhr.responseText)
            }
        } else if (xhr.status === 0) {
            finish("network", null)
        } else {
            finish("http " + xhr.status, null)
        }
    }
    try {
        xhr.open("GET", url)
        try { xhr.setRequestHeader("User-Agent", USER_AGENT) } catch (e) { /* not allowed on some engines */ }
        if (options.headers) {
            for (var h in options.headers) xhr.setRequestHeader(h, options.headers[h])
        }
        xhr.send()
    } catch (e) {
        finish("open", null)
    }
    return xhr
}

function fetchJson(url, callback, timeout) { return fetch(url, { type: "json", timeout: timeout }, callback) }
function fetchXml(url, callback, timeout)  { return fetch(url, { type: "xml",  timeout: timeout }, callback) }
function fetchText(url, callback, timeout) { return fetch(url, { type: "text", timeout: timeout }, callback) }

/** Human readable, translatable-by-caller description of an error string. */
function describeError(err) {
    if (!err) return ""
    if (err === "timeout") return "timeout"
    if (err === "network") return "offline"
    if (err.indexOf("http") === 0) return err
    return err
}

/** Encode an object as a query string. */
function query(params) {
    var parts = []
    for (var k in params) {
        if (params[k] === undefined || params[k] === null) continue
        parts.push(encodeURIComponent(k) + "=" + encodeURIComponent(String(params[k])))
    }
    return parts.join("&")
}

/** Cache helpers: entries are { t: <ms epoch>, v: <value> } */
function cacheFresh(entry, maxAgeMs) {
    return !!entry && typeof entry.t === "number" && (Date.now() - entry.t) < maxAgeMs && entry.v !== undefined
}
function cacheEntry(value) {
    return { t: Date.now(), v: value }
}
function cacheAge(entry) {
    return entry && typeof entry.t === "number" ? Date.now() - entry.t : Infinity
}
