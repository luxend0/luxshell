#!/usr/bin/env bash
# Shots of the notification center + compact control center (candidate notif-a), inside the
# nested sandbox only (tools/sandbox.sh start <name> first). The shell runs on the sandbox's
# private D-Bus (LUXSB_DBUS=1 LUXSHELL_NOTIFS=1) and gets its notifications from
# tools/notif-test.sh, so nothing reaches the session bus. Scale as live: QT_SCALE_FACTOR=0.85.
#   tools/notif-shots.sh [sandbox-name]
#   cc-compact.png  cc-compact-vs-ref.png (scale 1 next to ref/08)  notifications.png
#   notifications-groups.png  notifications-empty.png  notifications-anim.png
set -euo pipefail
name=${1:-notif-a}
here=$(cd "$(dirname "$0")/.." && pwd)
repo=$(cd "$here/../.." && pwd)
T=$repo/tools/sandbox.sh
A=$repo/tools/animstrip.py
RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/luxsandbox
out=$here/shots
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$out" "$tmp/cfg" "$tmp/img"
crop=1200x700+680+0
real=${WAYLAND_DISPLAY:?real session display needed to refuse it in vclick}

# vclick (wlr-virtual-pointer on the NESTED compositor only)
wayland-scanner client-header "$repo/tools/vclick/vp.xml" "$tmp/vp-client.h"
wayland-scanner private-code "$repo/tools/vclick/vp.xml" "$tmp/vp-proto.c"
gcc -O1 -I"$tmp" -o "$tmp/vclick" "$repo/tools/vclick/vclick.c" "$tmp/vp-proto.c" $(pkg-config --cflags --libs wayland-client)

# shellcheck disable=SC1090
. "$RT/$name.env"
mon=$(cat "$RT/$name.out")
ox=$(hyprctl monitors -j | jq -r ".[]|select(.name==\"$mon\")|.x")
ipc=(qs -p "$here/shell.qml" ipc call)
export REAL_WAYLAND_DISPLAY=$real
click=("$tmp/vclick" "$WAYLAND_DISPLAY")

run() {
    rm -rf "$tmp/cfg" && mkdir -p "$tmp/cfg"
    "$T" run "$name" "$here" LUXSB_DBUS=1 LUXSHELL_NOTIFS=1 LUXSHELL_DRYRUN=1 QT_SCALE_FACTOR=${SCALE:-0.85} \
        LUXSHELL_CONFIG_DIR="$tmp/cfg" LUXSHELL_CACHE_DIR="$tmp/cache" LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 "$@" >/dev/null
    sleep 0.6
}
at() { hyprctl dispatch "hl.dsp.cursor.move({ x = $((ox + $1)), y = $2 })" >/dev/null; sleep 0.25; }
away() { at 1280 1300; }
shot() { "$T" shot "$name" "$out/$1" "${2:-$crop}" >/dev/null; }
keys() { for k in "$@"; do wtype -k "$k"; sleep 0.3; done; }
focus() { hyprctl dispatch "hl.dsp.focus({monitor=\"$mon\"})" >/dev/null; }
notifs() { "$here/tools/notif-test.sh" "$name" set "$tmp/img"; sleep 0.4; }

"$here/tools/notif-test.sh" "$name" images "$tmp/img"
away

# ---- control center, compact ----------------------------------------------------------------
run LUXSHELL_PREVIEW=controlcenter
sleep 0.8
shot cc-compact.png
SCALE=1 run LUXSHELL_PREVIEW=controlcenter
sleep 0.8
shot cc-ref-scale1.png
ref=$repo/ref/08-control-center.png
magick "$ref" -crop $crop +repage "$tmp/ref.png"
magick "$tmp/ref.png" "$out/cc-ref-scale1.png" +append "$out/cc-compact-vs-ref.png"
rm -f "$out/cc-ref-scale1.png"

# ---- notification center ----------------------------------------------------------------------
run
notifs
focus
"${ipc[@]}" luxshell open notifications >/dev/null
sleep 1.4
shot notifications.png

# Vesktop unfolded, marcel's text unfolded, keyboard on its first button
keys Down Right Down Down space Right
sleep 0.8
shot notifications-groups.png

# empty: reopened, so no keyboard selection is left over
"${ipc[@]}" notifs clear >/dev/null
"${ipc[@]}" luxshell close >/dev/null
sleep 0.8
"${ipc[@]}" luxshell open notifications >/dev/null
sleep 1.2
shot notifications-empty.png

# ---- animation ---------------------------------------------------------------------------------
slow=10
region="$((ox + 850)),0 860x680"
times=0,40,80,120,180,260,400,600
run LUXSHELL_PREVIEW=hover LUXSHELL_SLOWMO=$slow
notifs
# the peek queue runs ten times slower here: opening the center once consumes it
"${ipc[@]}" luxshell open notifications >/dev/null
sleep 2
"${ipc[@]}" luxshell close >/dev/null
sleep 6
python3 "$A" row "$name" "$region" $slow 0.4 "$tmp/a1.png" "hover > notifications" $times -- "${ipc[@]}" luxshell open notifications
sleep 0.5
at 1541 82 # chevron of the folded Vesktop group
python3 "$A" row "$name" "$region" $slow 0.4 "$tmp/a2.png" "unfold group (click)" 0,60,120,180,260,380,500,700 -- "${click[@]}" click
sleep 0.5
at 1130 200 # marcel's card
python3 "$A" row "$name" "$region" $slow 0.4 "$tmp/a3.png" "swipe away" 0,60,120,180,260,380,500,700 -- "${click[@]}" drag 260
sleep 0.5
away
python3 "$A" row "$name" "$region" $slow 0.4 "$tmp/a4.png" "notifications > hover" $times -- "${ipc[@]}" luxshell close
magick "$tmp/a1.png" "$tmp/a2.png" "$tmp/a3.png" "$tmp/a4.png" -append "$out/notifications-anim.png"

run LUXSHELL_PREVIEW=collapsed
echo "shots in $out"
