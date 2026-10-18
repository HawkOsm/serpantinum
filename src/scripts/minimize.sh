#!/usr/bin/env bash
# Hyprland only. Minimize the focused window: save a small thumbnail of it (shown by the
# minimized-windows picker), then move it to the hidden special:minimized workspace.
set -u

dir="${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum/minimized"
mkdir -p "$dir"

win=$(hyprctl activewindow -j 2>/dev/null) || exit 0
addr=$(jq -r '.address // empty' <<<"$win")
[ -n "$addr" ] || exit 0
[ "$(jq -r '.workspace.name' <<<"$win")" = "special:minimized" ] && exit 0

# Only capture when no Serpantinum panel is open, otherwise the panel ends up in the shot.
widget=$(jq -r '.widget // "hidden"' "${XDG_RUNTIME_DIR:-/run/user/$UID}/serpantinum/current_widget" 2>/dev/null || echo hidden)
if [ "$widget" = "hidden" ] && command -v grim >/dev/null 2>&1; then
    geom=$(jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' <<<"$win")
    if timeout 2 grim -g "$geom" -s 0.5 -t jpeg -q 75 "$dir/$addr.tmp.jpg" 2>/dev/null; then
        mv -f "$dir/$addr.tmp.jpg" "$dir/$addr.jpg"
    else
        rm -f "$dir/$addr.tmp.jpg"
    fi
fi

hyprctl dispatch "hl.dsp.window.move({workspace=\"special:minimized\", window=\"address:$addr\", follow=false})" >/dev/null

# Drop thumbnails of windows that are no longer minimized.
keep=$(hyprctl clients -j | jq -r '.[] | select(.workspace.name == "special:minimized") | .address')
for f in "$dir"/0x*.jpg; do
    [ -e "$f" ] || continue
    grep -qx "$(basename "$f" .jpg)" <<<"$keep" || rm -f "$f"
done
