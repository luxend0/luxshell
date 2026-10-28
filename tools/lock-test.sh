#!/usr/bin/env bash
# Begleiteter Lockscreen-Test mit Totmannschalter: sperrt per luxshell-IPC und wartet aufs Entsperren.
# Ist nach LIMIT Sekunden (Standard 180) noch gesperrt (oder luxshell weg), greift unlock-rescue.sh.
LIMIT=${1:-180}
here=$(cd "$(dirname "$0")" && pwd)
locked() { qs -c luxshell ipc call luxshell state 2>/dev/null | tr -d '\n ' | grep -oE '"locked":[a-z]+' | cut -d: -f2; }
qs -c luxshell ipc call luxshell lock
start=$(date +%s); seen=0
while :; do
    st=$(locked); now=$(( $(date +%s) - start ))
    [ "$st" = true ] && seen=1
    if [ "$seen" = 1 ] && [ "$st" = false ]; then echo "ENTSPERRT nach ${now}s"; exit 0; fi
    if [ "$now" -ge "$LIMIT" ]; then echo "TIMEOUT nach ${now}s (Status: ${st:-luxshell weg}) -> Notausgang"; "$here/unlock-rescue.sh"; exit 3; fi
    sleep 2
done
