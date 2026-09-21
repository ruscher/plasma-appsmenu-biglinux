# 4. Quick Links — resolve applications instead of copying their details

## What was wrong

The gadget carried its own copy of every application's name, icon name and
command:

```qml
{ name: i18n("Big Store"), icon: "bigstore", target: "big-store" }
```

`bigstore` is not an icon. Big Store installs `big-store`
(`/usr/share/icons/hicolor/scalable/apps/big-store.svg`), so that tile drew an
empty gap — the reported symptom, and exactly what copying invites. Copies of
`Exec` are worse still: they lose the entry's field codes, working directory,
terminal flag and D-Bus activation, and they cannot tell whether the
application is installed at all.

## What it does now

A link states a **desktop id**; everything else is read from the desktop entry
at runtime by a new helper, `contents/tools/desktop-entry`, in the same spirit
as the existing `recent-activity` tool:

* `desktop-entry resolve <id>…` → one TSV line per id: `id, path, Name, Icon`.
  `Name` comes back translated, because KConfig honours the caller's locale and
  plasmashell runs under the session one.
* `desktop-entry launch <id>` → `gio launch <path>`, which applies the entry's
  own `Exec` and field codes.

The defaults are BigLinux's own tools, each with `alt` equivalents to try when
the first is missing, so a machine without KCalc still gets a calculator rather
than a gap. An id that resolves nowhere is **dropped from the grid**: no dead
button, which is what the brief asked for.

Backwards compatible: a `target` that is a URL still opens in the default
handler and anything else still runs as a command line, so existing user
configuration keeps working. The settings hint now tells users they can type an
application id and let the system supply the name and icon.

## Safety

Targets come from configuration and the `executable` data engine runs commands
**through a shell**, so ids are validated on both sides. The pattern admits
letters, digits, `. _ + -` and a single `/` (BigLinux ships
`bigcontrolcenter/biglinux-settings.desktop` inside a subdirectory) and nothing
else — no quote, space or shell metacharacter can appear — and `..` is rejected
explicitly. Ids are single-quoted anyway when the command is built.

Rejected as expected: `../../../etc/passwd`, `a;id.desktop`, `$(id).desktop`,
`../x.desktop`; `launch` on an invalid id exits 2, on a missing application 3.

The free-form command field stays a command field — that is its purpose — but
control characters are now refused, since they could smuggle a second command
past what the user believes they typed.

## Test (live, on the VM, defaults restored)

All ten tiles resolved, translated, with icon names taken from the entries:

| tile | icon | source |
|---|---|---|
| Central de Controle | `bigcontrolcenter` | `bigcontrolcenter.desktop` |
| Ajustes gerais | `biglinux-settings` | `bigcontrolcenter/biglinux-settings.desktop` |
| Temas do BigLinux | `big-theme-gui` | `bigcontrolcenter/big-themes-gui.desktop` |
| Terminal Ashy | `ashyterm` | `org.communitybig.ashyterm.desktop` |
| Big Store | **`big-store`** | `big-store.desktop` |
| Adicionar e Remover WebApps | `big-webapps` | `br.com.biglinux.webapps.desktop` |
| Atualizações de programas | `system-software-update` | `pamac-updates.desktop` |
| Calculadora | `org.gnome.Calculator` | **fallback** — `org.kde.kcalc.desktop` is not installed |
| Anotações | `kate` | `org.kde.kate.desktop` |
| Gerenciador arquivos | `org.kde.dolphin` | `org.kde.dolphin.desktop` |

`effectiveCount: 10`, `resolving: false`, and `org.kde.kcalc.desktop` is
correctly absent from the resolved set — the alternative took its place.

Launching was verified for real: `desktop-entry launch org.kde.kate.desktop`
started `/usr/bin/kate -b` (the `-b` comes from the entry, not from us), and the
process was cleaned up afterwards.

**NOT TESTED:** the tiles were not clicked with a pointer (Wayland blocks
synthetic input); the launch path was exercised through the same helper the
click handler calls.
