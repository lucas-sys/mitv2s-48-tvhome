#!/usr/bin/env bash
# Hide every package in a list on the TV (pm hide --user 0), one adb shell call per package, then verify.
#
# Use this on firmware where `pm disable-user` is refused for every package with a SecurityException
# (China Xiaomi TV builds are one): `pm hide` is accepted, survives a reboot and is undone with
# `pm unhide`. NOTHING is uninstalled.
#
# Usage: TV_HOST=<tv ip> scripts/hide.sh [--dry-run] lists/01-ads-telemetry.txt
# Undo:  TV_HOST=<tv ip> scripts/unhide.sh <same list>   (or scripts/restore-all.sh)
set -euo pipefail
ADB=${ADB:-adb}
TV_PORT=${TV_PORT:-5555}
DRY=0
[ "${1:-}" = "--dry-run" ] && { DRY=1; shift; }
LIST="${1:?usage: TV_HOST=<tv ip> scripts/hide.sh [--dry-run] <list>}"
: "${TV_HOST:?set TV_HOST to the TV IP, e.g. TV_HOST=<tv ip>}"
SERIAL="$TV_HOST:$TV_PORT"
adb() { "$ADB" -s "$SERIAL" "$@"; }
[ -r "$LIST" ] || { echo "cannot read $LIST" >&2; exit 1; }

PKGS=$(LC_ALL=C awk 'NR==1{sub(/^\357\273\277/,"")} {sub(/\r$/,""); print}' "$LIST" \
  | grep -vE '^\s*(#|$)' | sed -E 's/[[:space:]]+#.*$//' | awk '{print $1}' || true)
[ -n "$PKGS" ] || { echo "no package names in $LIST" >&2; exit 1; }
BAD=$(printf '%s\n' "$PKGS" | grep -vE '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$' || true)
[ -z "$BAD" ] || { echo "not a package name:"; printf '  %s\n' $BAD; exit 1; }

# Load-bearing packages: refused outright, no override. Keep this list in sync with docs/mitv2s-48.md.
KEEP_RE='^(android|mitv\.service|com\.mitv\.tvhome|com\.mstar\..*|com\.android\.(systemui|shell|phone|settings|packageinstaller|defcontainer|bluetooth|inputdevices|location\.fused|captiveportallogin|provision|managedprovisioning|proxyhandler|vpndialogs|pacprocessor|backupconfirm|keychain|certinstaller|externalstorage|documentsui|htmlviewer|providers\..*)|com\.google\.android\.webview|com\.sohu\.inputmethod\.sogou\.tv|com\.android\.inputmethod\..*|com\.xiaomi\.mitv\.settings|com\.xiaomi\.mitv\.systemui|com\.xiaomi\.mitv\.providers\.settings|com\.xiaomi\.mitv\.services|com\.xiaomi\.mitv\.tvplayer|com\.xiaomi\.mitv\.upgrade|com\.xiaomi\.tv\.appupgrade|com\.xiaomi\.mitv\.tvpush\.tvpushservice|com\.xiaomi\.mitv\.appstore|com\.xiaomi\.mitv\.smartshare|com\.xiaomi\.dlnatvservice|com\.duokan\.airkan\.tvbox|com\.svox\.pico)$'
CLASH=$(printf '%s\n' "$PKGS" | grep -E "$KEEP_RE" || true)
if [ -n "$CLASH" ]; then
  { echo "refusing $LIST: these packages keep the TV working, booting, showing Home or typing:"
    printf '%s\n' "$CLASH" | sed 's/^/  /'; echo "Nothing was changed."; } >&2
  exit 1
fi

echo "== $LIST: $(printf '%s\n' "$PKGS" | wc -l | tr -d ' ') packages on $SERIAL"
APPLIED=0; FAILED=0
for p in $PKGS; do
  if [ "$DRY" = 1 ]; then echo "would hide $p"; continue; fi
  out=$(adb shell "pm hide --user 0 $p" 2>&1) || true
  case "$out" in
    *"new hidden state: true"*) echo "hidden  $p"; APPLIED=$((APPLIED+1));;
    *) echo "FAILED  $p: $(printf '%s' "$out" | head -n 1)"; FAILED=$((FAILED+1));;
  esac
done
[ "$DRY" = 1 ] && exit 0

sleep 2
UNVERIFIED=0
for p in $PKGS; do
  st=$(adb shell "dumpsys package $p" 2>/dev/null | tr -d '\r' | grep -m1 -E 'User 0:.*hidden=' || true)
  case "$st" in
    *"hidden=true"*) :;;
    *) echo "NOT HIDDEN (check by hand): $p"; UNVERIFIED=$((UNVERIFIED+1));;
  esac
done
echo "== hidden=$APPLIED failed=$FAILED unverified=$UNVERIFIED"
[ "$FAILED" -eq 0 ] && [ "$UNVERIFIED" -eq 0 ]
