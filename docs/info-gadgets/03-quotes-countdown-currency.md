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
