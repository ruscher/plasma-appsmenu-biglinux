# 00 — Where this stage started, and on what

## The two machines

| | developer machine | lab VM |
|---|---|---|
| host | `ruscher-big` | QEMU/virtio |
| session | **Wayland** | Wayland, switched to **X11** for one pass |
| CPU | AMD Ryzen, 16 threads (`k10temp`) | 8 vCPU, no thermal sensor |
| GPU | **two**: Radeon RX 9060 XT (Navi 44) + Radeon Vega (Cezanne) | virtio, none |
| storage | NVMe with a temperature sensor | virtual, none |
| fans | **one**, on the RX 9060 XT | none |
| screens | three (3440×1440, 3440×1440, 2560×1080) | one |
| board | 23 gadgets, 4 columns | 22 gadgets, 3 columns |
| Plasma / KF / Qt | 6.7.4 / 6.29 / 6.11.2 | same |

Two properties of the developer machine turned out to matter more than
any of the above, and neither is visible from a VM:

- **vkBasalt** is enabled as a global Vulkan layer. That is what made the
  previous stage's `QtMultimedia` alarm take plasmashell down, and it is
  why audio in this project stays out of process (`docs/gadgets-stage2/04`).
- **Do Not Disturb is on until September 2027**, with
  `NotificationSoundsMuted=true`. Every notification is suppressed and
  only kept in history. This is the whole "Wayland does not notify"
  report — see `06`.

## What KSystemStats actually exposes here

Read directly from the daemon rather than assumed (probe: a bare `qml6`
file walking `SensorTreeModel` and subscribing a `SensorDataModel`):

```
327 sensor ids · 11 of them templates · 24 with unit 1000 (°C) · 1 with unit 1004 (RPM)
```

| subsystem | ids |
|---|---|
| cpu | 135 |
| disk | 71 |
| network | 34 |
| gpu | 31 |
| pressure | 24 |
| memory | 16 |
| os | 14 |
| lmsensors | 1 |
| power | 1 |

The temperatures: `cpu/all/{average,maximum,minimum}Temperature`, sixteen
`cpu/cpuN/temperature` (all reporting the same package figure, as AMD
does), `gpu/gpu0/{temperature,temp2,temp3}` (edge, junction, mem),
`gpu/gpu1/temperature`, and `lmsensors/nvme-pci-0900/temp1`.

The single fan is `gpu/gpu0/fan1` — *"Navi 44 [Radeon RX 9060 XT]
Ventoinha 1"*, 0 RPM, maximum 3000.

### "Fans is not showing all my fans"

It is showing all the fans that exist as far as the kernel is concerned.
`/sys/class/hwmon` carries exactly one `fan1_input`, on the `amdgpu`
hwmon of the discrete card, and `sensors` agrees. The board is an ASRock
B450M Steel Legend, whose Nuvoton Super I/O chip is what would report the
CPU cooler and the case fans — and no driver for it is loaded:

```
lsmod | grep -E 'nct6|it87'   →  nothing
modinfo -n nct6775            →  .../hwmon/nct6775.ko   (available, not loaded)
```

So the gadget cannot invent them, and this stage did not load a kernel
module on the user's machine to make a screenshot look better. What the
stage did fix is everything between the daemon and the card, which was
genuinely broken (`01`), and the settings now say plainly that
motherboard fans need that driver.

## Method

Every claim here was reproduced before being fixed, and the reproductions
ran in one of three places, always named as such in the documents:

- **inside plasmashell**, through a temporary probe in the deployed copy
  that logs state to the journal (`QT_LOGGING_RULES=qml=true`), removed
  afterwards;
- **in a bare `qml6` process**, when the question was about a Qt or KDE
  API rather than about the gadget;
- **on the lab VM**, for a clean install and for X11.

Screens were captured from inside the running shell with
`Item.grabToImage`, which is the only reliable way on this compositor;
`spectacle` was used for the full desktop when the question was about
something outside the menu, such as a notification pop-up.
