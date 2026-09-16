#!/usr/bin/env bash
# Temporarily switches the active tccd (TUXEDO Control Center) profile by id.
# Reverts to the AC/battery default (see /etc/tcc/settings stateMap) on the
# next power-source change, same as picking a profile in the TCC tray app.

id="$1"
if [ -z "$id" ]; then
    echo "usage: tcc_profile_set.sh <profile-id>" >&2
    exit 1
fi

busctl --system call com.tuxedocomputers.tccd /com/tuxedocomputers/tccd \
    com.tuxedocomputers.tccd SetTempProfileById s "$id"
