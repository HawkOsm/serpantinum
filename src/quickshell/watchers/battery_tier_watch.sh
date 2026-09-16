#!/usr/bin/env bash
# Run periodically (see singletons/PowerTierWatcher.qml). While the active
# tccd profile is one of the two "Power Saving" tiers, auto-switches between
# them based on battery percentage. Never touches any other profile, so it
# never overrides a manually-picked Performance/Balanced/Quiet mode.

THRESHOLD=30

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
GET="$SCRIPT_DIR/../../scripts/system/tcc_profile_get.sh"
SET="$SCRIPT_DIR/../../scripts/system/tcc_profile_set.sh"

active_id=$(bash "$GET")

if [ "$active_id" != "power_saving_high" ] && [ "$active_id" != "power_saving_low" ]; then
    exit 0
fi

bat_path=$(find /sys/class/power_supply -maxdepth 1 -iname 'BAT*' | head -1)
if [ -z "$bat_path" ] || [ ! -f "$bat_path/capacity" ]; then
    exit 0
fi

capacity=$(cat "$bat_path/capacity")

if [ "$capacity" -le "$THRESHOLD" ] && [ "$active_id" != "power_saving_low" ]; then
    bash "$SET" "power_saving_low"
elif [ "$capacity" -gt "$THRESHOLD" ] && [ "$active_id" != "power_saving_high" ]; then
    bash "$SET" "power_saving_high"
fi
