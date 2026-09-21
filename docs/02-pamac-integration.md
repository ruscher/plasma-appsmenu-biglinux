# 02 · Pamac integration

Development notes. Nothing here is needed at runtime.

## What it does

When the user searches for something that is **not installed**, a "Software"
section appears under the KRunner results offering the matching package.
Choosing it opens Pamac on that package. The menu never installs anything.

```
search "scribus"
   ↓  KRunner finds no installed application
   ↓  pamac search --repos --quiet -- 'scribus'
Software
   scribus
   Not installed · Official repositories      → opens pamac-manager --details=scribus
   ↓  the user reads the package and presses Install there
```

## Environment

`pamac-cli 11.7.4`, `libpamac 11.7.4`. `pamac-manager` at `/usr/bin` (with a
wrapper at `/usr/local/bin`), both on plasmashell's `PATH`.

## Which mechanism, and why

| Candidate | Verdict |
| --- | --- |
| `krunner_appstream` runner | Rejected. It exists but is **disabled** in this user's krunnerrc, and forcing a runner the user switched off would violate "respect the configuration". It also targets Discover, not Pamac. |
| `org.manjaro.pamac.daemon` on the system bus | Rejected. Introspection shows only transaction/progress members (`DownloadPkgsFinished`, `EmitActionProgress`, `GetAuthorizationFinished`, …) — it is the privileged transaction service, with no read-only search method. |
| `pamac info` | Rejected for interactive use: **1756 ms** per call here. It is the only way to get a description, which is why suggestions show no description. |
| **`pamac search --repos --quiet`** | **Chosen.** ~205 ms, sorted by relevance, prints one package name per line. |

`pamac-manager` CLI surface as installed:

```
--updates                  Display updates
--details=PACKAGE_NAME     Display package details
--details-id=APP_ID        Display package details
--search=SEARCH            Search packages
```

`--details=` is used when there is a concrete package name (the normal case);
`openSearch()` exists for `--search=` as a fallback.

## Why `--repos`

It restricts the lookup to the official repositories, which:

- keeps **AUR** out of the per-keystroke path — no network round trip while
  typing, and no results from a source the user may not have opted into
  (`/etc/pamac.conf` here does enable AUR and Flatpak, but that is the user's
  choice for Pamac's own UI, not a licence for this menu to query them on every
  keystroke);
- makes the origin label truthful: every suggestion really is from the official
  repositories, so "Official repositories" is stated rather than guessed.

Flatpak and Snap suggestions are deliberately not offered. Nothing is invented
about a package's origin.

## Security

### The finding that shaped the design

Plasma5Support's `"executable"` engine **runs its command through a shell**.
Verified rather than assumed:

| Command handed to the engine | Result |
| --- | --- |
| `echo SAFE` | `SAFE` |
| `echo A; touch /tmp/SHELL_INJECTION_HAPPENED` | `A` — **and the file was created** |
| `echo $(id -u)` | `1000` |
| ``echo `whoami` `` | `ruscher` |

So the user's query is untrusted input heading for a shell, and must never be
interpolated raw.

### Two independent defences

1. **Allowlist** (`isSearchableQuery`). Only
   `[A-Za-z0-9 À-ɏ . _ + -]`, length 3–64, and at least one letter. Everything
   else is not escaped — the lookup is simply skipped.
2. **Quoting** (`shellQuote`). The argument is single-quoted and embedded
   quotes are escaped `'\''`, so even a mistake in (1) cannot leave the
   argument.

Package names coming back from Pamac are re-validated with
`^[a-zA-Z0-9][a-zA-Z0-9@._+-]{0,127}$` before being passed to `--details=`.

### Injection test results

Every one of these was **blocked**, and no side-effect file was ever created:

