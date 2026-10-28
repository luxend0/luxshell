import QtQuick
import qs.config
import qs.core

// Appearance (ref/12): theme, accent, type. Keys: look* (plus theme, accent, fontFamily, fontSize).
SettingsPage {
    id: page

    pageId: "appearance"
    title: "Appearance"
    subtitle: "Theme, wallpaper, accent colour and fonts."
    icon: 0xF03D8
    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "theme",
                    "kind": "link",
                    "label": "Theme",
                    "keywords": "palette colours colors dark",
                    "keys": ["theme"],
                    "value": () => Theme.name,
                    "run": () => Ui.open("themes")
                },
                {
                    "id": "wallpaper",
                    "kind": "link",
                    "label": "Wallpaper",
                    "keywords": "background image video",
                    "value": () => "Choose...",
                    "run": () => Ui.open("wallpaper")
                }
            ]
        },
        {
            "title": "Accent",
            "options": [
                {
                    "id": "accent",
                    "kind": "swatches",
                    "key": "accent",
                    "label": "Accent colour",
                    "keywords": "color highlight tint",
                    "colours": () => [Theme.pal.accent, ...Theme.swatches]
                },
                {
                    "id": "accentCustom",
                    "kind": "text",
                    "label": "Custom (#rrggbb)",
                    "keywords": "accent colour color hex",
                    "resettable": false, // the swatch row above resets "accent"
                    "value": () => page.hex(Theme.accent),
                    "placeholder": "#rrggbb",
                    "valid": t => /^#?[0-9a-fA-F]{6}$/.test(t.trim()) || t.trim() === "",
                    "apply": t => {
                        const v = t.trim();
                        Settings.set("accent", v === "" ? "" : (v.startsWith("#") ? v : "#" + v).toLowerCase());
                    }
                },
                {
                    "id": "themeExport",
                    "kind": "switch",
                    "key": "themeExport",
                    "label": "Export colours (kitty, GTK and palette.json)",
                    "keywords": "theme export cache terminal gtk"
                }
            ]
        },
        {
            "title": "Type",
            "options": [
                {
                    "id": "fontSize",
                    "kind": "slider",
                    "key": "fontSize",
                    "label": "Font size",
                    "keywords": "text scale",
                    "min": 12,
                    "max": 20,
                    "step": 1,
                    "format": v => `${v} px`
                },
                {
                    "id": "fontFamily",
                    "kind": "font",
                    "key": "fontFamily",
                    "label": "Font",
                    "keywords": "typeface family inter"
                }
            ]
        }
    ]
}
