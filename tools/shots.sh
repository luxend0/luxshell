#!/usr/bin/env bash
# Regenerates shots/*.png inside the nested sandbox (tools/sandbox.sh), never on the real desktop.
#   tools/shots.sh [sandbox-name]      (sandbox must be started: sandbox.sh start <name>)
# Settings go to a temp dir, the clock is pinned to the reference frames (21:05 / 21:07).
set -euo pipefail
name=${1:-shots}
here=$(cd "$(dirname "$0")/.." && pwd)
T=$here/../../tools/sandbox.sh
out=$here/shots
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$out"
crop=1200x400+680+0

# shellcheck disable=SC1090
. "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/luxsandbox/$name.env"
mon=$(cat "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/luxsandbox/$name.out")
ox=$(hyprctl monitors -j | jq -r ".[]|select(.name==\"$mon\")|.x")
q() { qs -p "$here/shell.qml" ipc call luxshell "$@" >/dev/null; }
run() { "$T" run "$name" "$here" LUXSHELL_CONFIG_DIR="$tmp" "$@" >/dev/null; sleep 0.8; }

run LUXSHELL_FAKE_CLOCK=2026-10-25T21:05:00 LUXSHELL_PREVIEW=collapsed
"$T" shot "$name" "$out/collapsed.png" $crop >/dev/null

run LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 LUXSHELL_PREVIEW=hover
"$T" shot "$name" "$out/hover.png" $crop >/dev/null

run LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 LUXSHELL_PREVIEW=controlcenter
"$T" shot "$name" "$out/controlcenter.png" $crop >/dev/null
"$T" shot "$name" "$out/controlcenter-full.png" 1200x760+680+0 >/dev/null

run LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 LUXSHELL_PREVIEW=launcher
"$T" shot "$name" "$out/launcher.png" $crop >/dev/null
"$T" shot "$name" "$out/launcher-full.png" 1200x600+680+0 >/dev/null

# hover open: preview collapsed -> hover, grab frames as fast as grim allows
strip() { # <png-prefix> <out.png>; first capture right after the IPC call
    local files=() stamps=() t0 i
    t0=$(date +%s%N)
    for i in $(seq -w 0 19); do
        grim -g "$((ox + 680)),0 1200x130" "$tmp/$1-$i.png"
        stamps+=($((($(date +%s%N) - t0) / 1000000)))
        files+=("$tmp/$1-$i.png")
    done
    for i in "${!files[@]}"; do
        magick "${files[$i]}" -font /usr/share/fonts/inter/InterVariable.ttf -fill '#f5d90a' -pointsize 16 -annotate +8+122 "${stamps[$i]} ms" "${files[$i]}"
    done
    magick "${files[@]}" -append "$2"
}
run LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 LUXSHELL_PREVIEW=collapsed
q preview hover
strip open "$out/hover-anim.png"
q preview collapsed
strip close "$out/hover-close-anim.png"

# panel -> panel: control center, then launcher
run LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00
q preview controlcenter
sleep 0.8
q preview launcher
files=()
for i in $(seq -w 0 9); do
    grim -g "$((ox + 580)),0 1400x720" "$tmp/pp-$i.png"
    files+=("$tmp/pp-$i.png")
done
magick "${files[@]}" -resize 50% +append "$out/panel-morph-anim.png"

"$T" run "$name" "$here" LUXSHELL_CONFIG_DIR="$tmp" LUXSHELL_PREVIEW=collapsed >/dev/null
echo "shots in $out"
