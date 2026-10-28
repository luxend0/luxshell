#!/usr/bin/env bash
# Startet luxshell mit der Skalierung aus den Settings (uiScale -> QT_SCALE_FACTOR, wirkt nur beim Start).
# Neustart aus den Settings (Appearance > "Restart luxshell now"):
#   LUXSHELL_WAIT_PID    alte Instanz: erst nach ihrem Ende starten (max. 5 s)
#   LUXSHELL_SHELL_PATH  Shell-Ordner statt -c luxshell (Sandbox, Kandidaten); die uebrige Umgebung
#                        (WAYLAND_DISPLAY, HYPRLAND_INSTANCE_SIGNATURE, LUXSHELL_*) erbt der Neustart
if [[ -n ${LUXSHELL_WAIT_PID:-} ]]; then
    for _ in $(seq 100); do kill -0 "$LUXSHELL_WAIT_PID" 2>/dev/null || break; sleep 0.05; done
fi
unset LUXSHELL_WAIT_PID
cfg=${LUXSHELL_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/luxshell}/settings.json
scale=$(jq -r '.uiScale // 0.85' "$cfg" 2>/dev/null) || scale=0.85
[[ $scale =~ ^[0-9]*\.?[0-9]+$ ]] || scale=0.85
export QT_SCALE_FACTOR=$scale
if [[ -n ${LUXSHELL_SHELL_PATH:-} ]]; then
    path=$LUXSHELL_SHELL_PATH
    unset LUXSHELL_SHELL_PATH
    exec qs -p "$path" "$@"
fi
exec qs -c luxshell "$@"
