#!/usr/bin/env bash
# Run periodically (see singletons/PowerTierWatcher.qml). Detects transitions
# between AC and battery power and (re)applies the tccd default profile for
# the new state exactly once per transition -- so a manual Super+B pick still
# sticks until the AC state actually changes again.
#
# tccd's own built-in per-state default (settings.json "stateMap") does not
# survive a tccd restart when set by editing the file directly (no D-Bus
# setter exists for it), so this replicates that behavior ourselves.

STATE_FILE="/tmp/serpantinum_ac_state"

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SET="$SCRIPT_DIR/../../scripts/system/tcc_profile_set.sh"

ac_path=$(find /sys/class/power_supply -maxdepth 1 -iname 'AC*' -o -iname 'ADP*' | head -1)
if [ -z "$ac_path" ] || [ ! -f "$ac_path/online" ]; then
    exit 0
fi

if [ "$(cat "$ac_path/online")" = "1" ]; then
    current="ac"
else
    current="battery"
fi

previous=""
[ -f "$STATE_FILE" ] && previous=$(cat "$STATE_FILE")

if [ "$current" != "$previous" ]; then
    if [ "$current" = "ac" ]; then
        bash "$SET" "__default_custom_profile__"
    else
        bash "$SET" "power_saving_high"
    fi
    echo "$current" > "$STATE_FILE"
fi
