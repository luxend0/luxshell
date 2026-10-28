#!/usr/bin/env bash
# Test notifications for the notification center (candidate notif-a), sent to the PRIVATE
# bus of a sandbox shell started with LUXSB_DBUS=1 LUXSHELL_NOTIFS=1 (tools/sandbox.sh run).
# Never touches the session bus: the address comes from $XDG_RUNTIME_DIR/luxsandbox/<name>.dbus.
#   tools/notif-test.sh <sandbox> images <dir>     render avatars / cover / screenshot into <dir>
#   tools/notif-test.sh <sandbox> set <dir>        full set: 6 apps, actions, images, critical,
#                                                  ages 2h .. now (ipc notifs age)
#   tools/notif-test.sh <sandbox> one <dir>        one more Vesktop message (arrives live)
#   tools/notif-test.sh <sandbox> send APP ICON DESKTOP SUMMARY BODY [IMAGE] [URGENCY] [ACTIONS...]
set -euo pipefail
name=${1:?sandbox}; cmd=${2:?command}
here=$(cd "$(dirname "$0")/.." && pwd)
RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/luxsandbox
addr=$(cat "$RT/$name.dbus")
# shellcheck disable=SC1090
. "$RT/$name.env"

send() { # app icon desktop summary body [image] [urgency] [id text ...]
    local app=$1 icon=$2 desk=$3 summary=$4 body=$5 image=${6:-} urg=${7:-1}
    shift 7 2>/dev/null || shift $#
    local acts="" a
    for a in "$@"; do acts+="\"${a//\"/}\","; done
    local hints="{\"urgency\": <byte $urg>"
    [ -n "$desk" ] && hints+=", \"desktop-entry\": <\"$desk\">"
    [ -n "$image" ] && hints+=", \"image-path\": <\"file://$image\">"
    hints+="}"
    gdbus call --address "$addr" --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify "$app" 0 "$icon" "$summary" "$body" "[${acts%,}]" "$hints" 0 >/dev/null
}
age() { qs -p "$here/shell.qml" ipc call notifs age "$1" >/dev/null; }

case $cmd in
images)
    d=${3:?dir}; mkdir -p "$d"
    m() { nice -n 19 magick "$@"; }
    m -size 160x160 gradient:"#5a6b7a"-"#1c2329" -gravity center -fill "#e8edf1" -font Inter-Bold -pointsize 74 -annotate 0 "O" "$d/ok0x.png"
    m -size 160x160 gradient:"#8a7f6e"-"#2b2620" -gravity center -fill "#f3eee6" -font Inter-Bold -pointsize 74 -annotate 0 "M" "$d/marcel.png"
    m -size 160x160 gradient:"#6e7f74"-"#1f2a23" -gravity center -fill "#eef3ef" -font Inter-Bold -pointsize 74 -annotate 0 "K" "$d/kerem.png"
    m -size 400x400 gradient:"#d8c9a8"-"#3b3226" \( -size 400x400 xc:none -fill "#1d1812" -draw "circle 200,200 200,70" \) -composite \
        -fill "#d8c9a8" -draw "circle 200,200 200,186" "$d/cover.png"
    src=$here/../../ref/08-control-center.png
    [ -f "$src" ] || src=$here/ref/08-control-center.png
    m "$src" -resize 960x540 "$d/screenshot.png"
    ;;
set)
    d=${3:?dir}
    # 2 h ago
    send "Steam" "steam" "steam" "Counter-Strike 2 is ready to play" "The update finished downloading (1.2 GB)." "" 1
    send "kitty" "kitty" "kitty" "Command finished" "paru -Syu  (3m 41s, exit 0)" "" 0
    age 125
    # 40 min ago
    send "Spotify" "spotify" "spotify" "Kerala" "Bonobo  ·  Migration" "$d/cover.png" 0
    send "Firefox" "firefox" "firefox" "Download complete" "archlinux-2026.10.01-x86_64.iso  ·  1.3 GB" "" 1 default "" open "Open" folder "Show in folder"
    age 38
    # a few minutes ago
    send "Vesktop" "discord" "dev.vencord.Vesktop" "kerem" "pushed the fix for the invoice export, deploying after lunch" "$d/kerem.png" 1 default ""
    send "Screenshot" "applets-screenshooter" "" "Screenshot saved" "~/Pictures/Screenshots/2026-10-25_21-03-12.png" "$d/screenshot.png" 1 default "" edit "Edit" copy "Copy"
    age 4
    # now
    send "Vesktop" "discord" "dev.vencord.Vesktop" "marcel" "can you check the panel invoice export? the totals for October are off by one day, looks like the timezone again. Customers with hourly billing see the last day twice in the PDF, the CSV is fine." "$d/marcel.png" 1 default "" reply "Reply" read "Mark as read"
    send "System" "" "" "Disk almost full" "/home has 4.2 GB left (97 % used). Clean up the Steam shader cache or old snapshots." "" 2
    send "Vesktop" "discord" "dev.vencord.Vesktop" "ok0x" "node02 is back, latency looks normal again" "$d/ok0x.png" 1 default ""
    ;;
one)
    d=${3:?dir}
    send "Vesktop" "discord" "dev.vencord.Vesktop" "kerem" "deploy done, all green" "$d/kerem.png" 1 default ""
    ;;
send)
    shift 2
    send "$@"
    ;;
*) sed -n 2,10p "$0"; exit 1 ;;
esac
