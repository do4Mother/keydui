#!/usr/bin/env bash
# Installs the privileged helper and its polkit policy. Run with sudo.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root: sudo ./install.sh" >&2
  exit 1
fi

here="$(cd "$(dirname "$0")" && pwd)"

install -d -m 0755 /usr/lib/keydui
install -o root -g root -m 0755 \
  "$here/linux/packaging/keydui-apply" /usr/lib/keydui/keydui-apply
install -o root -g root -m 0644 \
  "$here/linux/packaging/dev.do4mother.keydui.policy" \
  /usr/share/polkit-1/actions/dev.do4mother.keydui.policy

echo "installed /usr/lib/keydui/keydui-apply and its polkit policy"
