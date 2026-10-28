# Settings app: how to add options

Everything the user can set lives in two places:

| What | Where |
|---|---|
| the value, its default, persistence | `config/Settings.qml` (one property per key) |
| the row in the settings app | `apps/settings/pages/<Page>.qml` (data, one file per page) |

`apps/settings/Catalog.qml` only lists the pages (sidebar order) and fills in the
boilerplate of options that name a `key`. The window (`SettingsWindow.qml`) and the row
family (`OptionRow.qml` + `*Ctl.qml`) render any page; you normally never touch them.

## The rule: everything is live

A consumer **binds** to `Settings.<key>` (or reads it inside a binding / function called
from one). A change in the app, via IPC or by editing `settings.json` by hand applies at
once, without a restart. The one exception is marked in its label (`uiScale`: "(restart)").
Things outside luxshell (keybinds, kitty/GTK theme, Hyprland look) are opt-in: their
switch defaults to `false`.

## Add an option (3 steps)

1. **Key + default** in `config/Settings.qml`, in the block of your area:

   ```qml
   // ---- island* : Bar & Island ----
   property int islandHeight: 42 // px of the collapsed island (island/Island.qml)
   ```

   The initial value *is* the default (one place). Literals only, no bindings. Types:
   `string`, `bool`, `int`, `real`, `list<string>`, `var` (objects / arrays). No
   `color`/`url` properties: colours are `"#rrggbb"` strings.

2. **Row** in the page file:

   ```js
   {
       "id": "islandHeight",
       "kind": "slider",
       "key": "islandHeight",
       "label": "Island height",
       "keywords": "size bar collapsed",
       "min": 36, "max": 56, "step": 1,
       "format": v => `${v} px`
   }
   ```

   With `key`, the row reads, writes, shows its reset arrow and resets by itself.

3. **Consumer**: `height: Settings.islandHeight`.

## Add a page (1 file + 1 line)

```qml
// apps/settings/pages/Island.qml
import QtQuick
import qs.config
SettingsPage {
    pageId: "island"
    title: "Island"
    subtitle: "One line under the title."
    icon: 0xF1513            // Material Design codepoint of the Nerd Font
    sections: [{ "title": "", "options": [ ... ] }]
}
```

then one line in `Catalog.qml` `sources`, at its sidebar position. A page without options
(or `hidden: true`) stays out of the sidebar and search. Timers, Processes and Components
the page needs go straight inside it (see `pages/Motion.qml`, `pages/Launcher.qml`).
Existing pages: `BarIsland, Media, ClockDate, Appearance, Wallpaper, Motion, Launcher,
OverviewPickers, Notifications, ControlCenter, LockScreen, Keybinds, Integrations, System, Demo`.
Reusable custom rows in `pages/`: `HiddenList.qml` (ids to exclude, "Add" opens a filterable
dropdown: launcher apps, media players), `CcPreview.qml` (the control center's real main page,
scaled down, live).

## Key prefixes per area

| Prefix | Page |
|---|---|
| `island*` | Bar & Island (layout, size, workspaces, click/scroll) |
| `look*` | Appearance (colours, font, radius, transparency/blur, shadow, border, scale) |
| `motion*` | Motion (animations, hover delays) |
| `launcher*` | Launcher (modes, prefixes) |
| `notif*` | Notifications (focus schedule, app exceptions) |
| `cc*` | Control Center (tiles, order) |
| `media*` | Media |
| `overview*` | Overview & Pickers (workspace overview) |
| `picker*` | Overview & Pickers (theme / wallpaper picker; `wallpaperVideos` keeps the wallpaper prefix) |
| `lock*` | Lock Screen |
| `wallpaper*` | Wallpaper |
| `keys*` | Keybinds (outside luxshell, default off) |
| `integration*` | apps theme, Hyprland look (outside luxshell, default off) |

Keys from before the prefixes (`theme`, `accent`, `fontFamily`, `fontSize`, `hoverHold`,
`workspaceCount`, ...) keep their names: never rename a key. If one really has to move,
add `"old": "new"` to `_renamed` in Settings.qml (applied when the file is read or imported).
Runtime state that is no preference (`gameMode`, `gameModeSaved`) belongs in `_state`:
never exported, imported or reset by "Reset all".

## Settings API

```js
Settings.get("islandLayout.hover.left")      // key or path into an object key
Settings.set("hoverHold", 200)                // validated: unknown key / wrong type -> warning, false
Settings.setPath("islandLayout.hover.left", ["clock", "media"])
Settings.reset("hoverHold"); Settings.resetMany([...]); Settings.resetAll()
Settings.isDefault("hoverHold")               // live in bindings
Settings.defaultOf("hoverHold")
Settings.keys(); Settings.isState(key)
Settings.snapshot(); Settings.restore(snap)   // undo for bulk changes
Settings.exportData(); Settings.importData(obj)
Settings.edited(key)                          // signal after any change
```

`settings.json` holds only values that differ from the default (sparse), so a changed
default reaches everyone who never touched the key. Keys the running version does not
know are kept on save (other branches, newer versions). A value of the wrong type in the
file falls back to the default with a warning; invalid JSON is copied to
`settings.json.broken` and the current values stay.

### Objects and lists (island layout, tile order, app exceptions)

Use a `var` key. Every write replaces the whole value (`set`/`setPath` clone, change and
reassign), which is what makes bindings fire:

