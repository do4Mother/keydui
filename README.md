# keydui

A small Flutter (Linux desktop) GUI for editing `/etc/keyd/default.conf`,
the config file for [keyd](https://github.com/rvaiya/keyd), a system-wide
key remapping daemon.

The app reads your current keyd mappings and lets you add, edit and remove
rows — with a "listen" mode that captures a key combo by pressing it, or
you can type a key name directly. Saving rewrites only the lines you
changed: comments, `[ids]` blocks, named layers and spacing are preserved
as they were.

## Editing a mapping

Each row has two halves, **Press** (the combination you hit) and **Send**
(what keyd produces), and both are entered the same way: tick the
modifier chips, then pick the key — by typing it or by pressing the
keyboard button and hitting the key itself. Holding modifiers during a
capture ticks their chips for you, so Ctrl+Alt+F4 can be entered by
pressing Ctrl+Alt+F4.

Keys and modifiers are shown the way they are printed on a keyboard
(`Ctrl`, `Super`, `Page Up`, `Left Arrow`); keyd's own names (`control`,
`meta`, `pageup`, `left`) are what gets written to the file. Where the
two differ for a whole chord, the row says so under the Send field:
Shift+Home is shown as `Shift + Home · writes S-home`.

A keyd action the chips cannot represent — `macro(...)`, `layer(...)`,
`command(...)`, or an AltGr `G-` prefix — keeps a plain text box and is
written exactly as typed. Use the "Use keys instead" button to go back to
chips.

## Requirements

- `keyd` must already be installed and its service running
  (`systemctl status keyd`). The app queries `keyd list-keys` for
  autocompletion and validates with `keyd check` before saving; without
  keyd installed, the key list falls back to a built-in default and a save
  attempt stops at that validation step with a message saying keyd was not
  found — nothing is written.
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
dart format --set-exit-if-changed .
./test/helper/apply_test.sh   # exercises the privileged helper in a sandbox
```

`apply_test.sh` never touches `/etc`: it runs the helper against a temp
directory with `KEYDUI_CONF` pointed inside it and a stub `keyd` on `PATH`.
