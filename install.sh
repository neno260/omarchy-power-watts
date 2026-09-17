#!/usr/bin/env bash
# Install or remove the RAPL power monitor system service required by the
# neno.power-watts bar widget. Run as root (or with sudo).
#
#   sudo ./install.sh            install + enable the monitor service
#   sudo ./install.sh --uninstall stop + remove the monitor service
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "This installer must run as root; re-running with sudo..." >&2
  exec sudo "$0" "$@"
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

remove_service() {
  systemctl disable --now omarchy-power-monitor 2>/dev/null || true
  rm -f /etc/systemd/system/omarchy-power-monitor.service
  rm -f /usr/local/bin/omarchy-power-monitor.py
  systemctl daemon-reload
  echo
  echo "Removed omarchy-power-monitor.service and its script."
  echo "Remove the bar widget with:  omarchy plugin remove neno.power-watts"
}

if [ "${1:-}" = "--uninstall" ]; then
  remove_service
  exit 0
fi

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