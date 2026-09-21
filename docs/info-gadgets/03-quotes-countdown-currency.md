# 7. Quote of the Day — original content, one honest provider

## Local collection

The 24 entries that were here were famous quotations in English, hard-coded as
plain strings: not translatable, and not ours to ship. They are replaced by
**40 messages written for this project**, each wrapped in `i18nc` so they are
translated with the rest of the interface, and carrying no third-party licence
at all. The themes are the ones the brief asked for — motivation, productivity,
learning, perseverance, creativity, free software and technology:

> A problem written down is already half understood.
> The code you can delete is worth more than the code you can add.
> Software you are allowed to study is software you can trust.
> An error is not a failure; it is information arriving on time.

They have no author, so the attribution line and the "copy" action now omit the
dash instead of printing a dangling one.

The message of the day is chosen from the date, so it is stable all day and the
same on every machine sharing that date — a quote *of the day* rather than a
random one per launch.

## Online: one provider, because only one qualifies

The brief allows a choice of sources **only if** more than one stable, properly
licensed public API exists. The obvious candidates were tested rather than
assumed:

| provider | result |
|---|---|
| `zenquotes.io/api/today` | **HTTP 200** — free, no account |
| `api.quotable.io/random` | does not resolve |
| `api.forismatic.com` | does not resolve |
| `quotes.rest/qod` | HTTP 401 — needs an API key, which this project does not ship |

Only ZenQuotes qualifies, so there is no provider picker: adding dead or
key-gated services to lengthen a list is exactly what the brief warned against.

## Fallback

The setting is now a choice between **Local collection only** (default) and
**Online, falling back to the local collection**.

The fallback is structural rather than handled: a local message is put on
screen before any request is made, and an online reply only ever *replaces* it.
A failure clears nothing and shows no error — it just raises the offline badge,
so an offline machine simply keeps reading local messages. Switching back to
local restores a local message immediately; it used to leave the last online
quote up forever.

### Test (live, three configurations)

| case | result |
|---|---|
| Local only | `isLocalMessage: true`, 40 messages, no author, `offline: false` |
| Online, reachable | quote fetched from ZenQuotes (`Kahlil Gibran`), `isLocalMessage: false` |
| Online, provider unreachable | `offline: true`, `loading: false`, **`isLocalMessage: true`** — the card keeps its local message |

The third case was produced by pointing the deployed copy at an unresolvable
host; the copy was restored afterwards.

---

# 8. Countdown — "Add event" in line, and nothing thrown away silently

## Layout

`Add event` now sits on the same line as the date fields. The pair lives in a
`Flow` rather than a `RowLayout`, so the button keeps that line while there is
room for it and drops to its own line when the dialog is narrow — responsive
without a width breakpoint.

## The real problem: silent loss

Typing an event and then pressing `Done`, `Esc`, the close button, or clicking
outside threw the half-typed event away without a word.

`GadgetSettingsDialog` now offers a generic hook rather than knowing anything
about countdowns:

```qml
function tryClose() {
    if (settingsItem && typeof settingsItem.requestClose === "function") {
        settingsItem.requestClose(function() { dialog.close() })
        return
    }
    close()
}
```

A settings page that defines `requestClose(proceed)` either calls `proceed()`
immediately or asks its own question first. Pages that define nothing behave
exactly as before.

Every exit had to be routed through it, which is why `closePolicy` is now
`NoAutoClose`: `Esc` is handled by a key handler and clicking outside by a
`TapHandler` on the modal overlay, so neither can slip past the question.

The countdown page asks only when there is something to lose. `dirty` is
simply "the new-event name is not empty", which matches both rules in the
brief: an untouched form asks nothing, and a form that was just added asks
nothing either, because adding clears the field. The question offers
**Add event**, **Discard** and **Cancel**, all translatable.

### Test (live, driving the real settings page)

```
empty form:  dirty=false  proceeded=1
dirty form:  dirty=true   proceeded=1   (close was refused)
addEvent():  events 0 -> 1, dirty=false
after add:   proceeded=2                (closes without asking)
```

**NOT TESTED:** the three buttons were not clicked with a pointer (Wayland
blocks synthetic input); the close contract was driven through the same
functions those buttons call.

---

# 9. Currency — show as many as you like

## The cut

The list was a `Repeater` over `targets.filter(…).slice(0, compact ? 4 : 8)`.
Currencies past the cut were not scrolled off, they were absent.

It is now a `ListView` that scrolls vertically, with the base-currency line
staying put above it. Measured with all 29 currencies selected:
`contentHeight 522` against `height 159` — it scrolls, and all 29 are present.

## Settings

`Select all` and `Clear` were added. `Select all` deliberately excludes the
base currency, and the base's own checkbox is disabled, so the one invalid
pairing — quoting a currency against itself — is not offered at all rather
than filtered out afterwards. With nothing selected the card explains itself
instead of sitting blank, and no request is made.

## A cache bug found by the test

The first run showed the real defect: 29 currencies selected, `ratesReturned:
5`, `requestId: 0`. No request had been made at all. The cached quote was
accepted because it matched the **base**, and nothing checked whether it
covered the currencies actually on screen — so adding currencies left their
rows empty for up to an hour.

`cachedRates()` now requires the payload to contain every currency currently
shown. Adding one invalidates the cache; removing one does not, since the
payload still covers what is left.

After the fix, same configuration: `ratesReturned: 29`, `requestId: 1` — every
rate present, from a **single** request, which is what the brief asked for.

## Two smaller corrections

* The currency list is now exactly what the API publishes at `/v1/currencies`
  (30 codes, fetched and compared). The old list contained `ARS`, which
  Frankfurter does not carry, so selecting it produced a permanently blank row.
* `api.frankfurter.app` answers `301` to `api.frankfurter.dev/v1`. Qt follows
  it, so the gadget worked, but every refresh paid for a redirect; it now calls
  the canonical host.
* Requests supersede one another through a generation counter instead of being
  dropped by an `if (busy) return` guard, the same reentrancy trap described in
  `01-weather-calendar-system.md`.
