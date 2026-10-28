#!/usr/bin/env bash
# Lock screen shots inside the nested sandbox (tools/sandbox.sh), never on the real desktop.
#   tools/lockshots.sh [sandbox-name]      (sandbox must be started: sandbox.sh start <name>)
#
# Runs qs with LUXSHELL_DRYRUN=1 + LUXSHELL_LOCK_TEST_PASSWORD (PAM is never asked), the clock
# pinned to ref/11 (Sunday, October 25, 21:06) and USER=user0 so lock.png lines up with the
# reference pixel by pixel. Every IPC call goes to the qs PID of THIS sandbox (checked: its
# WAYLAND_DISPLAY is the nested one), keys are typed with wtype into the nested compositor.
# qs is only ever restarted while unlocked (restarting a locked qs = Hyprland's lockdead screen).
#
#   lock.png          full screen, idle (hint line)
#   lock-vs-ref.png   ref/11 left, lock.png right (half size)
#   lock-1080p.png    a second (temporary) 1920x1080 output: every screen gets the lock, scaled
#   lock-typing.png   full screen, password pill with dots
#   lock-caps.png     user block, Caps Lock on (pill glyph + note)
#   lock-error.png    user block: wrong password -> checking -> shake -> empty (video ms)
#   lock-anim.png     lock (desktop blurs into the lock screen) and unlock, full screen frames
set -euo pipefail
name=${1:-lock-a}
here=$(cd "$(dirname "$0")/.." && pwd)
T=$here/tools/sandbox.sh
[ -x "$T" ] || T=$here/../../tools/sandbox.sh
A=$here/tools/animstrip.py
[ -f "$A" ] || A=$here/../../tools/animstrip.py
out=$here/shots
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$out" "$tmp/cfg" "$tmp/cache"
pw=luxtest

wall=""
for w in "$HOME/Pictures/Wallpapers/LuxOS/luxos-metal.mp4" "$HOME/Pictures/Wallpapers/blue-abstract-2560x1440-25119.jpg"; do
    [ -f "$w" ] && { wall=$w; break; }
done
printf '{"wallpaper": "%s"}\n' "$wall" >"$tmp/cfg/settings.json"

RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
base=$RT/luxsandbox/$name
# shellcheck disable=SC1090
. "$base.env"
mon=$(cat "$base.out")
ox=$(hyprctl monitors -j | jq -r ".[]|select(.name==\"$mon\")|.x")

qspid() {
    local pid wl
    pid=$(cat "$base.qs.pid")
    wl=$(tr '\0' '\n' <"/proc/$pid/environ" | sed -n 's/^WAYLAND_DISPLAY=//p')
    [ "$wl" = "$WAYLAND_DISPLAY" ] || { echo "refusing: qs $pid is not in the sandbox ($wl)" >&2; exit 3; }
    echo "$pid"
}
ipc() { qs ipc --pid "$(qspid)" call luxshell "$@"; }
locked() { # true | false | unknown (qs busy reloading: retried)
    local s
    for _ in 1 2 3 4 5 6; do
        s=$(ipc state 2>/dev/null | jq -r .locked 2>/dev/null) && [ -n "$s" ] && { echo "$s"; return; }
        sleep 0.5
    done
    echo unknown
}
run() {
    if [ -f "$base.qs.pid" ] && kill -0 "$(cat "$base.qs.pid")" 2>/dev/null && [ "$(locked)" != false ]; then
        echo "qs is (maybe) locked, not restarting it" >&2
        exit 4
    fi
    "$T" run "$name" "$here" LUXSHELL_DRYRUN=1 LUXSHELL_WALLPAPER=1 LUXSHELL_CONFIG_DIR="$tmp/cfg" LUXSHELL_CACHE_DIR="$tmp/cache" \
        LUXSHELL_LOCK_TEST_PASSWORD=$pw LUXSHELL_FAKE_CLOCK=2026-10-25T21:06:00 LUXSHELL_PREVIEW=collapsed USER=user0 "$@" >/dev/null
    sleep 2
}
focus() { hyprctl dispatch "hl.dsp.focus({ monitor = \"$mon\" })" >/dev/null; }
unlock() { # $1 = seconds to wait
    focus
    wtype -k Escape
    wtype "$pw"
    wtype -k Return
    sleep "$1"
    [ "$(locked)" = false ] || { echo "unlock failed" >&2; exit 5; }
}
shot() { "$T" shot "$name" "$@" >/dev/null; }
# grid ROW.png TILE_WIDTH COLUMNS OUT.png: re-tile an animstrip row
grid() {
    local d
    d=$(mktemp -d -p "$tmp")
    magick "$1" -crop "$2"x +repage +adjoin "$d/t_%02d.png"
    magick montage "$d"/t_*.png -tile "$3"x -geometry +0+0 -background black "$4"
}
user="900x300+830+1100"
# pointer where ref/11 has it
hyprctl dispatch "hl.dsp.cursor.move({ x = $((ox + 1754)), y = 576 })" >/dev/null

