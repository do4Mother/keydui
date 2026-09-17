# keydui

A small Flutter (Linux desktop) GUI for editing `/etc/keyd/default.conf`,
the config file for [keyd](https://github.com/rvaiya/keyd), a system-wide
key remapping daemon.

The app reads your current keyd mappings, lets you add, edit and remove
rows (with a "listen" mode that captures a key combo by pressing it, or you
can type a key name directly), and shows a preview of the resulting keyd
config before you save.

## Requirements

- `keyd` must already be installed and its service running
  (`systemctl status keyd`). The app queries `keyd list-keys` for
  autocompletion and validates with `keyd check` before saving; without
  keyd installed, the key list falls back to a built-in default and saving
  is disabled.
- Linux with polkit (for the privileged save step below).

## Privileged apply helper

Editing `/etc/keyd/default.conf` requires root. This app never runs as
root itself: it writes your edited config to a temp file, then asks
polkit (via `pkexec`) to run a small helper that copies that file into
place, backs up the previous config to
`/etc/keyd/default.conf.bak`, and reloads keyd. That helper and its
polkit policy must be installed once, up front:

```bash
sudo ./install.sh
```

This installs:

- `/usr/lib/keydui/keydui-apply` — the privileged helper script.
- `/usr/share/polkit-1/actions/dev.do4mother.keydui.policy` — the polkit
  policy that lets `pkexec` prompt for a password to run it.

Without this step, saving will fail with a message telling you to run it.

## Running the app

```bash
flutter run -d linux
```

Reading the current config on startup does not require any special
privileges; only saving does, at which point polkit will prompt for your
password.

## Development

```bash
flutter test
flutter analyze
```
