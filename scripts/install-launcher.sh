#!/usr/bin/env bash
# Install the ported launcher on the TV. Usage:
#   TV_HOST=<tv ip> scripts/install-launcher.sh <apk> [--take-home]
#
# Without --take-home the APK is only installed: the stock Xiaomi launcher stays Home and the new one can
# be opened from 我的应用 first. --take-home hides com.mitv.tvhome so HOME resolves to com.gathin.tvhome;
# that is the only way on this firmware, and it is undone with one `pm unhide` (printed at the end).
set -euo pipefail
APK="${1:?usage: TV_HOST=<tv ip> scripts/install-launcher.sh <apk> [--take-home]}"
TAKE=0
[ "${2:-}" = "--take-home" ] && TAKE=1
ADB=${ADB:-adb}
TV_PORT=${TV_PORT:-5555}
: "${TV_HOST:?set TV_HOST to the TV IP}"
SERIAL="$TV_HOST:$TV_PORT"
adb() { "$ADB" -s "$SERIAL" "$@"; }
[ -r "$APK" ] || { echo "cannot read $APK" >&2; exit 1; }

echo "== push + install"
adb push "$APK" /data/local/tmp/tvhome-api22.apk
adb shell pm install -r /data/local/tmp/tvhome-api22.apk | tail -n 1
adb shell pm path com.gathin.tvhome

if [ "$TAKE" = 1 ]; then
  echo "== hide the stock launcher so HOME resolves to the new one"
  adb shell 'pm hide --user 0 com.mitv.tvhome'
  sleep 2
  adb shell input keyevent 3
  sleep 2
  echo "Home process now:"
  adb shell 'dumpsys activity | grep mHomeProcess' | head -n 1
  echo
  echo "Undo: $ADB -s $SERIAL shell pm unhide --user 0 com.mitv.tvhome"
  echo "      $ADB -s $SERIAL shell input keyevent 3"
else
  echo
  echo "The stock launcher is still Home. Open the new launcher from 我的应用 to try it, then run this"
  echo "again with --take-home (or: adb shell pm hide --user 0 com.mitv.tvhome)."
fi
