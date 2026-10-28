#!/usr/bin/env bash
# Media shots (candidate media-b) inside the nested sandbox, never on the real desktop.
#   tools/media-shots.sh [sandbox-name]     (sandbox.sh start <name> first)
# The shell runs on the sandbox's private D-Bus (LUXSB_DBUS=1) with tools/mpris-test-player.py
# as the only player, so every click/key hits the test player, never the user's Spotify.
# Crops as the reference frames (1200x400+680+0); animations at LUXSHELL_SLOWMO=10.
#   media-collapsed.png  media-hover.png  media-panel.png  media-anim.png
#   extra: media-hover-chip.png (pointer on the chip), media-panel-two.png (two players,
#          mono glow), media-empty.png (no player), media-collapsed-base.png (repo root shell)
set -euo pipefail
name=${1:-media-b}
here=$(cd "$(dirname "$0")/.." && pwd)
repo=$(cd "$here/../.." && pwd)
T=$repo/tools/sandbox.sh
A=$repo/tools/animstrip.py
RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/luxsandbox
out=$here/shots
tmp=$(mktemp -d)
covers=$tmp/covers
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$tmp"; }
trap cleanup EXIT
mkdir -p "$out" "$covers" "$tmp/cfg"
crop=1200x400+680+0

# shellcheck disable=SC1090
. "$RT/$name.env"
mon=$(cat "$RT/$name.out")
ox=$(hyprctl monitors -j | jq -r ".[]|select(.name==\"$mon\")|.x")
ipc=(qs -p "$here/shell.qml" ipc call luxshell)

# ---- covers (raster, so the real image path is exercised) -------------------------------
m() { nice -n 19 magick "$@"; }
m -size 600x600 gradient:"#3b6a8c"-"#0a1420" \( -size 600x600 xc:none -fill "#e9eef2" -draw "circle 380,230 380,140" -blur 0x1 \) -composite \
  \( -size 600x600 xc:none -fill "#060b12" -draw "path 'M0,600 L0,430 Q150,360 300,420 T600,400 L600,600 Z'" \) -composite "$covers/c1.png"
m -size 600x600 gradient:"#f2c14e"-"#b33a2a" \( -size 600x600 xc:none -fill "#2b1a12" -draw "rectangle 0,390 600,600" \) -composite \
  -fill "#fff1c9" -draw "circle 420,190 420,120" "$covers/c2.png"
m -size 600x600 gradient:"#e6e6e6"-"#2a2a2a" -fill none -stroke "#111111" -strokewidth 18 \
  -draw "rectangle 140,140 460,460" -draw "line 140,460 460,140" "$covers/c3.png"
tracks=(--track "Blue Hour|Mara Velde|Low Orbit|231|file://$covers/c1.png"
        --track "Sunday Static|The Quiet Engines|Signals|187|file://$covers/c2.png"
        --track "Grey Matter (Live)|Nightcall Avenue|Polar Lights|305|file://$covers/c3.png")

# shell on a fresh private bus, then the test player(s) on that bus
run() {
    for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
    pids=()
    "$T" run "$name" "$here" LUXSB_DBUS=1 LUXSHELL_DRYRUN=1 LUXSHELL_CONFIG_DIR="$tmp/cfg" "$@" >/dev/null
    sleep 0.5
}
player() {
    DBUS_SESSION_BUS_ADDRESS=$(cat "$RT/$name.dbus") setsid python3 "$here/tools/mpris-test-player.py" "$@" >>"$tmp/player.log" 2>&1 &
    pids+=($!)
    sleep 1.5
}
bus() { gdbus call --address "$(cat "$RT/$name.dbus")" --dest org.mpris.MediaPlayer2.luxshelltest --object-path /org/mpris/MediaPlayer2 "$@" >/dev/null; }
away() { "$T" hypr "$name" dispatch "hl.dsp.cursor.move({ x = $((ox + 1280)), y = 1300 })" >/dev/null; }
away

