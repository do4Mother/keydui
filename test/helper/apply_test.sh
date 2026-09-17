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
      # config's DIRECTORY right when the real keyd would be mid-reload, so
      # the caller's post-failure restore -- which stages a new file beside
      # the config and renames it into place -- cannot succeed either.
      # (Revoking write on the config file alone no longer blocks anything:
      # an atomic restore replaces the directory entry, not the file's
      # contents, which is the entire point of doing it that way.)
      if [ -n "${STUB_BLOCK_RESTORE:-}" ] && [ -n "${KEYDUI_CONF:-}" ]; then
        chmod 555 "$(dirname "$KEYDUI_CONF")" 2>/dev/null || true
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
chmod 755 "$work/etc" 2>/dev/null || true
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

# The revert must be atomic too: it runs precisely when something has
# already gone wrong. Prove it goes through the same staging file the
# install uses -- a truncating in-place `cp` would leave a half-written live
# config if it failed partway.
setup
cat > "$work/bin/cp" <<'CPSTUB'
#!/usr/bin/env bash
# Records every cp destination the helper asks for.
echo "$*" >> "$KEYDUI_TRACE"
exec /usr/bin/cp "$@"
CPSTUB
chmod +x "$work/bin/cp"
export KEYDUI_TRACE="$work/trace"
: > "$KEYDUI_TRACE"
STUB_RELOAD_FAILS=1 "$script" "$work/new.conf" >/dev/null 2>&1
check "revert stages instead of writing the live config in place" \
  "$(grep -c -- "$work/etc/.default.conf.new" "$KEYDUI_TRACE")" "3"
check "revert never copies straight onto the live config" \
  "$(grep -c -e "$work/etc/default.conf\$" "$KEYDUI_TRACE")" "0"
unset KEYDUI_TRACE
rm -f "$work/bin/cp"

# Concurrent runs must not interleave: two helpers share one staging path
# and one backup file. The stub marks the window in which the real helper
# has the config open; those windows must not overlap.
if command -v flock >/dev/null 2>&1; then
  setup
  export KEYDUI_TRACE="$work/trace"
  : > "$KEYDUI_TRACE"
  cat > "$work/bin/keyd" <<'SLOWSTUB'
#!/usr/bin/env bash
case "$1" in
  reload)
    echo "in" >> "$KEYDUI_TRACE"
    sleep 0.4
    echo "out" >> "$KEYDUI_TRACE"
    ;;
esac
exit 0
SLOWSTUB
  chmod +x "$work/bin/keyd"
  printf 'second = config\n' > "$work/second.conf"
  "$script" "$work/new.conf" >/dev/null 2>&1 &
  "$script" "$work/second.conf" >/dev/null 2>&1 &
  wait
  check "concurrent runs do not interleave" \
    "$(tr '\n' ' ' < "$KEYDUI_TRACE")" "in out in out "
  unset KEYDUI_TRACE
else
  echo "ok - concurrent runs do not interleave (skipped: no flock)"
fi

# A missing flock must not stop the apply: locking is defence in depth, not
# a requirement. Shadow it with a stub that reports "not found".
setup
cat > "$work/bin/flock" <<'FLOCKSTUB'
#!/usr/bin/env bash
echo "flock: broken" >&2
exit 127
FLOCKSTUB
chmod +x "$work/bin/flock"
PATH="$work/bin:$PATH" "$script" "$work/new.conf" >/dev/null 2>&1
check "apply still succeeds when flock is unavailable" \
  "$?:$(cat "$work/etc/default.conf")" "0:new = config"
rm -f "$work/bin/flock"

[ "$fails" -eq 0 ] || exit 1
echo "all helper tests passed"
