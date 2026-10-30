#!/usr/bin/env bash
# Undo scripts/hide.sh: unhide every package in a list.
#
# Usage: TV_HOST=<tv ip> scripts/unhide.sh lists/01-ads-telemetry.txt
set -euo pipefail
ADB=${ADB:-adb}
TV_PORT=${TV_PORT:-5555}
LIST="${1:?usage: TV_HOST=<tv ip> scripts/unhide.sh <list>}"
: "${TV_HOST:?set TV_HOST to the TV IP}"
SERIAL="$TV_HOST:$TV_PORT"
[ -r "$LIST" ] || { echo "cannot read $LIST" >&2; exit 1; }
PKGS=$(LC_ALL=C awk 'NR==1{sub(/^\357\273\277/,"")} {sub(/\r$/,""); print}' "$LIST" \
  | grep -vE '^\s*(#|$)' | sed -E 's/[[:space:]]+#.*$//' | awk '{print $1}' || true)
FAILED=0
for p in $PKGS; do
  out=$("$ADB" -s "$SERIAL" shell "pm unhide --user 0 $p" 2>&1) || true
  case "$out" in
    *"new hidden state: false"*) echo "unhidden $p";;
    *) echo "FAILED   $p: $(printf '%s' "$out" | head -n 1)"; FAILED=$((FAILED+1));;
  esac
done
echo "== unhidden, failed=$FAILED"
[ "$FAILED" -eq 0 ]
