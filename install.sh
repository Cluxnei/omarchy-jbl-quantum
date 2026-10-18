#!/bin/bash
# Installs the pieces a shell plugin can't: the udev rule (needs sudo) and the
# user service that talks to the dongle. Safe to re-run.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rule=/etc/udev/rules.d/70-jbl-quantum.rules
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

if [[ ${1:-} == --uninstall ]]; then
  systemctl --user disable --now jbl-quantum.service 2>/dev/null || true
  rm -f "$unit_dir/jbl-quantum.service"
  systemctl --user daemon-reload
  if [[ -f $rule ]]; then
    sudo rm -f "$rule"
    sudo udevadm control --reload
  fi
  echo "Removed service and udev rule. History kept in ~/.local/share/jbl-quantum/"
  exit 0
fi

if [[ -f $rule ]] && diff -q <(grep -v "^#" "$here/system/70-jbl-quantum.rules") <(grep -v "^#" "$rule") >/dev/null; then
  echo "==> udev rule already installed"
else
  echo "==> udev rule (sudo)"
  sudo install -m 0644 "$here/system/70-jbl-quantum.rules" "$rule"
  sudo udevadm control --reload
  sudo udevadm trigger --subsystem-match=hidraw --action=change
fi

echo "==> user service"
mkdir -p "$unit_dir"
install -m 0644 "$here/system/jbl-quantum.service" "$unit_dir/jbl-quantum.service"
chmod +x "$here/bin/jbl-quantumd"
systemctl --user daemon-reload
systemctl --user enable --now jbl-quantum.service
systemctl --user restart jbl-quantum.service

echo
echo "Done. Battery history lives in ~/.local/share/jbl-quantum/history.db"
echo "If the widget isn't on your bar yet:  omarchy plugin enable cluxnei.jbl-quantum --section right"