```qml
property var islandLayout: ({ "hover": { "left": ["clock"], "right": ["status"] } })
```

```js
Settings.setPath("islandLayout.hover.left", ["media", "clock"]) // live
Settings.reset("islandLayout.hover")                             // only that branch
Settings.islandLayout.hover.left.push("x")                       // WRONG: in place, no signal, not saved
```

## Option fields (all kinds)

| Field | Meaning |
|---|---|
| `id`, `kind`, `label` | required (`label` may be "" for a bare `custom` row) |
| `keywords` | extra search words |
| `key` | Settings key or path: fills `value`, `set`, reset, tip |
| `keys` | what the reset arrow restores, when it is not just `[key]` (links, compound rows) |
| `store` | object with `get/set/isDefault/reset/defaultOf` instead of Settings (see `pages/Demo.qml`) |
| `resettable: false` | no reset arrow (e.g. a second row for the same key) |
| `enabled()` | greyed out while false |
| `value()`, `set(v)` | override what `key` gives (service-backed rows, e.g. Game Mode) |
| `modified()`, `reset()`, `defaultValue()` | override the reset behaviour |
| `summary()` | text on the label line of tall rows (default: "3 of 6", "2 folders") |

Functions are called inside bindings, so everything they read stays live. Read live state
only inside these functions: a binding in `sections` itself rebuilds every row of the page.

## Kinds

| Kind | Value | Extra fields |
|---|---|---|
| `link` | text + arrow | `run()` |
| `choice` | dropdown | `options()` -> `[{ value, label, detail, font }]`; long lists scroll + filter (`searchable: true` forces it) |
| `font` | installed font families, filterable, each shown in itself | `mono: true` (fontconfig monospace only) |
| `switch` | bool | |
| `slider` | number | `min`, `max`, `step`, `format(n)` |
| `swatches` | accent discs, `""` = theme accent | `colours()` |
| `text` | string field | `placeholder`, `valid(t)`, `apply(t)` (default: set) |
| `button` | action | `action` (text or function), `run()`, `confirm` (text: first click asks) |
| `info` | read-only text | |
| `color` | `"#rrggbb"`, picker (saturation/value, hue, hex, swatches) | `allowEmpty` + `emptyLabel` + `fallback()` (`""` = default colour), `swatches()` |
| `list` | ordered enabled values `["wifi", "bt"]` | `items()` -> `[{ value, label, icon }]`; `toggle: false` = order only |
| `time` | `"HH:MM"` | `step` (minutes, wheel and Left/Right) |
| `timerange` | `{ "from": "22:00", "to": "07:00" }` | `step` |
| `weekdays` | ISO days `[1..7]`, 1 = Monday | |
| `path` | one path (`~/...` under $HOME) | `mode`: `file` / `folder` / `save`, `placeholder`; Browse = zenity |
| `paths` | list of paths, missing ones marked | `mode`, `addLabel`, `placeholder` |
| `custom` | anything | `component` (a `Component` declared in the page) |

`pages/Demo.qml` has one row of every new kind; start the shell with
`LUXSHELL_SETTINGS_DEMO=1` to see the "Option types" page.

### `custom` rows

```qml
Component { id: editor; IslandEditor {} }   // inside the page
{ "id": "islandLayout", "kind": "custom", "key": "islandLayout", "label": "Layout", "component": editor }
```

The row sets these properties on your root item if it declares them: `opt` (the option:
`opt.value()`, `opt.set(v)`), `row` (the OptionRow: `row.focused`), `host`. It takes your
`implicitHeight`. Keys are forwarded when your item has the function: `activate()`
Enter/Space, `adjust(d)` Left/Right, `navigate(d, mods)` Up/Down inside the row (return
false to leave it), `enter(d)` focus arrives from above (1) / below (-1), `deleteKey()`,
`focusRect()` `{ y, h }` to keep in view. Example: `pages/DemoZones.qml` (drag to reorder).

Inside your own controls do not write `row: row` (the property shadows the id); name it
differently (`owner: row`).

## Reset and undo

- Per option: the quiet arrow next to a changed control (tip shows the default), or
  Delete/Backspace on the focused row.
- Per page: "Reset page" in the header card, or Ctrl+Backspace. The toast offers Undo.
- Everything: System > "Reset all settings" (asks once, Undo in the toast).

## Backup and IPC

System > Backup exports / imports one JSON file (`Backup.qml`, runtime state excluded,
import replaces every preference and can be undone). Scriptable:

```sh
qs -c luxshell ipc call settings get hoverHold
qs -c luxshell ipc call settings set hoverHold 240          # JSON; a bare word is a string
qs -c luxshell ipc call settings set islandLayout.hover.left ' ["clock", "media"]'  # arrays: leading space (the qs CLI splits [a,b])
qs -c luxshell ipc call settings reset hoverHold
qs -c luxshell ipc call settings resetPage notifications
qs -c luxshell ipc call settings changed
qs -c luxshell ipc call settings exportFile ~/luxshell-settings.json
qs -c luxshell ipc call settings importFile ~/luxshell-settings.json
```

## Keyboard (settings window)

Typing searches, Up/Down rows (and the entries of list/folder rows), Shift+Up/Down moves a
list entry, Left/Right adjusts, Enter/Space activates, Delete resets, Ctrl+Backspace resets
the page, Tab switches sidebar/page, Alt+Left/Right back/forward, Esc clears/closes.
