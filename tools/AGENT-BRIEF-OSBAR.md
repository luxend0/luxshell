# Zusatz-Brief Welle "OS + Bar" (2026-10-29)

Erst `tools/AGENT-BRIEF.md` lesen (gilt komplett), dann `SPEC.md` Abschnitt "Welle OS + Bar".
Abweichungen/Ergaenzungen zu AGENT-BRIEF.md:

- Scratchpad (Settings/Cache/Logs der Sandbox):
  `/tmp/claude-1000/-home-luxend/1c7d3856-8742-4708-9e61-f71ca2545f7c/scratchpad/<dein-name>/`
  (der Pfad im alten Brief gilt nicht mehr).
- CPU schonen (der PC ist bei Volllast schon abgestuerzt): Sandbox immer mit
  `nice -n 19 ionice -c3 tools/sandbox.sh ...` starten, keine Builds/Tests parallel laufen lassen,
  kein Polling unter 2 s. Es laufen bis zu 3 Agents gleichzeitig.
- Systemzustand bleibt tabu (BT, Netz, Lautstaerke, Helligkeit, Nachtlicht, Power-Profil,
  Monitor, Eingabe): alles ueber `Exec` mit `LUXSHELL_DRYRUN=1`, Dateien nur im Scratchpad.
- Bar-Widgets: Registry `island/bar/BarRegistry.qml` (Eintrag mit id, name, icon, states, cls,
  reveal, desc, options), Komponente in `island/bar/BarContent.qml` (Component-Block + Zuordnung),
  Widget-Dateien in `island/widgets/` (Vorbilder: VolumeWidget, SysmonWidget, BatteryWidget,
  WeatherWidget, SystemButton). Neue Widgets nur in die Palette, NICHT in das Default-Layout.
  Zum Testen das Layout in deiner Sandbox-Settings-Datei (LUXSHELL_CONFIG_DIR) setzen.
- Mehrere Agents aendern parallel BarRegistry/BarContent/Settings/Theme/Panels/Catalog:
  nur additiv, Bloecke am Ende bzw. als eigene Eintraege, nichts umsortieren oder umformatieren.
- Icons: `widgets/Icons.qml` (Lucide-SVG-Pfade) bzw. `island/widgets/WIcons.qml`, je nachdem was
  die Nachbarn nutzen; neue Icons additiv.
- Abgabe wie im alten Brief, zusaetzlich: welche Settings-Schluessel neu sind und wie man jedes
  neue Panel/Widget per IPC oder Layout in der Sandbox sieht.
