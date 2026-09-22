# 03 — Network gadget

## Before

A chart with two unlabelled lines, two numbers with arrow icons, and units
that lied: the code divided by 1024 and printed `KB/s`.

## After

**Overview** keeps the line chart (`Sparkline`, the same component Drive
Monitor uses) and adds a legend that names the series:

```
● Download   238 KiB/s
● Upload      31 KiB/s
```

The dot is in the series colour, so legend and chart cannot be read apart;
values sit in a monospace column so digits do not jitter. Units are binary and
say so — `B/s`, `KiB/s`, `MiB/s`, `GiB/s` — formatted through the locale.
Verified: `1536 → "1,5 KiB/s"`, `131072 → "128 KiB/s"`, `2.5 MiB → "2,5 MiB/s"`,
`1.2 GiB → "1,20 GiB/s"`, `0 → "0 B/s"`.

**Details** is a second tab (`GadgetTabStrip`, the same strip News and Live
Scores use). It shows the connection that carries the default route.

### Where the data comes from

Not from `/sys/class/net`, not from `nmcli`. plasma-nm's `NetworkModel`
already publishes, per active connection, a `ConnectionDetailsModel` whose
rows are sectioned and localised — exactly what Plasma's own network applet
displays. Probed live on the VM (session in pt_BR):

```
[Ethernet]
  Velocidade de conexão = 0 bit/s
  Endereço MAC = 52:54:00:C1:C6:17           (copy)
  Dispositivo = enp1s0                        (copy)
[IPv4]
  Endereço IPv4 = 192.168.132.87              (copy)
  Gateway IPv4 padrão = 192.168.132.1          (copy)
  Servidor de nomes IPv4 primário = 192.168.132.1  (copy)
```

An IPv6 section, a secondary name server, a Wi-Fi SSID and signal appear only
when the system has them; there is never a placeholder posing as a value.

### Which connection is "the" connection

`NetworkModel` marks state and type but not primacy. The pane takes the
activated connections, drops loopback (type 20) and VPNs (11, 19) — a VPN is
named on its own line instead — and with a single candidate that is the
answer. With more than one it asks NetworkManager once over D-Bus for
`PrimaryConnection`, reads that active connection's `Connection` path and
matches it against `ConnectionPathRole`. Two fixed `busctl` property reads,
triggered by model changes and debounced, no user data in the command, no
polling.

Connection types follow NetworkManagerQt's enum: Ethernet 13, Wi-Fi 14, VPN
11, WireGuard 19, Bridge 4, Bond 3, Team 15, VLAN 10, Tunnel 17, Bluetooth 2,
mobile 5/6.

### Copy

Every identifier row has an `edit-copy-symbolic` button. Its accessible name
is specific — "Copy IPv4 address", built from the row's own label — and the
icon turns into a tick for 1.4 s as feedback, with a "Copied" tooltip. Speeds
and signal levels are not offered: a value ending in `/s`, `%` or `bit/s` gets
no button.

### Settings

A title-bar action (`configure-symbolic`, "Network settings") opens System
Settings on the networking module through `KCMLauncher.openSystemSettings
("kcm_networkmanagement")` — the same call the Plasma network applet makes,
not a path to an executable.

### Cost

The details pane is a separate file (`items/network/NetworkDetails.qml`)
behind a `Loader` that is active only while its tab is shown, so the
`NetworkModel` is not kept alive for a glance at the chart; and because the
`org.kde.plasma.networkmanagement` import is isolated there, a system without
plasma-nm's QML plugin still gets the chart and a one-line explanation in the
Details tab.

## Not tested

Wi-Fi, VPN, bridge and bonding were not present on the VM (one virtio
Ethernet, no IPv6 route). The code paths exist and the type table is from the
library's enum, but they were not exercised against live hardware.
