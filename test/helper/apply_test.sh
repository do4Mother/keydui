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
  reload) [ -n "${STUB_RELOAD_FAILS:-}" ] && exit 1; exit 0 ;;
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
check "no staging file left" "$(ls "$work/etc" | grep -c '^\.default')" "0"

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

[ "$fails" -eq 0 ] || exit 1
echo "all helper tests passed"
