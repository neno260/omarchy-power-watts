#!/usr/bin/env bash
# Install the RAPL power monitor system service required by the
# neno.power-watts bar widget. Run as root (or with sudo).
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "This installer must run as root; re-running with sudo..." >&2
  exec sudo "$0" "$@"
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -m 0755 "$DIR/monitor/omarchy-power-monitor.py" \
  /usr/local/bin/omarchy-power-monitor.py

install -m 0644 "$DIR/monitor/omarchy-power-monitor.service" \
  /etc/systemd/system/omarchy-power-monitor.service

systemctl daemon-reload
systemctl enable --now omarchy-power-monitor

echo
echo "Installed and started omarchy-power-monitor.service."
echo "It publishes wattage to /run/omarchy-power/watts.json, which the"
echo "neno.power-watts bar widget reads."
echo
echo "Next: add the bar widget:  omarchy plugin add <repo-url>"