# keydui

A small Flutter (Linux desktop) GUI for editing `/etc/keyd/default.conf`,
the config file for [keyd](https://github.com/rvaiya/keyd), a system-wide
key remapping daemon.

The app reads your current keyd mappings and lets you add, edit and remove
rows — with a "listen" mode that captures a key combo by pressing it, or
you can type a key name directly. Saving rewrites only the lines you
changed: comments, `[ids]` blocks, named layers and spacing are preserved
as they were.

## Install

Release builds are published on the
[Releases page](https://github.com/do4Mother/keydui/releases) for
`x86_64` and `aarch64`.

```bash
# Debian / Ubuntu
sudo apt install ./keydui_<version>_amd64.deb

# Fedora / openSUSE
sudo dnf install ./keydui-<version>-1.x86_64.rpm

# Any distro — the tarball
tar -xzf keydui-<version>-linux-x86_64.tar.gz
cd keydui-<version>-linux-x86_64
sudo ./install.sh        # and sudo ./uninstall.sh to remove it
```

All three install the same thing: the app under `/usr/lib/keydui/app`
with a `keydui` command on your `PATH`, plus the privileged helper and
its polkit policy described below. Check the `.sha256` file next to the
download if you want to verify it.

Or build it yourself — see [Development](#development).

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
polkit policy must be installed once, up front. The `.deb`, `.rpm` and
tarball installs above already do this; when running from a source
checkout, do it yourself:

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

## Releasing

Releases are cut by hand from GitHub Actions: **Actions → Release → Run
workflow**, then give it a version like `1.2.0`. It runs the analyzer,
the tests and the helper test, builds the Linux release bundle on native
`x86_64` and `arm64` runners, packages each as a `.tar.gz`, a `.deb` and
an `.rpm` with [nfpm](https://nfpm.goreleaser.com/), and opens a draft
release tagged `v<version>` with everything attached. Publish the draft
when you're happy with it.

Package layout lives in `linux/packaging/` — `nfpm.yaml` for the
`.deb`/`.rpm`, `install-tarball.sh` for the tarball.

## License

MIT — see [LICENSE](LICENSE).
