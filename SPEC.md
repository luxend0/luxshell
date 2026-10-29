# luxshell - Spec

Eigene Quickshell-Dots fuer LuxOS (Hyprland 0.56, Lua-Config, Quickshell 0.3.2, Qt 6.12).
Vorlage: Video "Should You Learn Quickshell for Hyprland?" (saneAspect, youtu.be/cLB2eaXrrk4).
Referenz-Frames in `ref/` (auf 2560 hochskaliert, Original 1280x720 = halbe Groesse von 1440p).
**Ziel: 1:1 wie im Video.**

## Rahmen
- Ordner `~/.config/quickshell/luxshell`, Start `qs -c luxshell`. Git, spaeter privates Repo luxend0/luxshell.
- Ersetzt Ambxst schrittweise. Waehrend der Uebergangszeit laeuft Ambxst parallel; luxshell darf
  NICHTS von Ambxst importieren oder voraussetzen.
- Monitor: DP-3 2560x1440@180 (Island auf jedem Screen).
- Kein Akku vorhanden (Desktop, Ethernet).

## Look
- 1:1 monochrom wie Video: Island tiefschwarz, kein Rand, weisse/graue Schrift. Default-Theme "noir".
- Themes (Theme-Picker) tauschen eine Palette; Akzent faerbt aktiven Workspace, Slider, Toggles
  (siehe ref/15-theme-tinted.png: aktiver Workspace + Battery wurden cyan). Rot (#e5484d) nur
  fuer den Power-Button.
- Schrift: Inter. Icons: Outline-Stil wie im Video (Lucide/SF-Symbols-artig). Verfuegbar:
  "JetBrainsMono Nerd Font" (Material-Design-Glyphen) oder eigene SVGs in `assets/` (Lucide, ISC).

## Island (Kernelement)
- Oben mittig, **buendig an der Bildschirmkante**, nur unten abgerundet. Reserviert Platz
  (exclusive zone = Hoehe im eingeklappten Zustand).
- **Eingeklappt** (ref/01-collapsed.png): 5 Workspace-Kapseln (hochkant; aktiv = groesser + hell,
  belegt = grau, leer = dunkelgrau), Uhr HH:mm mittig, rechts Signalbalken (Ethernet = voll)
  und **Lautstaerke-Icon statt Akku** (scrollen = Lautstaerke).
- **Hover** (ref/02-hover.png, Animation ref/13 + ref/14): waechst breiter UND hoeher, zweizeilig:
  links oben App-Icon + Titel des aktiven Fensters, darunter groessere Workspace-Kapseln;
  Mitte grosse Uhr + Datum ("Sun, Oct 25", gedimmt); rechts oben Benachrichtigungsstatus
  ("All caught up" + Glocke bzw. Anzahl), darunter Signal + Lautstaerke.
  Zusaetzlich dezent: Tray-Icons, Zahnrad (oeffnet Settings-App), Power-Button (rot, Powermenu).
- **Klick** auf die Island morpht ins Control Center. Klick daneben / Esc schliesst.
- Panels morphen ALLE aus der Island heraus (Groesse/Ecken animieren, Inhalt blendet ueber),
  siehe ref/16-cc-open-anim.png (Launcher -> Control Center).

## Module (Reihenfolge)
1. Island-Kern: eingeklappt, Hover, Morph-Container, IPC, Theme, Basis-Services
2. Control Center (ref/08, ref/09): Wi-Fi, Focus/DND, Lock, Bluetooth (+ Geraete-Unterseite),
   Game Mode, Dark-Toggle (runder Button), Sound- und Display-Slider (mit Pfeil zu Unterseite),
   Notifications-Liste ("No notifications")
3. Launcher (ref/07): Suchfeld + App-Liste (Icon, Name, Untertitel), Auswahl-Highlight
4. Wallpaper-Picker (ref/06) + Theme-Picker (ref/04, ref/05): Karussell, Suche, "Enter to apply"
5. OSD (ref/10) + Notifications aus der Island
6. Workspace-Overview (aus der Island), Media in der Island (Cover, Titel, Play/Pause)
7. Lockscreen (ref/11), Settings-App (ref/12, Fenster mit Sidebar)

## Keybinds (ersetzen Ambxsts Ziele, gleiche Tasten)
Super-Tap Launcher, Super+Shift+D Control Center, Super+Tab Overview, Super+Esc Powermenu,
Super+Shift+W Wallpaper-Picker, Super+Shift+Y Theme-Picker. Aufruf per
`qs -c luxshell ipc call luxshell <fn> <arg>` (IpcHandler target "luxshell").

## Regeln fuer Entwicklung
- Testen NUR in der Sandbox (`tools/sandbox.sh`), nie `qs -c luxshell` auf dem echten Desktop
  starten, nie Ambxst/Hyprland-Config/laufende Prozesse anfassen.
- Preview-Zustaende per Env erzwingbar: `LUXSHELL_PREVIEW=collapsed|hover|<panel>`.
- `NotificationServer` nur wenn `LUXSHELL_NOTIFS=1` (sonst kollidiert es mit Ambxst auf dem
  echten Session-Bus); in der Sandbox Fake-Daten.
- Systemzustand nie aendern (Lautstaerke, WLAN, Bluetooth, Helligkeit) - nur lesen.
- Hyprland-Dispatch ist Lua: `Hyprland.dispatch('hl.dsp.focus({workspace="3"})')`.
- CPU schonen: kein Dauer-Polling unter 2 s, nice fuer schwere Befehle.

## Welle "OS + Bar" (Grilling 2026-10-29)
Reihenfolge: 1) Bar, 2) OS-Seiten + Polkit + Idle, 3) Clipboard, Kalender, Timer, Extra-Seiten.
Design-Module (Polkit-Prompt, Clipboard, Kalender, Displays-Seite, Timer) je 2 Varianten, luxend
waehlt per Bild; alles andere je ein Agent. Max 3 Agents gleichzeitig. Commit + Push je Modul.

