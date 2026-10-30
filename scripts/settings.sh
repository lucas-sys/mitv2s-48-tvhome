#!/usr/bin/env bash
# System switches this TV needs, all reversible. Usage: TV_HOST=<tv ip> scripts/settings.sh apply|undo
#
#   apply  boot ad off, 24-hour clock, marketing push notifications denied (the push service itself stays,
#          it carries the installer allowlist on this firmware)
#   undo   every value back; `settings delete` restores the firmware default
set -euo pipefail
MODE="${1:?usage: TV_HOST=<tv ip> scripts/settings.sh apply|undo}"
ADB=${ADB:-adb}
TV_PORT=${TV_PORT:-5555}
: "${TV_HOST:?set TV_HOST to the TV IP}"
SERIAL="$TV_HOST:$TV_PORT"
adb() { "$ADB" -s "$SERIAL" "$@"; }
case "$MODE" in
  apply)
    adb shell 'settings put system boot_ad_switch 0'      # the 15 s sponsored boot video
    adb shell 'settings put system time_12_24 24'         # 24-hour clock (TextClock and every app)
    adb shell 'appops set com.xiaomi.mitv.tvpush.tvpushservice POST_NOTIFICATION deny' || \
      echo "note: appops POST_NOTIFICATION not supported on this build, skipped"
    ;;
  undo)
    adb shell 'settings delete system boot_ad_switch'
    adb shell 'settings delete system time_12_24'
    adb shell 'appops set com.xiaomi.mitv.tvpush.tvpushservice POST_NOTIFICATION allow' || true
    ;;
  *) echo "usage: $0 apply|undo" >&2; exit 1;;
esac
echo "== $MODE done"
