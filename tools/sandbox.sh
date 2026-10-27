#!/usr/bin/env bash
# Isolierte Preview-Umgebung: nested Hyprland mit 2560x1440-Headless-Output.
# Das Hyprland-Fenster landet per Window-Rule unsichtbar in special:luxsandbox.
#
#   sandbox.sh start <name>                 nested Hyprland starten
#   sandbox.sh run   <name> <shell.qml|dir> [KEY=VAL ...]   qs darin starten (ersetzt vorherigen Lauf)
#                    LUXSB_DBUS=1 als KEY=VAL: eigener Session-Bus (fuer NotificationServer-Tests);
#                    Adresse danach in $XDG_RUNTIME_DIR/luxsandbox/<name>.dbus (fuer notify-send)
#   sandbox.sh shot  <name> <out.png> [WxH+X+Y]             Screenshot (optional Crop)
#   sandbox.sh log   <name>                 qs-Log anzeigen
#   sandbox.sh hypr  <name> <hyprctl-args>  hyprctl gegen die Sandbox
#   sandbox.sh stop  <name>
set -euo pipefail
RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
DIR=$RT/luxsandbox
mkdir -p "$DIR"
cmd=${1:-}; name=${2:-}
[ -n "$cmd" ] && [ -n "$name" ] || { sed -n 2,13p "$0"; exit 1; }
base=$DIR/$name
here=$(cd "$(dirname "$0")" && pwd)

load() {
    [ -f "$base.env" ] || { echo "sandbox '$name' laeuft nicht (start zuerst)" >&2; exit 1; }
    # shellcheck disable=SC1090
    . "$base.env"
}

case $cmd in
start)
    [ -f "$base.env" ] && kill -0 "$(cat "$base.pid")" 2>/dev/null && { echo "laeuft schon"; exit 0; }
    # Window-Rule im echten Hyprland (idempotent)
    hyprctl eval 'hl.window_rule({ name = "luxshell-sandbox", match = { class = "aquamarine" }, workspace = "special:luxsandbox silent" })' >/dev/null
    exec 9>"$DIR/.lock"; flock 9
    ls "$RT/hypr" >"$base.before"
    ls "$RT" | grep -E '^wayland-[0-9]+$' >"$base.wlbefore" || true
    setsid Hyprland --config "$here/sandbox-hypr.lua" >"$base.hypr.log" 2>&1 &
    echo $! >"$base.pid"
    sig=""; wl=""
    for _ in $(seq 50); do
        sleep 0.2
        sig=$(ls "$RT/hypr" | grep -vxFf "$base.before" | head -1 || true)
        wl=$(ls "$RT" | grep -E '^wayland-[0-9]+$' | grep -vxFf "$base.wlbefore" | head -1 || true)
        [ -n "$sig" ] && [ -n "$wl" ] && [ -S "$RT/hypr/$sig/.socket.sock" ] && break
    done
    [ -n "$sig" ] && [ -n "$wl" ] || { echo "nested Hyprland kam nicht hoch, siehe $base.hypr.log" >&2; exit 1; }
    printf 'export HYPRLAND_INSTANCE_SIGNATURE=%s\nexport WAYLAND_DISPLAY=%s\n' "$sig" "$wl" >"$base.env"
    flock -u 9
    load
    sleep 0.5
    hyprctl output create headless >/dev/null
    sleep 0.5
    out=$(hyprctl monitors -j | jq -r '.[]|select(.name|startswith("HEADLESS"))|.name' | head -1)
    hyprctl eval "hl.monitor({ output = \"$out\", mode = \"2560x1440@60\", position = \"5000x0\", scale = 1 })" >/dev/null
    echo "$out" >"$base.out"
    echo "sandbox '$name' bereit: output $out"
    ;;
run)
    load
    target=${3:?shell.qml oder Ordner angeben}; shift 3
    [ -d "$target" ] && target=$target/shell.qml
    [ -f "$base.qs.pid" ] && kill "$(cat "$base.qs.pid")" 2>/dev/null || true
    sleep 0.3
    if printf '%s\n' "$@" | grep -qx 'LUXSB_DBUS=1'; then
        env "$@" setsid dbus-run-session -- sh -c 'echo "$DBUS_SESSION_BUS_ADDRESS" >"$1"; exec qs -p "$2"' _ "$base.dbus" "$target" >"$base.qs.log" 2>&1 &
    else
        env "$@" setsid qs -p "$target" >"$base.qs.log" 2>&1 &
    fi
    echo $! >"$base.qs.pid"
    sleep 2.5
    grep -E "ERROR|error|TypeError|ReferenceError|is not|Cannot" "$base.qs.log" | grep -v Papirus | head -20 || true
    ;;
shot)
    load
    out=$3; geo=${4:-}
    grim -o "$(cat "$base.out")" "$out"
    [ -n "$geo" ] && magick "$out" -crop "$geo" +repage "$out"
    echo "$out"
    ;;
log)  cat "$base.qs.log" ;;
hypr) load; shift 2; hyprctl "$@" ;;
stop)
    [ -f "$base.qs.pid" ] && kill "$(cat "$base.qs.pid")" 2>/dev/null || true
    [ -f "$base.pid" ] && kill "$(cat "$base.pid")" 2>/dev/null || true
    rm -f "$base".*
    echo "gestoppt"
    ;;
*) sed -n 2,13p "$0"; exit 1 ;;
esac
