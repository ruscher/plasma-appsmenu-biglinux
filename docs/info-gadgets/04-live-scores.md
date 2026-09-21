# 10. Live Scores — a score that is actually in the middle

## Why the score drifted

Each row was `Team | score | Team` with both team columns as plain
`Layout.fillWidth` items. A `RowLayout` gives every filling item its implicit
width first and shares only the remainder, so two columns whose contents differ
in length end up different widths — and the pill between them is wherever
that leaves it, not in the middle.

Both columns now carry `Layout.preferredWidth: 0` (and `minimumWidth: 0`), so
they start from the same base, split the remainder evenly, and stay symmetric
whatever the names are.

Measured in the running gadget on a 444 px row, with deliberately lopsided
fixtures:

| row | before | after |
|---|---|---|
| `Sport Club Internacional de Porto Alegre` vs `Vasco` | **107 px off centre** | **0** |
| `Ajax` vs `Borussia Moenchengladbach Football Club` | **117 px off centre** | **0** |
| `Flamengo` vs `Palmeiras` | 1 px | **0** |

## Logos and names

Badges grow from 16 px to 22 px, and to 32 px on a wide card — moderate, as
asked. The logo occupies a **fixed slot** whether or not a badge exists, so
rows line up either way, and a missing or failed badge falls back to the team's
abbreviation in a circle instead of collapsing the row. Names elide to one line
and carry a tooltip with the full name, shown only when the label is actually
truncated. The match list scrolls vertically.

## Configuration

The league picker was a `Flow`, which left ragged rows and pushed the last
leagues out of view. It is a `GridLayout` whose column count comes from the
real width — verified by building the page at three widths and reading back
what it chose:

| width | columns |
|---|---|
| 34 grid units | **3** |
| 22 grid units | **2** |
| 12 grid units | **1** |

The dialog already scrolls vertically, so a long list stays reachable, and the
last league cannot be unticked — following nothing would only produce a blank
card.

Two settings were added:

* **Refresh live scores** — 30 s / 1 min / 2 min / 5 min, defaulting to a
  minute. 30 s is the floor offered, out of respect for a free API.
* **Notify me about live matches** — kick-off, goals and full time.

## Notifications, and their limit

State is compared between polls and a notification is sent only on a change,
so the same goal is never announced twice. When notifications are off the state
is still tracked, so switching them on does not immediately announce matches
that were already running.

The limitation is stated in the settings, in the user's own language: alerts
can only be noticed **while the Info page is open**. Nothing here runs in the
background, and adding a daemon purely for score alerts is not a trade this
project makes — which is exactly the choice the brief asked to document rather
than paper over.

## What the free API actually provides

Checked rather than assumed, because the brief forbids listing sports without
working data:

| endpoint | result |
|---|---|
| `livescore.php?s=Soccer` | 31 live matches |
| `…Basketball` | 3 |
| `…American Football` | 14 |
| `…Baseball` | 2 |
| `…Ice Hockey` | 11 |
| `…Motorsport` | **no live feed** (fixtures still work) |
| `eventsnextleague.php` | **one** upcoming fixture per league — a free-tier cap |
| API v2 `livescore` | HTTP 400, needs a paid key |

Every sport in the list has working data except Motorsport, which has fixtures
but no live feed, and the FIFA World Cup entry, which is empty outside a
tournament. No sports were added: the API's usable sports were already all
represented, and padding the list was explicitly ruled out.

**NOT TESTED:** the notifications were not observed firing against a real goal
— that needs a match to score while the page is open. The change-detection
logic was exercised, but the end-to-end alert is reported as untested rather
than claimed.
