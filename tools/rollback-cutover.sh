#!/usr/bin/env bash
# Macht die luxshell-Umstellung vom 2026-10-28 rueckgaengig: alte Hypr-Config + Keybinds,
# Ambxst ohne Patch-Flag (Benachrichtigungen + OSD wieder bei Ambxst), Uebergangs-Island statt luxshell.
set -u
H=$HOME/.config/hypr
cp "$H/hyprland.lua.bak-luxshell" "$H/hyprland.lua"
cp "$H/luxos/keybinds.lua.bak-luxshell" "$H/luxos/keybinds.lua"
hyprctl eval 'hl.env("AMBXST_LUXSHELL", "")' >/dev/null
for pid in $(pgrep -f '^qs -c luxshell'); do kill "$pid"; done
ambxst quit >/dev/null 2>&1; sleep 1
hyprctl dispatch 'hl.dsp.exec_cmd("ambxst")' >/dev/null
hyprctl dispatch 'hl.dsp.exec_cmd("qs -c island")' >/dev/null
# luxshell-Tasten zurueck auf Ambxsts Originale (wie in ~/.local/share/ambxst/hyprland.lua)
hyprctl eval 'for _, k in ipairs({"SUPER + Super_L", "SUPER + TAB", "SUPER + COMMA", "SUPER + SHIFT + Y"}) do pcall(hl.unbind, k) end
hl.bind("SUPER + Super_L", hl.dsp.exec_cmd("ambxst run launcher"), { release = true })
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("ambxst run overview"))
hl.bind("SUPER + COMMA", hl.dsp.exec_cmd("ambxst run wallpapers"))' >/dev/null
hyprctl eval 'dofile(os.getenv("HOME") .. "/.config/hypr/luxos/keybinds.lua")' >/dev/null
echo "zurueck auf Island + Ambxst"