Bar (neue Widgets nur in der Palette des Layout-Editors, luxends Layout bleibt):
- Menue-Widgets Bluetooth, Sound (bestehendes Volume), Netzwerk (bestehendes), Display:
  Klick oeffnet NUR das jeweilige Menue als eigenes Island-Panel, ohne CC, ohne Zurueck-Pfeil.
- Schalter Mikrofon (rot wenn eine App aufnimmt), Nachtlicht (Scroll = Temperatur),
  Power-Profil, Caffeine (Restzeit). Rechtsklick: Mic = Sound-Menue (Eingabe),
  Nachtlicht = Display-Menue, Power-Profil = 3er-Auswahl, Caffeine = 30 min / 1 h / 2 h / bis aus.
- Info/Tools: GPU-Last/VRAM + CPU/GPU-Temperatur (AMD sysfs), Netzwerk-Speed, Updates
  (checkupdates + paru -Qua, Klick = Terminal mit `paru -Syu`), Screenshot, Pipette (hyprpicker),
  Clipboard-Button, Privacy-Punkt (nur waehrend Bildschirmfreigabe/Aufnahme/Mic), Launcher-
  und Overview-Button. Kalender (Klick auf Uhr/Datum, nur Anzeige), Timer/Pomodoro.
- Clipboard-Panel (Phase 3): Super+V, cliphist, 500 Eintraege, Bilder, Pinnen, Suche, ohne
  Passwortmanager-Eintraege (x-kde-passwordManagerHint); Ambxst-Clipboard aus.

Settings: Sidebar in zwei Gruppen "luxshell" (bisherige Seiten) und "System" mit Displays,
Eingabe, Sound, Netzwerk + Bluetooth, Energie + Idle, Standard-Apps, Datum/Zeit/Sprache,
Autostart, Ueber dieses System, Benutzerkonto, Speicher, Datenschutz.
- Hyprland-Werte (Monitor, Eingabe, Autostart) sofort live per hyprctl, dauerhaft in
  `~/.config/hypr/luxos/luxshell-system.lua` (am Ende von hyprland.lua dofile'd, nur geschrieben
  wenn etwas geaendert wird). Monitor-Aenderungen: "Behalten?"-Dialog 15 s, sonst Rollback.
- Displays: Aufloesung, Hz, Scale, VRR, 10-bit/HDR (nur wenn der Monitor es kann), Rotation,
  an/aus; Drag-Canvas fuer die Anordnung erst ab 2 Monitoren.
- Eingabe: Sensitivity/Accel global + optional pro Geraet; Key-Repeat bleibt aus.
- Polkit: luxshell ist der Agent (Quickshell.Services.Polkit), Prompt im Lockscreen-Stil.
- Idle: eigener Dienst (Wayland idle-notify), Startwerte wie Ambxst (2:30 dimmen, 5:00 sperren,
  5:30 Bildschirm aus, 30 min Suspend), pausiert bei Medienwiedergabe und Caffeine; Ambxst-Idle
  aus (Backup).
- Loeschen/Aufraeumen (Speicher, Datenschutz) nur auf Klick mit Bestaetigung.
