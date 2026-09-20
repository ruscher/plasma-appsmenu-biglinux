/*
    SPDX-FileCopyrightText: 2024 BigLinux Team
    SPDX-License-Identifier: GPL-2.0-or-later

    RssParser — tolerant RSS 2.0 / Atom / RDF parser over Qt's XHR DOM.
    parse(doc, maxItems) → { title, items: [{ title, link, date, summary, image }] }
    Never throws: malformed feeds yield an empty item list.
*/
.pragma library

function localName(node) {
    var n = node.nodeName || ""
    var i = n.indexOf(":")
    return i >= 0 ? n.substring(i + 1) : n
}
function text(node) {
    if (!node) return ""
    var out = ""
    var kids = node.childNodes || []
    for (var i = 0; i < kids.length; i++) {
        var k = kids[i]
        if (k.nodeName === "#text" || k.nodeName === "#cdata-section") out += k.nodeValue || ""
    }
    return out.trim()
}
function attr(node, name) {
    if (!node || !node.attributes) return ""
    for (var i = 0; i < node.attributes.length; i++) {
        if (node.attributes[i].name === name) return node.attributes[i].value || ""
    }
    return ""
}
function child(node, name) {
    var kids = node.childNodes || []
    for (var i = 0; i < kids.length; i++) if (localName(kids[i]) === name) return kids[i]
    return null
}
function children(node, name) {
    var out = [], kids = node.childNodes || []
    for (var i = 0; i < kids.length; i++) if (localName(kids[i]) === name) out.push(kids[i])
    return out
}
function stripHtml(s) {
    return (s || "").replace(/<[^>]+>/g, " ").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/\s+/g, " ").trim()
}
function imgFromHtml(s) {
    var m = /<img[^>]+src=["']([^"']+)["']/i.exec(s || "")
    return m ? m[1] : ""
}
function parseDate(s) {
    if (!s) return null
    var d = new Date(s)
    if (!isNaN(d.getTime())) return d.getTime()
    return null
}

function parseItem(node, isAtom) {
    var item = { title: "", link: "", date: null, summary: "", image: "" }
    var kids = node.childNodes || []
    var descHtml = ""
    for (var i = 0; i < kids.length; i++) {
        var k = kids[i], n = localName(k), full = k.nodeName || ""
        if (n === "title") item.title = stripHtml(text(k))
        else if (n === "link") {
            if (isAtom) {
                var rel = attr(k, "rel")
                if ((!rel || rel === "alternate") && !item.link) item.link = attr(k, "href")
            } else item.link = text(k)
        }
        else if (n === "pubDate" || n === "published" || n === "updated" || n === "date") { if (!item.date) item.date = parseDate(text(k)) }
        else if (n === "description" || n === "summary") { if (!descHtml) descHtml = text(k) }
        else if (n === "encoded" || n === "content") { if (!descHtml || full.indexOf("content") === 0) descHtml = text(k) || descHtml }
        else if (n === "content" && full.indexOf("media") === 0) { if (!item.image && /image/.test(attr(k, "type") || "image")) item.image = attr(k, "url") }
        else if (n === "thumbnail") { if (!item.image) item.image = attr(k, "url") }
        else if (n === "enclosure") { if (!item.image && /^image/.test(attr(k, "type"))) item.image = attr(k, "url") }
        else if (n === "image") { if (!item.image) item.image = attr(k, "href") || text(k) }
        else if (n === "group") {
            var mc = child(k, "content"); if (mc && !item.image) item.image = attr(mc, "url")
            var mt = child(k, "thumbnail"); if (mt && !item.image) item.image = attr(mt, "url")
        }
    }
    // media:content may carry the tag name with prefix only; handle generic scan
    if (!item.image) {
        for (var j = 0; j < kids.length; j++) {
            var kk = kids[j]
            if ((kk.nodeName === "media:content" || kk.nodeName === "media:thumbnail") && attr(kk, "url")) { item.image = attr(kk, "url"); break }
        }
    }
    if (!item.image) item.image = imgFromHtml(descHtml)
    item.summary = stripHtml(descHtml).substring(0, 240)
    return item
}

function parse(doc, maxItems) {
    var result = { title: "", items: [] }
    try {
        var root = doc.documentElement
        if (!root) return result
        var rn = localName(root)
        var items = []
        if (rn === "feed") {                       // Atom
            result.title = stripHtml(text(child(root, "title")))
            var entries = children(root, "entry")
            for (var i = 0; i < entries.length; i++) items.push(parseItem(entries[i], true))
        } else if (rn === "rss") {                 // RSS 2.0
            var ch = child(root, "channel")
            if (ch) {
                result.title = stripHtml(text(child(ch, "title")))
                var its = children(ch, "item")
                for (var j = 0; j < its.length; j++) items.push(parseItem(its[j], false))
            }
        } else if (rn === "RDF") {                 // RSS 1.0
            var ch1 = child(root, "channel")
            if (ch1) result.title = stripHtml(text(child(ch1, "title")))
            var its1 = children(root, "item")
            for (var k = 0; k < its1.length; k++) items.push(parseItem(its1[k], false))
        }
        items = items.filter(function(it) { return it.title.length > 0 })
        if (maxItems && items.length > maxItems) items = items.slice(0, maxItems)
        result.items = items
    } catch (e) {
        console.warn("RssParser:", e)
    }
    return result
}
