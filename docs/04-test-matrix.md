# 04 · Test matrix

Development notes. Nothing here is needed at runtime.

Environment: BigLinux (Manjaro), Plasma **6.7.4**, KF **6.29**, Qt 6,
**Wayland**, locale **pt_BR.UTF-8**, pamac **11.7.4**, 4-monitor desktop,
plasmashell under `systemd --user`.

Method: the plasmoid was deployed to
`~/.local/share/plasma/plasmoids/org.biglinux.appsmenu` and driven inside the
real `plasmashell`. Because Wayland blocks synthetic input, UI states were
reached by temporarily injecting a driver into the *deployed* copy (never the
repository) which sets the query text and calls the same functions the buttons
call; results were written to a file and read back. Model-level checks used an
offscreen `qml6` harness.

Only rows actually executed are marked PASS.

## A · Search results (offscreen `Kicker.RunnerModel` harness)

| Query | Expected | Obtained | Status |
| --- | --- | --- | --- |
| `firefox` | installed app | `Navegador Firefox` — Web Browser | PASS |
| `2+2` | calculator answer present | `4` under **Calculadora** | PASS |
| `10*25` | 250 | `250` | PASS |
| `100/4` | 25 | `25` | PASS |
| `sqrt(144)` | 12 | `12` | PASS |
| `2^10` | 1024 | `1024` | PASS |
| `(15+5)*3` | 60 | `60` | PASS |
| `1 l em ml` | 1000 ml | `1.000 mililitros (ml)` | PASS |
| `2 litros em ml` | 2000 ml | `2.000 mililitros (ml)` | PASS |
| `5 m em cm` | 500 cm | `500 centímetros (cm)` | PASS |
| `100 km em mi` | miles | `62,1373 milhas (mi)` (+nmi, mm, mil) | PASS |
| `30 C em F` | 86 °F | `86 graus Fahrenheit (°F)` | PASS |
| `1 GB em MB` | 1000 MB | `1.000 megabytes (MB)` | PASS |
| `10 kg em g` | 10000 g | `10.000 gramas (g)` | PASS |
| `1 l in ml` | no conversion (English keyword on a pt_BR system) | web-search fallback only | PASS (expected) |
| `display` | settings + apps | 20 rows incl. `Configurações da tela` | PASS |
| `network` | broad results | 58 rows across several runners | PASS |
| `Downloads` | folder / places / bookmarks | folder + bookmarks | PASS |
| `kill firefox` | shell runner | `Executar kill firefox` (Linha de comando) | PASS |
| `history` | settings + bookmarks | `Arquivos recentes`, bookmarks | PASS |

## B · Runner configuration is respected

| krunnerrc | `10*25` | Status |
| --- | --- | --- |
| `calculatorEnabled=true` | `Calculadora → 250` | PASS |
| `calculatorEnabled=false` | calculator absent | PASS |
| `calculatorEnabled=true` (restored) | `Calculadora → 250` | PASS |
| `krunner_webshortcutsEnabled=false` | web fallback absent | PASS |

krunnerrc restored byte-identical afterwards (`diff` clean).

## C · Tab navigation during a search — the reported bug

Driver calls `activateTab(n)`, which is exactly what each tab's `onClicked`
calls.

### Different tab while searching

| Step | search text | page | Status |
| --- | --- | --- | --- |
| typed `firefox` | `"firefox"` | searchView | — |
| `activateTab(0)` | `""` | **homePage** | PASS |
| typed `25*4` | `"25*4"` | searchView | — |
| `activateTab(2)` | `""` | **placesPage** | PASS |
| typed `kate` | `"kate"` | searchView | — |
| `activateTab(1)` | `""` | **allAppsPage** | PASS |

### Same tab while searching — the case that used to do nothing

| Tab | after typing | after clicking the SAME tab | Status |
| --- | --- | --- | --- |
| 0 Home | searchView, `"firefox"` | `""` · **homePage** · nav=0 | PASS |
| 1 Apps | searchView, `"firefox"` | `""` · **allAppsPage** · nav=1 | PASS |
| 2 Places | searchView, `"firefox"` | `""` · **placesPage** · nav=2 | PASS |
| 3 Info | searchView, `"firefox"` | `""` · **infoPage** · nav=3 | PASS |

### Rapid-fire stress (no waiting between actions)

```
text="abc"; activateTab(3); text="def"; activateTab(0);
text="ghi"; activateTab(2); activateTab(2)
```

| Moment | State | Status |
| --- | --- | --- |
| immediately after | `busy=true`, `pendingTab=2`, deferral engaged | PASS |
| after it settles | `search=""`, `page=placesPage`, `nav=2`, `pendingSearch=false`, `pendingTab=-1` | PASS |

No stuck transition, no crash. The `StackView.busy` deferral that exists to
avoid the known use-after-free was preserved and demonstrably used.

## D · Software suggestions (Pamac)

