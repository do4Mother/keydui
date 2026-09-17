#!/usr/bin/env bash
# Exercises linux/packaging/keydui-apply against a sandbox config dir
# with a stub `keyd` on PATH.
set -uo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$root/linux/packaging/keydui-apply"
fails=0

setup() {
  work="$(mktemp -d)"
  mkdir -p "$work/bin" "$work/etc"
  printf 'old = config\n' > "$work/etc/default.conf"
  printf 'new = config\n' > "$work/new.conf"
  cat > "$work/bin/keyd" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  check) [ -n "${STUB_CHECK_FAILS:-}" ] && { echo "bad config" >&2; exit 1; }; exit 0 ;;
  reload)
    if [ -n "${STUB_RELOAD_FAILS:-}" ]; then
      # Simulate a restore that will itself fail: revoke write access to the
      # live config right when the real keyd would be mid-reload, so the
      # caller's post-failure "cp backup -> conf" cannot succeed either.
      if [ -n "${STUB_BLOCK_RESTORE:-}" ] && [ -n "${KEYDUI_CONF:-}" ]; then
        chmod 000 "$KEYDUI_CONF" 2>/dev/null || true
      fi
      exit 1
    fi
    exit 0 ;;
esac
exit 0
STUB
  chmod +x "$work/bin/keyd"
  export PATH="$work/bin:$PATH"
  export KEYDUI_CONF="$work/etc/default.conf"
}

check() {
  if [ "$2" = "$3" ]; then echo "ok - $1"; else
    echo "FAIL - $1: expected [$3] got [$2]"; fails=$((fails + 1)); fi
}

setup
"$script" "$work/new.conf" >/dev/null 2>&1
check "success exits 0" "$?" "0"
check "config replaced" "$(cat "$work/etc/default.conf")" "new = config"
check "backup written" "$(cat "$work/etc/default.conf.bak")" "old = config"
check "no staging file left" "$(ls -A "$work/etc" | grep -c '^\.default')" "0"

setup
STUB_CHECK_FAILS=1 "$script" "$work/new.conf" >/dev/null 2>&1
check "invalid config exits 1" "$?" "1"
check "invalid config leaves file alone" \
  "$(cat "$work/etc/default.conf")" "old = config"

setup
STUB_RELOAD_FAILS=1 "$script" "$work/new.conf" >/dev/null 2>&1
check "failed reload exits 2" "$?" "2"
check "failed reload reverts" "$(cat "$work/etc/default.conf")" "old = config"

setup
"$script" >/dev/null 2>&1
check "missing argument exits 1" "$?" "1"

# Reload fails AND the restore-copy back to the live config also fails: the
# script cannot claim it reverted, so it must exit 4, not 2.
setup
STUB_RELOAD_FAILS=1 STUB_BLOCK_RESTORE=1 "$script" "$work/new.conf" >/dev/null 2>&1
rc=$?
chmod 644 "$work/etc/default.conf" 2>/dev/null || true
check "failed restore exits 4" "$rc" "4"

# An I/O failure during apply (not a keyd verdict) must exit 3, not 1.
# Pre-seed a writable backup file so the backup step's overwrite succeeds,
# then make the directory itself unwritable so the staging copy - which
# must create a brand-new file - fails.
setup
printf 'placeholder backup\n' > "$work/etc/default.conf.bak"
chmod 555 "$work/etc"
"$script" "$work/new.conf" >/dev/null 2>&1
rc=$?
chmod 755 "$work/etc"
check "io failure exits 3, config unchanged" \
  "$rc:$(cat "$work/etc/default.conf")" "3:old = config"

# A source path that starts with '-' must never reach keyd's own argument
# parser; the script rejects it itself before running `keyd check`.
setup
printf 'evil = config\n' > "$work/-evil.conf"
(cd "$work" && "$script" "-evil.conf") >/dev/null 2>&1
rc=$?
check "dash-prefixed source exits 1, config unchanged" \
  "$rc:$(cat "$work/etc/default.conf")" "1:old = config"

[ "$fails" -eq 0 ] || exit 1
echo "all helper tests passed"
