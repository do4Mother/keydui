#!/usr/bin/env bash
# Removes what install.sh put in place. Run with sudo.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root: sudo ./uninstall.sh" >&2
  exit 1
fi

rm -f /usr/bin/keydui
rm -f /usr/share/applications/dev.do4mother.keydui.desktop
rm -f /usr/share/polkit-1/actions/dev.do4mother.keydui.policy
rm -rf /usr/lib/keydui

echo "removed keydui (your /etc/keyd/default.conf was left alone)"
