#!/bin/bash
# Installs and starts the user service that talks to the dongle. Never uses
# sudo: the one root step (the udev rule) is printed for you to run yourself,
# with the rule text inline so what runs as root is exactly what you read.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
rule_path=/etc/udev/rules.d/70-jbl-quantum.rules
rule='KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0ecb", ATTRS{idProduct}=="2115", TAG+="uaccess"'

if [[ ${1:-} == --uninstall ]]; then
  systemctl --user disable --now jbl-quantum.service 2>/dev/null || true
  rm -f "$unit_dir/jbl-quantum.service"
  systemctl --user daemon-reload
  echo "Removed the user service. History kept in ~/.local/share/jbl-quantum/"
  [[ -f $rule_path ]] && echo "To drop the udev rule too:  sudo rm $rule_path"
  exit 0
fi

echo "==> user service"
mkdir -p "$unit_dir"
install -m 0644 "$here/system/jbl-quantum.service" "$unit_dir/jbl-quantum.service"
systemctl --user daemon-reload
systemctl --user enable jbl-quantum.service
systemctl --user restart jbl-quantum.service

# Is the dongle's HID node readable by this user?
node=""
for d in /sys/class/hidraw/hidraw*; do
  grep -qi '00000ECB:00002115' "$d/device/uevent" 2>/dev/null && node="/dev/${d##*/}" && break
done

echo
if [[ -n $node && -r $node ]]; then
  echo "Dongle found at $node and readable. All set."
else
  [[ -z $node ]] && echo "Dongle not plugged in right now; plug it in after the next step."
  echo "One root step left: allow your user to read the dongle. Run:"
  echo
  echo "  echo '$rule' | sudo tee $rule_path && sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=hidraw"
  echo
  echo "(or replug the dongle instead of the trigger)"
fi
echo
echo "History lives in ~/.local/share/jbl-quantum/history.db"
echo "If the widget isn't on your bar yet:  omarchy plugin enable cluxnei.jbl-quantum --section right"