# ---- stills at normal speed ----------------------------------------------------------
before=$(hyprctl monitors -j | jq -r '.[].name' | sort)
hyprctl output create headless >/dev/null
sleep 0.5
extra=$(hyprctl monitors -j | jq -r '.[].name' | sort | comm -13 <(echo "$before") - | head -1)
hyprctl eval "hl.monitor({ output = \"$extra\", mode = \"1920x1080@60\", position = \"9000x0\", scale = 1 })" >/dev/null
trap 'hyprctl output remove "$extra" >/dev/null 2>&1; rm -rf "$tmp"' EXIT
run
ipc lock
sleep 2.5 # intro + the video still
shot "$out/lock.png"
ref=$here/ref/11-lockscreen.png
[ -f "$ref" ] || ref=$here/../../ref/11-lockscreen.png
[ -f "$ref" ] && magick "$ref" "$out/lock.png" -resize 50% +append "$out/lock-vs-ref.png"
# second monitor: a temporary 1920x1080 headless output in the sandbox (the nested window's
# own output never presents while it is parked in special:luxsandbox, grim would hang on it)
timeout 5 grim -o "$extra" "$out/lock-1080p.png"
focus
wtype "hunter22"
sleep 0.3
timeout 5 grim -o "$extra" "$tmp/x.png" && magick "$tmp/x.png" -crop 960x260+480+800 +repage "$out/lock-1080p-typing.png"
sleep 0.6
shot "$out/lock-typing.png"
wtype -k Escape
wtype "HUNTER" # wtype sends upper case without Shift = Caps Lock for the letter-case check
sleep 0.6
shot "$out/lock-caps.png" "$user"
unlock 1.5

# ---- motion at LUXSHELL_SLOWMO=10 --------------------------------------------------------
slow=10
run LUXSHELL_SLOWMO=$slow
ipc lock
sleep 9
focus
wtype "wrong12"
sleep 3
python3 "$A" row "$name" "$((ox + 980)),1198 600x150" $slow 1 "$tmp/e.png" "wrong password" 0,300,450,475,500,530,565,605,650,720,800,950 -- wtype -k Return
grid "$tmp/e.png" 600 4 "$out/lock-error.png"
unlock $((45 * slow / 100 + 38 * slow / 100 + 2))

python3 "$A" row "$name" "$ox,0 2560x1440" $slow 0.2 "$tmp/a1.png" "lock" 0,40,80,140,220,320,450,700 -- qs ipc --pid "$(qspid)" call luxshell lock
sleep 3
focus
wtype "$pw"
sleep 3 # pill fades in (slow motion)
python3 "$A" row "$name" "$ox,0 2560x1440" $slow 0.2 "$tmp/a2.png" "unlock" 0,450,500,560,640,720,800,900 -- wtype -k Return
grid "$tmp/a1.png" 512 4 "$tmp/g1.png"
grid "$tmp/a2.png" 512 4 "$tmp/g2.png"
magick "$tmp/g1.png" "$tmp/g2.png" -append "$out/lock-anim.png"
sleep 2
[ "$(locked)" = false ] || { echo "still locked after the unlock strip" >&2; exit 5; }
run
echo "shots in $out"