# ---- stills ------------------------------------------------------------------------------
run LUXSHELL_FAKE_CLOCK=2026-10-25T21:05:00 LUXSHELL_PREVIEW=collapsed
player "${tracks[@]}"
bus --method org.mpris.MediaPlayer2.Player.SetPosition /luxshell/test/track/0 83000000
sleep 0.5
"$T" shot "$name" "$out/media-collapsed.png" $crop >/dev/null

# the same frame from the repo root shell (without media) for a pixel comparison
for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
pids=()
"$T" run "$name" "$repo" LUXSB_DBUS=1 LUXSHELL_DRYRUN=1 LUXSHELL_CONFIG_DIR="$tmp/cfg" LUXSHELL_FAKE_CLOCK=2026-10-25T21:05:00 LUXSHELL_PREVIEW=collapsed >/dev/null
sleep 1
"$T" shot "$name" "$out/media-collapsed-base.png" $crop >/dev/null

run LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 LUXSHELL_PREVIEW=hover
player "${tracks[@]}"
bus --method org.mpris.MediaPlayer2.Player.SetPosition /luxshell/test/track/0 83000000
sleep 0.8
"$T" shot "$name" "$out/media-hover.png" $crop >/dev/null
# pointer enters the surface right on the chip (a warp inside the surface sends no motion)
"$T" hypr "$name" dispatch "hl.dsp.cursor.move({ x = $((ox + 1280 - 479 + 120)), y = 32 })" >/dev/null
sleep 0.6
"$T" shot "$name" "$out/media-hover-chip.png" $crop >/dev/null
away

"${ipc[@]}" preview media >/dev/null
sleep 1.2
"$T" shot "$name" "$out/media-panel.png" $crop >/dev/null

# two players (second one is not a test name: its controls only log), mono glow
printf '{"mediaGlow": "mono"}\n' >"$tmp/cfg/settings.json"
run LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 LUXSHELL_PREVIEW=media
player --identity Spotify --paused "${tracks[@]:2:2}" "${tracks[@]:0:2}"
player --bus-name org.mpris.MediaPlayer2.firefox.instance_1_9 --identity Firefox --paused --no-volume \
    --track "Live at the Lighthouse - Full Set|Kiko Lane||3725|file://$covers/c2.png"
sleep 0.8
"$T" shot "$name" "$out/media-panel-two.png" $crop >/dev/null
rm -f "$tmp/cfg/settings.json"

run LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 LUXSHELL_PREVIEW=media
sleep 0.8
"$T" shot "$name" "$out/media-empty.png" $crop >/dev/null

# ---- animation ---------------------------------------------------------------------------
slow=10
region="$((ox + 730)),0 1100x270"
times=0,40,80,120,180,260,450
run LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 LUXSHELL_PREVIEW=hover LUXSHELL_SLOWMO=$slow
player "${tracks[@]}"
bus --method org.mpris.MediaPlayer2.Player.SetPosition /luxshell/test/track/0 83000000
sleep 1
python3 "$A" row "$name" "$region" $slow 0.55 "$tmp/a1.png" "hover > media" $times -- "${ipc[@]}" preview media
sleep 0.5
python3 "$A" row "$name" "$region" $slow 0.55 "$tmp/a2.png" "next track" 0,60,120,180,260,340,450 -- \
    gdbus call --address "$(cat "$RT/$name.dbus")" --dest org.mpris.MediaPlayer2.luxshelltest --object-path /org/mpris/MediaPlayer2 --method org.mpris.MediaPlayer2.Player.Next
sleep 0.5
python3 "$A" row "$name" "$region" $slow 0.55 "$tmp/a3.png" "media > collapsed" $times -- "${ipc[@]}" preview collapsed
magick "$tmp/a1.png" "$tmp/a2.png" "$tmp/a3.png" -append "$out/media-anim.png"

grep -h "call\|set " "$tmp/player.log" || true
"$T" run "$name" "$here" LUXSB_DBUS=1 LUXSHELL_DRYRUN=1 LUXSHELL_CONFIG_DIR="$tmp/cfg" LUXSHELL_PREVIEW=collapsed >/dev/null
echo "shots in $out"
