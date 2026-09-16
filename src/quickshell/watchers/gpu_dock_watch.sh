#!/usr/bin/env bash
# Run periodically (see singletons/PowerTierWatcher.qml). If a monitor gets
# connected to the dGPU while the session is running in iGPU-primary mode
# (see uwsm/env-hyprland.d/10-gpu-power.sh), the dGPU is still open (just
# not primary), so Hyprland will usually hotplug the monitor live without
# any restart -- it just might be a bit laggier on that output than normal
# (a known Nvidia multi-GPU limitation, not a guaranteed failure).
#
# This never restarts anything on its own -- that would kill whatever
# you're working on, which defeats the point of "I plugged in my monitor
# because I need it right now." It only sends a single informational
# notification so you know you're in that state and can relogin later,
# on your own timing, if you want full performance on the external output.

STATE_FILE="/tmp/serpantinum_gpu_dock_state"
MODE_FILE="/tmp/serpantinum_gpu_mode"
DEBOUNCE_POLLS=2  # consecutive positive polls required before notifying

# Only relevant if this session actually booted iGPU-primary. Written by
# uwsm/env-hyprland.d/10-gpu-power.sh at login -- more reliable than reading
# Hyprland's own /proc/PID/environ, which doesn't reflect uwsm-exported vars.
if [ "$(cat "$MODE_FILE" 2>/dev/null)" != "igpu" ]; then
    rm -f "$STATE_FILE"
    exit 0
fi

[ -e /dev/dri/dgpu ] || exit 0
dgpu_card="$(basename "$(readlink -f /dev/dri/dgpu)")"

dgpu_has_monitor=0
for status in /sys/class/drm/"$dgpu_card"-*/status; do
    [ -f "$status" ] || continue
    if [ "$(cat "$status" 2>/dev/null)" = "connected" ]; then
        dgpu_has_monitor=1
        break
    fi
done

if [ "$dgpu_has_monitor" -eq 0 ]; then
    rm -f "$STATE_FILE"
    exit 0
fi

state="none:0"
[ -f "$STATE_FILE" ] && state=$(cat "$STATE_FILE")
phase="${state%%:*}"
count="${state##*:}"

if [ "$phase" = "notified" ]; then
    # Already told you about this dock event; don't repeat.
    exit 0
fi

count=$((count + 1))
if [ "$count" -lt "$DEBOUNCE_POLLS" ]; then
    echo "pending:$count" > "$STATE_FILE"
    exit 0
fi

echo "notified:$count" > "$STATE_FILE"

notify-send "Monitor connected on battery power" \
    "It should light up, but may lag a bit on that output (Nvidia multi-GPU limitation). Log out/in whenever it's convenient for full performance -- nothing will restart on its own." \
    2>/dev/null
