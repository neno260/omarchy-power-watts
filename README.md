# Power Watts

Live power consumption bar widget for the Omarchy shell. Shows the current
total power draw (in watts) in your top bar, refreshing every ~2 seconds, with
a per-component breakdown in the hover tooltip.

Uses Intel RAPL energy counters, so it works on any Intel/AMD system that
exposes `/sys/class/powercap/*/energy_uj` — no external sensors needed.

## What it looks like

A bolt icon plus the current draw, e.g. ` 26.4W` in the bar. Hover to see the
breakdown (`psys`, `package`, `dram`, ...) per RAPL zone.

## Requirements

- Omarchy (Hyprland shell with plugin support)
- Intel RAPL exposed via `sysfs` (Intel CPUs, and AMD with kernel support):
  ```
  ls /sys/class/powercap/
  ```
  You need `intel-rapl` to be present.

## Installation

The widget consists of two parts: a root system service that reads the
RAPL counters (they are root-only on most systems) and publishes the watts,
plus the bar widget itself.

### 1. Install the monitor service

The monitor service runs as root and writes `/run/omarchy-power/watts.json`
every couple of seconds.

```bash
git clone <repo-url>
cd <repo-dir>
sudo ./install.sh
```

This copies `monitor/omarchy-power-monitor.py` to `/usr/local/bin` and
installs/enables `omarchy-power-monitor.service`.

### 2. Add the bar widget

```bash
omarchy plugin add <repo-url>
omarchy plugin enable neno.power-watts
```

The widget appears in the bar. Move it with:

```bash
omarchy bar move neno.power-watts --section right
```

## Removing

```bash
# Remove the bar widget
omarchy plugin remove neno.power-watts

# Remove the monitor service (run from the cloned repo)
sudo ./install.sh --uninstall
```

## How it works

- `omarchy-power-monitor.py` reads the RAPL `energy_uj` counters twice about a
  second apart, computes watts from the delta, and writes the result to
  `/run/omarchy-power/watts.json` (world-readable, atomically via rename).
- Prefers the `psys` (whole platform) RAPL domain when present; otherwise it
  sums the per-package zones.
- `BarWidget.qml` watches the JSON file with `FileView` (`watchChanges` +
  `atomicWrites`) and repaints whenever a new value lands.

## Troubleshooting

**Widget is empty / invisible** — the monitor isn't running or isn't publishing:

```bash
systemctl status omarchy-power-monitor
cat /run/omarchy-power/watts.json
```

**No `/sys/class/powercap/intel-rapl`** — no RAPL support on this hardware.
Nothing the widget can do; it will stay empty.

**Glyph renders as a box** — the bolt glyph (`\uf0e7`) is a Nerd Font Font
Awesome glyph; install a Nerd Font (e.g. JetBrains Mono Nerd) and make sure
Hyprland/Omarchy uses it.

## Files

```
├── BarWidget.qml            the bar widget (QML)
├── manifest.json            Omarchy plugin manifest
├── install.sh               installs/enables the monitor service (--uninstall removes it)
├── LICENSE                  MIT
└── monitor/
    ├── omarchy-power-monitor.py     root RAPL reader/publisher
    └── omarchy-power-monitor.service systemd unit
```

## License

MIT