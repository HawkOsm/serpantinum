#!/usr/bin/env bash
# Prints the id of the currently active tccd (TUXEDO Control Center) profile,
# e.g. "performance", "balanced", "quiet", "power_saving_high", "power_saving_low".

reply=$(busctl --system -j call com.tuxedocomputers.tccd /com/tuxedocomputers/tccd \
    com.tuxedocomputers.tccd GetActiveProfileJSON 2>/dev/null)

if [ -z "$reply" ]; then
    exit 0
fi

echo "$reply" | jq -r '.data[0]' | jq -r '.id // empty'
