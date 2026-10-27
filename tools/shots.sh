#!/usr/bin/env bash
# Regenerates shots/*.png inside the nested sandbox (tools/sandbox.sh), never on the real desktop.
#   tools/shots.sh [sandbox-name]      (sandbox must be started: sandbox.sh start <name>)
# Settings go to a temp dir, the clock is pinned to the reference frames (21:05 / 21:07).
# Animations run at LUXSHELL_SLOWMO=10 and are resampled to 60 fps (tools/animstrip.py),
# strips in the layout of ref/13 + ref/14 (2 x 15 tiles, 0..483 ms):
#   hover-open-anim.png, hover-close-anim.png   whole animation, trigger at 0 ms
#   hover-*-vs-ref.png   reference left, ours right on the reference timeline: the trigger
#       sits where the motion starts in ref/13 / ref/14 (fitted: 377 / 358 ms)
#   panel-morph-anim.png   hover > control center > launcher > collapsed
set -euo pipefail
name=${1:-shots}
here=$(cd "$(dirname "$0")/.." && pwd)
T=$here/tools/sandbox.sh
A=$here/tools/animstrip.py
ref=$here/ref
[ -d "$ref" ] || ref=$here/../../ref
out=$here/shots
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$out"
crop=1200x400+680+0

# shellcheck disable=SC1090
. "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/luxsandbox/$name.env"
mon=$(cat "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/luxsandbox/$name.out")
ox=$(hyprctl monitors -j | jq -r ".[]|select(.name==\"$mon\")|.x")
ipc=(qs -p "$here/shell.qml" ipc call luxshell)
run() { "$T" run "$name" "$here" LUXSHELL_CONFIG_DIR="$tmp" "$@" >/dev/null; sleep 0.8; }
# pointer far below the island (it would hover it and show up in the frames)
"$T" hypr "$name" dispatch "hl.dsp.cursor.move({ x = $((ox + 1280)), y = 1300 })" >/dev/null

run LUXSHELL_FAKE_CLOCK=2026-10-25T21:05:00 LUXSHELL_PREVIEW=collapsed
"$T" shot "$name" "$out/collapsed.png" $crop >/dev/null

run LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 LUXSHELL_PREVIEW=hover
"$T" shot "$name" "$out/hover.png" $crop >/dev/null

slow=10
tile="$((ox + 780)),0 1000x120"
run LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 LUXSHELL_PREVIEW=collapsed LUXSHELL_SLOWMO=$slow
python3 "$A" ref "$name" "$tile" $slow 0="$out/hover-open-anim.png" 377="$tmp/open-aligned.png" -- "${ipc[@]}" preview hover
sleep 0.5
python3 "$A" ref "$name" "$tile" $slow 0="$out/hover-close-anim.png" 358="$tmp/close-aligned.png" -- "${ipc[@]}" preview collapsed
magick "$ref/13-hover-open-anim-strip.png" "$tmp/open-aligned.png" +append "$out/hover-open-vs-ref.png"
magick "$ref/14-hover-close-anim-strip.png" "$tmp/close-aligned.png" +append "$out/hover-close-vs-ref.png"

times=0,33,67,100,150,200,300,450
panel="$((ox + 780)),0 1000x720"
run LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 LUXSHELL_PREVIEW=hover LUXSHELL_SLOWMO=$slow
python3 "$A" row "$name" "$panel" $slow 0.3 "$tmp/p1.png" "hover > control center" $times -- "${ipc[@]}" preview controlcenter
python3 "$A" row "$name" "$panel" $slow 0.3 "$tmp/p2.png" "control center > launcher" $times -- "${ipc[@]}" preview launcher
python3 "$A" row "$name" "$panel" $slow 0.3 "$tmp/p3.png" "launcher > collapsed" $times -- "${ipc[@]}" preview collapsed
magick "$tmp/p1.png" "$tmp/p2.png" "$tmp/p3.png" -append "$out/panel-morph-anim.png"

"$T" run "$name" "$here" LUXSHELL_CONFIG_DIR="$tmp" LUXSHELL_PREVIEW=collapsed >/dev/null
echo "shots in $out"
