#!/usr/bin/env bash
# Startet luxshell mit der Skalierung aus den Settings (uiScale -> QT_SCALE_FACTOR, wirkt nur beim Start).
cfg=${LUXSHELL_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/luxshell}/settings.json
scale=$(jq -r '.uiScale // 0.85' "$cfg" 2>/dev/null) || scale=0.85
[[ $scale =~ ^[0-9]*\.?[0-9]+$ ]] || scale=0.85
export QT_SCALE_FACTOR=$scale
exec qs -c luxshell "$@"