```
obs; touch /tmp/PWNED_A          obs && touch /tmp/PWNED_B
obs | tee /tmp/PWNED_C           $(touch /tmp/PWNED_D)
`touch /tmp/PWNED_E`             obs\ntouch /tmp/PWNED_F
obs' ; touch /tmp/PWNED_G ; '    ../../etc/passwd
obs > /tmp/PWNED_H               obs$IFS;touch/tmp/PWNED_I
obs\;touch /tmp/PWNED_J          obs"x
```

Legitimate queries still pass: `inkscape`, `obs studio`, `gimp`,
`área de trabalho` (accented input works). `2+2` is rejected for having no
letter — which also saves a pointless package lookup — and `ab` for being too
short.

### A bug this testing caught

The allowlist was first written with `\p{L}`/`\p{N}` and the `u` flag. **Qt's
V4 engine does not implement Unicode property escapes and silently evaluates
them to `false`**, so every query — including `inkscape` — failed the test. It
failed *closed*, so it was never unsafe, but the feature was entirely dead.
The pattern now uses explicit ranges (ASCII + Latin-1 Supplement + Latin
Extended-A). Worth remembering for any future regex in QML.

## Nothing is installed automatically

The only commands ever run are `pamac search …` (read-only) and
`pamac-manager --details=…` / `--search=…` (opens the GUI). There is no
`pacman -S`, no `pamac install`, no `sudo`, no polkit prompt raised by us.
Installation happens in Pamac, after the user decides.

## Performance

| Concern | Measure |
| --- | --- |
| Debounce | 350 ms after the last keystroke |
| Minimum query | 3 characters, and must contain a letter |
| Cost per lookup | ~205 ms, off the GUI thread (`DataSource` is asynchronous) |
| Concurrency | a `generation` counter; replies from superseded queries are dropped |
| Cache | last 40 queries → names, so backspacing costs nothing |
| Result cap | 3 suggestions |
| Probe | `command -v pamac-manager`, **once per plasmoid** |

The component lives in `main.qml` rather than in `SearchResultsPage.qml`
precisely so the probe and the cache survive the results page being destroyed
and rebuilt on every new search.

### A bug this caught

Originally the component was created per search page. Because the availability
probe is asynchronous, the first query always arrived while `available` was
still `false`, `schedule()` dropped it, and nothing ever retried — the section
never appeared. Fixed with `onAvailableChanged: schedule()` *and* by hoisting
the component so the probe happens once.

## Ordering

Suggestions are rendered in a separate block **below** the KRunner list, never
merged into it. Consequences, all of them intended:

- a package can never outrank a real local result;
- KRunner's model is not modified, wrapped or re-sorted;
- the "no matches" placeholder only appears when there is also no suggestion.

## Not shown when already installed

`SearchResultsPage.hasInstalledAppMatch` scans the merged model for a
`favoriteId` beginning with `applications:`, which `RunnerMatchesModel` sets
only for the services runner. That marker is **untranslated**, unlike the
category name ("Aplicativos" here), so the check works in any language.

Verified live: searching `inkscape` on this machine shows **no** suggestion,
because Inkscape is installed as a Flatpak and the services runner matches it.
Searching `scribus`, which is in the repositories and not installed in any
form, does show the suggestion.

## When Pamac is absent

`available` stays false, so:

- no probe result, no lookups, no processes;
- the Software section is never instantiated;
- no error message, no repeated warnings;
- the KRunner search is completely unaffected.

The plasmoid therefore still works on a non-Manjaro Plasma system. Pamac is not
a dependency of the search.

## Tested

| Case | Expected | Result |
| --- | --- | --- |
| `scribus` (in repos, not installed) | suggestion shown | PASS — "scribus · Not installed · Official repositories" |
| `inkscape` (installed via Flatpak) | no suggestion | PASS — suppressed by the installed-app gate |
| `firefox` (installed) | no suggestion | PASS |
| `2+2` | no lookup at all | PASS — rejected by the allowlist |
| click a suggestion | Pamac opens on that package | PASS — `pamac-manager --details=scribus` launched (process confirmed) |
| 12 injection payloads | no shell execution | PASS — all blocked, no files created |
