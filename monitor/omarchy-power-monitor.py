#!/usr/bin/env python3
"""Publish live power consumption (watts) from Intel RAPL to a world-readable JSON file.

Writes to /run/omarchy-power/watts.json:
  {"watts": <float>, "components": {"psys": w, "package-0": w, "dram": w, ...}, "ts": <unix>}

Uses the "psys" (whole platform) RAPL domain when present, otherwise sums the
per-package zones. Values are sampled over a rolling window each tick.
"""

import json
import os
import time

RAPL_DIR = "/sys/class/powercap"
STATE_DIR = "/run/omarchy-power"
STATE_FILE = os.path.join(STATE_DIR, "watts.json")
TICK_SECS = 2.0
SAMPLE_SECS = 1.0
NANO = 1_000_000.0


def top_level_rapl():
    """Yield (name, path) for top-level RAPL zones (intel-rapl:N, not :N:M)."""
    try:
        names = sorted(os.listdir(RAPL_DIR))
    except OSError:
        return
    for name in names:
        parts = name.split(":")
        if len(parts) != 2 or name.startswith("intel-rapl:") is False:
            continue
        path = os.path.join(RAPL_DIR, name)
        if os.path.isfile(os.path.join(path, "energy_uj")):
            yield name, path


def read_energy_uj(path):
    try:
        with open(path, "r") as handle:
            return float(handle.read().strip())
    except (OSError, ValueError):
        return None


def collect(pairs):
    """Sample energy counters across the given RAPL zones; return {name: watts}."""
    first = {}
    for name, path in pairs:
        value = read_energy_uj(os.path.join(path, "energy_uj"))
        if value is not None:
            first[name] = value
    if not first:
        return {}

    time.sleep(SAMPLE_SECS)

    second = {}
    for name, path in pairs:
        value = read_energy_uj(os.path.join(path, "energy_uj"))
        if value is not None:
            second[name] = value

    result = {}
    for name, start in first.items():
        end = second.get(name)
        if end is not None:
            delta = end - start
            if delta < 0:
                delta += 1 << 32
            result[name] = delta / NANO / SAMPLE_SECS
    return result


def write_state(payload):
    os.makedirs(STATE_DIR, exist_ok=True)
    temp = STATE_FILE + ".tmp"
    try:
        with open(temp, "w") as handle:
            json.dump(payload, handle)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, STATE_FILE)
        os.chmod(STATE_FILE, 0o644)
    except OSError:
        pass


LABELS = {"intel-rapl:1": "psys", "intel-rapl:0": "package"}


def main():
    zones = list(top_level_rapl())
    if not zones:
        while True:
            time.sleep(TICK_SECS)
    psys = [(name, path) for name, path in zones if name == "intel-rapl:1"]
    if psys:
        zones = psys

    while True:
        tick_start = time.time()
        readings = collect(zones)
        if readings:
            total = sum(readings.values())
            components = {LABELS.get(name, name.split(":")[-1]): round(w, 1) for name, w in readings.items()}
            payload = {
                "watts": round(total, 1),
                "components": components,
                "ts": int(tick_start),
            }
            write_state(payload)
        time.sleep(max(0.0, TICK_SECS - (time.time() - tick_start)))


if __name__ == "__main__":
    main()