| Case | Expected | Obtained | Status |
| --- | --- | --- | --- |
| `scribus` (in repos, not installed) | suggestion below results | `scribus · Not installed · Official repositories` | PASS |
| `inkscape` (installed as Flatpak) | no suggestion | none — installed-app gate | PASS |
| `firefox` (installed) | no suggestion | none | PASS |
| `2+2` | no package lookup | rejected by allowlist | PASS |
| click suggestion | Pamac opens on that package | `pamac-manager --details=scribus` ran, process confirmed | PASS |
| suggestion position | never above KRunner results | separate block below the list | PASS |
| Pamac absent | search unaffected, nothing shown | `available=false` path; not exercised on a machine without Pamac | NOT TESTED (see 05) |

### Injection attempts — all blocked, no file ever created

| Payload | Result |
| --- | --- |
| `obs; touch /tmp/PWNED_A` | blocked |
| `obs && touch /tmp/PWNED_B` | blocked |
| `obs \| tee /tmp/PWNED_C` | blocked |
| `$(touch /tmp/PWNED_D)` | blocked |
| `` `touch /tmp/PWNED_E` `` | blocked |
| `obs\ntouch /tmp/PWNED_F` | blocked |
| `obs' ; touch /tmp/PWNED_G ; '` | blocked |
| `../../etc/passwd` | blocked |
| `obs > /tmp/PWNED_H` | blocked |
| `obs$IFS;touch/tmp/PWNED_I` | blocked |
| `obs\;touch /tmp/PWNED_J` | blocked |
| `obs"x` | blocked |
| `inkscape`, `obs studio`, `gimp`, `área de trabalho` | allowed (correct) |
| `2+2` (no letter), `ab` (too short) | blocked (correct) |

## E · Header / UX

| Case | Expected | Obtained | Status |
| --- | --- | --- | --- |
| Resting header | avatar · identity · compact search · actions · ⋮ | as designed (screenshot) | PASS |
| While searching | avatar+identity collapsed, field full width | as designed (screenshot) | PASS |
| Placeholder resting | `Search…` | shown | PASS |
| Placeholder searching | `Search apps, files, settings, calculations…` | shown | PASS |
| Options position | after the quick buttons | last in the row | PASS |
| Options icon | vertical kebab | `view-more-symbolic`, geometry verified as 3 dots on one `x` | PASS |
| Options label | "Options" | `i18nc(…, "Options")` | PASS |
| Category headings in results | grouped by runner | `Aplicativos`, `Calculadora`, `Palavras-chave…` | PASS |

## F · Regression

| Area | Status | Evidence |
| --- | --- | --- |
| Home (favourites, recents) | PASS | screenshot after final build |
| Apps page | PASS | reached as `allAppsPage` in the tab tests |
| Places (Computer/History/Frequently Used) | PASS | reached as `placesPage`; models unchanged |
| Info / gadgets | PASS | screenshot — clock, weather, calendar, meters all render |
| Session actions | PASS | `Kicker.SystemModel` untouched; buttons render and keep `systemFavorites` |
| Last-tab persistence | PASS | `lastTab` written by `activateTab` and by `onCurrentIndexChanged` |
| Menu open/close cycles | PASS | ~10 open/close cycles across the test runs, no failures |

## G · Quality gates

| Gate | Result |
| --- | --- |
| `qmllint` on the six changed files | no syntax errors |
| `qmllint` over the whole `contents/` tree | 0 files with syntax errors |
| `metadata.json` parses, Id intact | PASS |
| plasmashell journal, appsmenu entries | **0 warnings** from this plasmoid |
| TypeError / ReferenceError / binding loop | none from this plasmoid |
| segfault / crash | none across ~10 plasmashell restarts |

The only plasmoid warning in the journal is pre-existing and unrelated
(`OnboardingOverlay: Detected anchors on an item that is managed by a layout`,
present on `main`). The only `TypeError`s came from Plasma's own
`org.kde.plasma.brightness` applet.

## H · Not tested

| Item | Why |
| --- | --- |
| X11 session | The machine runs Wayland; switching the user's live session was too disruptive. No code added here touches `DISPLAY`/`XAUTHORITY` — the new paths are config reads, QML layout and `DataSource`, all session-agnostic. |
| Physical mouse clicks / real key presses | Wayland blocks synthetic input. Every interaction was driven through the same functions the handlers call (`activateTab(n)`, `searchField.text`, `openPackage()`), and the handler wiring was verified by inspection. |
| A machine without Pamac | Not available here. The guard is `available === false`, which is also the state during the first milliseconds of every run before the probe answers — a path that is exercised constantly. |
| Panel edges / DPI scales other than this desktop's | Layout uses `Layout.fillWidth` and grid units rather than fixed sizes, but only this configuration was observed. |
| `plasmoidviewer` | Not used: it does not reproduce KRunner/DBus/KService behaviour, and the real `plasmashell` was available and used instead. |
