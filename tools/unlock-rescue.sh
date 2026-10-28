#!/usr/bin/env bash
# Notausgang, falls der luxshell-Lockscreen nicht entsperrt.
# Vom TTY aus (Strg+Alt+F3, einloggen):  ~/.config/quickshell/luxshell/tools/unlock-rescue.sh
# Beendet luxshell, hebt die verwaiste Sperre im ECHTEN Hyprland auf (nicht in einer Sandbox)
# und startet luxshell neu. Danach mit Strg+Alt+F1 (bzw. F2) zurueck zum Desktop.
set -u
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
sig=""
for row in $(hyprctl instances -j | jq -r '.[] | "\(.instance)=\(.pid)"'); do
    pid=${row#*=}
    tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null | grep -q sandbox-hypr.lua && continue
    sig=${row%%=*}
    break
done
[ -n "$sig" ] || { echo "kein echtes Hyprland gefunden"; exit 1; }
echo "Hyprland: $sig"
for p in $(pgrep -f '^qs -c luxshell'); do kill "$p"; done
sleep 1
HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl eval 'hl.clear_crashed_lockscreen()'
sleep 0.5
HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl dispatch "hl.dsp.exec_cmd(\"env LUXSHELL_NOTIFS=1 $HOME/.config/quickshell/luxshell/tools/run.sh\")"
echo "entsperrt, luxshell neu gestartet"
