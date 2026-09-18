#!/usr/bin/env bash
# Installs keydui from the release tarball. Run with sudo from the
# unpacked directory: sudo ./install.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root: sudo ./install.sh" >&2
  exit 1
fi

here="$(cd "$(dirname "$0")" && pwd)"

install -d -m 0755 /usr/lib/keydui
rm -rf /usr/lib/keydui/app
cp -a "$here/app" /usr/lib/keydui/app
chown -R root:root /usr/lib/keydui/app

install -o root -g root -m 0755 "$here/keydui-apply" /usr/lib/keydui/keydui-apply
install -o root -g root -m 0644 \
  "$here/dev.do4mother.keydui.policy" \
  /usr/share/polkit-1/actions/dev.do4mother.keydui.policy
install -d -m 0755 /usr/share/applications
install -o root -g root -m 0644 \
  "$here/dev.do4mother.keydui.desktop" \
  /usr/share/applications/dev.do4mother.keydui.desktop
ln -sf /usr/lib/keydui/app/keydui /usr/bin/keydui

echo "installed keydui; run it with 'keydui'"
