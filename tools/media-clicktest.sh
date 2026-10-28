#!/usr/bin/env bash
# Mouse test of the media chip + panel inside the nested sandbox (never the real desktop):
# the shell runs on the sandbox's private D-Bus with tools/mpris-test-player.py as the only
# player; clicks come from tools/vclick (wlr-virtual-pointer on the NESTED compositor).
#   tools/media-clicktest.sh [sandbox-name]     (sandbox.sh start <name> first)
# Prints the shell state after every step and the calls the test player received.
set -euo pipefail
name=${1:-media-b}
here=$(cd "$(dirname "$0")/.." && pwd)
repo=$(cd "$here/../.." && pwd)
T=$repo/tools/sandbox.sh
RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/luxsandbox
REAL=${WAYLAND_DISPLAY:?real session display unknown}
tmp=$(mktemp -d)
pid=""
trap '[ -n "$pid" ] && kill "$pid" 2>/dev/null; rm -rf "$tmp"' EXIT

# build the click helper (scratch, not in the repo)
wayland-scanner client-header "$here/tools/vclick/vp.xml" "$tmp/vp-client.h"
wayland-scanner private-code "$here/tools/vclick/vp.xml" "$tmp/vp-proto.c"
gcc -O1 -I"$tmp" -o "$tmp/vclick" "$here/tools/vclick/vclick.c" "$tmp/vp-proto.c" $(pkg-config --cflags --libs wayland-client)
nice -n 19 magick -size 600x600 gradient:"#f2c14e"-"#b33a2a" "$tmp/c.png"

"$T" run "$name" "$here" LUXSB_DBUS=1 LUXSHELL_DRYRUN=1 LUXSHELL_CONFIG_DIR="$tmp" LUXSHELL_FAKE_CLOCK=2026-10-25T21:07:00 >/dev/null
sleep 0.5
DBUS_SESSION_BUS_ADDRESS=$(cat "$RT/$name.dbus") setsid python3 "$here/tools/mpris-test-player.py" \
    --track "Blue Hour|Mara Velde|Low Orbit|231|file://$tmp/c.png" --track "Glass|Kiko|Signals|187|file://$tmp/c.png" >"$tmp/player.log" 2>&1 &
pid=$!
sleep 2

# shellcheck disable=SC1090
. "$RT/$name.env"
ox=$(hyprctl monitors -j | jq -r ".[]|select(.name==\"$(cat "$RT/$name.out")\")|.x")
Q() { qs -p "$here/shell.qml" ipc call luxshell "$@"; }
at() { hyprctl dispatch "hl.dsp.cursor.move({ x = $((ox + $1)), y = $2 })" >/dev/null; sleep 0.25; }
click() { REAL_WAYLAND_DISPLAY=$REAL "$tmp/vclick" "$WAYLAND_DISPLAY" click; sleep 0.5; }
drag() { REAL_WAYLAND_DISPLAY=$REAL "$tmp/vclick" "$WAYLAND_DISPLAY" drag "$1"; sleep 0.5; }
st() { echo "   panel=$(Q state | jq -r .panel) | $(Q state | jq -r .media)"; }
hover() { at 1280 1300; at 1280 20; sleep 0.8; }

# geometry (Theme.hover / Theme.media): hover island 958 wide, panel 686 wide, both centred on 1280
hl=$((1280 - 479)); pl=$((1280 - 343)); x0=$((pl + 24 + 188 + 28))
hover
echo "1 chip text -> media panel"; at $((hl + 140)) 32; click; st
echo "2 play/pause disc"; at $((x0 - 11 + 42 + 14 + 26)) 186; click; st
echo "3 seek click at 50 %"; at $((x0 + 211)) 134; click; st
echo "4 seek drag 50 % -> 75 %"; drag 105; st
echo "5 volume click at 25 %"; at $((x0 + 422 - 120 + 30)) 186; click; st
echo "6 next"; at $((x0 - 11 + 42 + 14 + 52 + 14 + 21)) 186; click; st
echo "7 open-app button (raises, closes)"; at $((x0 + 422 + 6 - 14)) 38; click; st
hover
echo "8 chip play disc (no panel)"
# the disc sits right after the text: rightmost dark-grey pixel of the chip row is its edge
"$T" shot "$name" "$tmp/row.png" 400x1+$((hl + 45))+32 >/dev/null
dx=$(python3 -c "
from PIL import Image
im = Image.open('$tmp/row.png').convert('L'); w = im.size[0]
xs = [x for x in range(w) if 16 <= im.getpixel((x, 0)) <= 60]
print(xs[-1] - 13 if xs else 300)")
at $((hl + 45 + dx)) 32; click; st
echo "9 clock -> control center"; at 1240 48; click; st
Q close
echo "--- test player received:"
tail -n +2 "$tmp/player.log"
