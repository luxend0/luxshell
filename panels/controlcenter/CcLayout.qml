pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.services

// What the control center's main page shows and where (Settings.ccTiles / ccSliders), for
// the panel (MainPage.qml) and the settings preview (apps/settings/pages/CcPreview.qml).
//
// Packing, in reading order: a row takes up to Theme.ccLayout.maxTiles tiles; a round
// button joins the row while every tile of it stays >= minTile wide; tiles share what the
// round buttons leave, so the measured sizes come out by themselves (default: Wi-Fi,
// Focus, lock = 270 + 270 + 80; Bluetooth, Game Mode = 317 + 317). A row of round buttons
// only starts at the left. Then one slider card per row, full width. Same pad, gaps and
// row height as ref/08 (Theme.cc); the panel height follows the row count.
//
//   catalog            every tile / round button: { id, kind, label, glyph, sheet, available }
//   sliderCatalog      every slider card: { id, label, glyph, sheet }
//   slots              { key: { id, kind, x, y, w, h } } for the shown items; key = tile id,
//                      sliders "s:<id>" (the microphone has a tile and a slider)
//   keys               the shown keys in reading order
//   height             main page height (2 pads + rows); empty = one row for the hint
Singleton {
    id: root

    readonly property QtObject cc: Theme.cc
    readonly property QtObject lay: Theme.ccLayout

    // glyph: Material Design codepoint (settings app rows), the panel draws Lucide (Glyphs)
    readonly property var catalog: [
        { "id": "network", "kind": "tile", "label": "Network (Wi-Fi / Ethernet)", "glyph": 0xF05A9, "sheet": "network", "available": true },
        { "id": "focus", "kind": "tile", "label": "Focus", "glyph": 0xF0377, "sheet": "", "available": true },
        { "id": "bluetooth", "kind": "tile", "label": "Bluetooth", "glyph": 0xF00AF, "sheet": "bluetooth", "available": true },
        { "id": "gamemode", "kind": "tile", "label": "Game Mode", "glyph": 0xF0297, "sheet": "", "available": true },
        { "id": "nightlight", "kind": "tile", "label": "Night Light (wlsunset)", "glyph": 0xF0594, "sheet": "", "available": NightLight.available },
        { "id": "caffeine", "kind": "tile", "label": "Caffeine (stay awake)", "glyph": 0xF0176, "sheet": "", "available": true },
        { "id": "mic", "kind": "tile", "label": "Microphone mute", "glyph": 0xF036C, "sheet": "", "available": true },
        { "id": "power", "kind": "tile", "label": "Power mode", "glyph": 0xF04C5, "sheet": "", "available": PowerProfile.available },
        { "id": "lock", "kind": "round", "label": "Lock (round button)", "glyph": 0xF033E, "sheet": "", "available": true },
        { "id": "screenshot", "kind": "round", "label": "Screenshot (round button)", "glyph": 0xF0E51, "sheet": "", "available": true },
        { "id": "theme", "kind": "round", "label": "Theme switch (round button)", "glyph": 0xF050E, "sheet": "", "available": true }
    ]
    readonly property var sliderCatalog: [
        { "id": "sound", "label": "Sound", "glyph": 0xF057E, "sheet": "sound" },
        { "id": "display", "label": "Display", "glyph": 0xF00DF, "sheet": "display" },
        { "id": "mic", "label": "Microphone", "glyph": 0xF036C, "sheet": "" }
    ]

    function entry(id: string): var {
        return catalog.find(c => c.id === id) ?? null;
    }

    // shown ids: known, available, once each
    function tileIds(list: var): var {
        const out = [];
        for (const id of Array.from(list ?? [])) {
            const e = entry(id);
            if (e && e.available && !out.includes(id))
                out.push(id);
        }
        return out;
    }
    function sliderIds(list: var): var {
        const out = [];
        for (const id of Array.from(list ?? []))
            if (sliderCatalog.some(s => s.id === id) && !out.includes(id))
                out.push(id);
        return out;
    }

    // rows of { kind, id } for the tiles (see header)
    function pack(ids: var): var {
        const W = cc.width - 2 * cc.pad;
        const rows = [];
        let row = null;
        const fits = (r, kind) => {
            const t = r.tiles + (kind === "tile" ? 1 : 0);
            const n = r.items.length + 1;
            const rounds = n - t;
            if (t > lay.maxTiles)
                return false;
            const free = W - rounds * cc.row - (n - 1) * cc.gapX;
            return t > 0 ? free / t >= lay.minTile : free >= 0;
        };
        for (const id of ids) {
            const kind = entry(id).kind;
            if (!row || !fits(row, kind)) {
                row = {
                    "items": [],
                    "tiles": 0
                };
                rows.push(row);
            }
            row.items.push({
                "id": id,
                "kind": kind
            });
            if (kind === "tile")
                row.tiles++;
        }
        return rows;
    }

    // slots of a whole layout (also used by the settings preview with unsaved lists)
    function compute(tileList: var, sliderList: var): var {
        const W = cc.width - 2 * cc.pad;
        const step = cc.row + cc.gapY;
        const slots = {};
        const keys = [];
        const rows = pack(tileIds(tileList));
        rows.forEach((r, i) => {
            const y = cc.pad + i * step;
            const rounds = r.items.length - r.tiles;
            const free = W - rounds * cc.row - (r.items.length - 1) * cc.gapX;
            const tw = r.tiles > 0 ? Math.floor(free / r.tiles) : 0;
            let x = cc.pad;
            let tilesLeft = r.tiles;
            for (const it of r.items) {
                // the last tile takes the rounding rest, so the row ends flush
                const w = it.kind === "round" ? cc.row : (--tilesLeft === 0 ? free - tw * (r.tiles - 1) : tw);
                slots[it.id] = {
                    "id": it.id,
                    "kind": it.kind,
                    "x": x,
                    "y": y,
                    "w": w,
                    "h": cc.row
                };
                keys.push(it.id);
                x += w + cc.gapX;
            }
        });
        const sliders = sliderIds(sliderList);
        sliders.forEach((id, i) => {
            const key = "s:" + id;
            slots[key] = {
                "id": id,
                "kind": "slider",
                "x": cc.pad,
                "y": cc.pad + (rows.length + i) * step,
                "w": W,
                "h": cc.row
            };
            keys.push(key);
        });
        const n = rows.length + sliders.length;
        return {
            "slots": slots,
            "keys": keys,
            "rows": n,
            "height": 2 * cc.pad + Math.max(1, n) * cc.row + Math.max(0, n - 1) * cc.gapY
        };
    }

    readonly property var current: compute(Settings.ccTiles, Settings.ccSliders)
    readonly property var slots: current.slots
    readonly property var keys: current.keys
    readonly property int height: current.height
    readonly property bool empty: current.rows === 0
}
