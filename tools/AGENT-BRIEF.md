# Brief fuer Modul-Agents (gilt fuer jeden Kandidaten)

## Projekt
luxshell = eigene Quickshell-Dots (Quickshell 0.3.2, Qt 6.12, Hyprland 0.56 Lua-Config), 1:1-Nachbau
einer Dynamic-Island-Shell aus einem Video. Repo `/home/luxend/.config/quickshell/luxshell`.
Lies `SPEC.md` (verbindlich) und die fuer dein Modul genannten `ref/*.png` (2x hochskaliert aus
1280x720, also ca. 1:1 zu 2560x1440). Quickshell-API: `/usr/lib/qt6/qml/Quickshell/**/*.qmltypes`,
Doku https://quickshell.org/docs/.

## Architektur (Stand im Repo-Root, git log)
- `core/Ui.qml`: zentraler Zustand. Prioritaet Panel > Overlay (`Ui.flash(id, ms)`) > Hover > eingeklappt.
  `Ui.open/toggle/close(id)`.
- `core/Panels.qml`: Registry `{ id: { component, kind: "panel"|"overlay", ... } }`; probt beim Start
  jedes Panel einmal (`probe: true`) fuer seine Maximalgroesse (Layer-Surface-Groesse).
- `panels/PanelBase.qml`: Vertrag. `preferredWidth/Height` (Island morpht live mit), `maxWidth/Height`,
  `cornerRadius`, `focusDefault()`, `probe`. Esc schliesst (PanelHost).
- `core/Ipc.qml`: IpcHandler `luxshell` (toggle, open, close, preview, flash, theme, state).
- `config/Theme.qml` (Farbrollen + Mass-Bloecke je Modul am Ende), `config/Themes.qml` (Paletten),
  `config/Motion.qml` (Island-Morph-Timing, `Motion.ms()` fuer Zeitlupe), `config/Settings.qml`
  (persistente Schluessel, `Settings.set(key, value)`), `config/Env.qml` (alle Env-Variablen).
- Services (Singletons): Hypr, Clock, Net, Audio, Apps, Tray, Notifs (Peek + Verlauf), Activities
  (OSD-Bausteine), Bt, Networks, Mixer, Brightness, GameMode, Exec (ALLE Systemaktionen laufen hierueber;
  `LUXSHELL_DRYRUN=1` loggt nur), Wallpapers, ThemeSync.
- Beispiele fuer gute Panels: `panels/Launcher.qml` (+ `panels/launcher/`), `panels/ControlCenter.qml`
  (+ `panels/controlcenter/`), `panels/ThemePicker.qml` (+ `panels/picker/`).

## Settings (seit 2026-10-28)
- Jede Option: Schluessel mit Default in `config/Settings.qml` (Praefix je Bereich: `island*`, `look*`,
  `motion*`, `launcher*`, `notif*`, `cc*`, `media*`, `lock*`, `wallpaper*`, `keys*`, `integration*`),
  Eintrag auf der Seite `apps/settings/pages/<Seite>.qml`, Konsument liest `Settings.x` (live).
  Anleitung, Optionstypen, `setPath` fuer Objekte/Listen: `apps/settings/README.md`.
- Alles wirkt sofort live, jede Option ist per Reset auf den Default zurueckzusetzen.
- luxshell laeuft live mit `QT_SCALE_FACTOR=0.85` (tools/run.sh): in der Sandbox ebenso testen.

## Arbeitskopie
`rsync -a --exclude candidates --exclude ref --exclude .git /home/luxend/.config/quickshell/luxshell/ /home/luxend/.config/quickshell/luxshell/candidates/<dein-name>/`
und nur dort arbeiten. Neue Dateien frei; bestehende nur additiv (Registry-Eintrag, Block am Ende
von Theme.qml, neue Settings-Schluessel, ggf. eine Zeile in shell.qml) - im Bericht auflisten.
`island/*` und `core/Ui.qml` nur wenn zwingend, minimal, begruendet. Kein Git-Commit.

## Testen (Pflicht, nur Sandbox)
`/home/luxend/.config/quickshell/luxshell/tools/sandbox.sh` (ohne Argumente = Hilfe), Sandbox-Name = dein Name.
- `start` verweigert mit Exit 2, wenn ein Monitor schlaeft: dann warten und erneut versuchen, nie umgehen.
- Tastaturfokus nur, wenn per IPC geoeffnet (nicht per LUXSHELL_PREVIEW):
  `. $XDG_RUNTIME_DIR/luxsandbox/<name>.env; hyprctl dispatch 'hl.dsp.focus({monitor="HEADLESS-1"})'; qs -p <shell.qml> ipc call luxshell open <panel>`, dann `wtype`.
- Settings/Cache per `LUXSHELL_CONFIG_DIR` / `LUXSHELL_CACHE_DIR` in einen eigenen Unterordner von
  `/tmp/claude-1000/-home-luxend/5b176542-b076-45ab-afbc-31639687e709/scratchpad/<name>/` (der Scratchpad ist geteilt).
- Fuer Benachrichtigungen/D-Bus-Dienste und ALLES, was Hilfsprogramme mit GUI startet (zenity,
  Dateidialoge, Portale): `sandbox.sh run <name> <dir> LUXSB_DBUS=1 GDK_DEBUG=no-portals ...` (eigener
  Bus), sonst poppen Dialoge auf dem echten Desktop auf.
- Mausklicks: `tools/vclick/` (Bauanleitung im Kopf von vclick.c, `REAL_WAYLAND_DISPLAY=wayland-1 vclick
  <sandbox-display> click|drag DX|wiggle`), Zeiger setzen: `hyprctl dispatch "hl.dsp.cursor.move({ x = 5000+X, y = Y })"`
  gegen die Sandbox-Instanz.
- Immer `LUXSHELL_DRYRUN=1`. Am Ende IMMER `sandbox.sh stop <name>`.

## Verboten
Echten Desktop anfassen (`qs -c luxshell`, Ambxst, ~/.config/hypr, fremde Prozesse), Systemzustand
aendern (Lautstaerke, Netz, BT, Helligkeit, Sperren der ECHTEN Session, Suspend/Reboot/Logout),
User-Dateien veraendern, `pkill -f` mit Mustern, die deine eigene Shell treffen.

## Abgabe
Shots in `candidates/<name>/shots/` (gleiche Crops wie die Refs, damit man vergleichen kann).
Keine QML-Warnungen im Log (`QFont::fromString` und `qt.qpa.wayland.textinput` sind bekannt).
Antwort kurz, deutsch, ohne Em-Dash: Dateien (neu/geaendert), Aufbau in 3-5 Saetzen,
Theme/Settings-Ergaenzungen, Masse, Abweichungen zum Video, Luecken.
