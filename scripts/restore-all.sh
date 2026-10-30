#!/usr/bin/env bash
# Undo everything this repository changed on the TV: unhide every package in the three lists and put the
# system switches back. Nothing was uninstalled, so this is complete (a factory reset is not needed).
#
# Usage: TV_HOST=<tv ip> scripts/restore-all.sh
set -euo pipefail
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(dirname "$HERE")
: "${TV_HOST:?set TV_HOST to the TV IP}"
for f in 01-ads-telemetry.txt 02-preloaded-apps.txt 03-account-cloud.txt; do
  "$HERE/unhide.sh" "$ROOT/lists/$f"
done
"$HERE/settings.sh" undo
echo
echo "== back to the stock state of the hidden packages and switches."
echo "   If you also hid the stock launcher:  adb shell pm unhide --user 0 com.mitv.tvhome"
echo "   Reboot the TV once so the launcher and system services settle."
