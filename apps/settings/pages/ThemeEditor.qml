import QtQuick
import qs.config
import qs.apps.settings

// Theme editor: works on the APPLIED theme, so every change shows on the whole shell at
// once (island, panels, this window). Built-in themes are read-only: "Duplicate" copies
// the applied theme into a custom one (config/CustomThemes, ~/.config/luxshell/themes/<name>.json)
// and applies it. Custom themes can be renamed and deleted; each colour has its own reset,
// back to the colour of the theme it was duplicated from.
SettingsPage {
    id: page

    pageId: "themeeditor"
    title: "Theme editor"
    subtitle: "Copy a theme and change its colours. It joins the theme picker."
    icon: 0xF08B5

    // the applied theme (never the picker's live preview)
    readonly property string themeId: Themes.palettes.hasOwnProperty(Settings.theme) ? Settings.theme : "noir"
    readonly property bool custom: CustomThemes.isCustom(themeId)

    function paletteColour(path: string): string {
        const p = Themes.palettes[themeId] ?? Themes.fixed.noir;
        const v = path.startsWith("swatches.") ? p.swatches[parseInt(path.slice(9))] : p[path];
        return String(v ?? "").toLowerCase();
    }

    // store for the colour rows (same API as config/Settings for plain keys)
    QtObject {
        id: colours

        function get(k: string): string {
            return page.custom ? CustomThemes.colour(page.themeId, k) : page.paletteColour(k);
        }
        function set(k: string, v: var): bool {
            return CustomThemes.setColour(page.themeId, k, String(v));
        }
        function defaultOf(k: string): string {
            const s = page.custom ? CustomThemes.sourceColour(page.themeId, k) : "";
            return s !== "" ? s.toLowerCase() : get(k);
        }
        function isDefault(k: string): bool {
            if (!page.custom)
                return true;
            const s = CustomThemes.sourceColour(page.themeId, k);
            return s === "" || s.toLowerCase() === get(k);
        }
        function reset(k: string): void {
            const s = page.custom ? CustomThemes.sourceColour(page.themeId, k) : "";
            if (s !== "")
                set(k, s.toLowerCase());
        }
    }

    function role(key: string, label: string, keywords: string): var {
        return {
            "id": "themeColour_" + key.replace(".", "_"),
            "kind": "color",
            "store": colours,
            "key": key,
            "label": label,
            "keywords": "theme colour color palette " + keywords,
            "enabled": () => page.custom,
            "swatches": () => [...new Set(["island", "base", "surface", "surfaceHigh", "text", "textDim", "accent"].map(r => page.paletteColour(r)))]
        };
    }

    Component {
        id: note
        Note {}
    }

    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "themeEditorTheme",
                    "kind": "choice",
                    "key": "theme",
                    "resettable": false, // Appearance > Theme resets it; here it only picks what to edit
                    "label": "Theme",
                    "keywords": "palette applied current edit custom",
                    "searchable": true,
                    "options": () => Themes.names.map(n => ({
                                "value": n,
                                "label": n,
                                "detail": CustomThemes.isCustom(n) ? "custom" : n === "wallpaper" ? "from wallpaper" : ""
                            }))
                },
                {
                    "id": "themeDuplicate",
                    "kind": "button",
                    "label": "Duplicate as a new theme",
                    "keywords": "copy new create custom theme",
                    "value": () => `→ ${CustomThemes.uniqueId(page.themeId + "-copy")}`,
                    "action": "Duplicate",
                    "run": () => {
                        const id = CustomThemes.duplicate(page.themeId);
                        Settings.set("theme", id);
                        SettingsApp.toast(`Created "${id}"`, null);
                    }
                },
                {
                    "id": "themeName",
                    "kind": "text",
                    "label": "Name",
                    "keywords": "rename theme name file",
                    "resettable": false,
                    "enabled": () => page.custom,
                    "value": () => page.themeId,
                    "placeholder": "my-theme",
                    "valid": t => !page.custom || CustomThemes.nameError(t, page.themeId) === "",
                    "apply": t => {
                        const to = CustomThemes.rename(page.themeId, t);
                        if (to !== "" && to !== page.themeId)
                            SettingsApp.toast(`Renamed to "${to}"`, null);
                    }
                },
                {
                    "id": "themeFile",
                    "kind": "info",
                    "label": "File",
                    "keywords": "theme json path folder",
                    "value": () => page.custom ? Catalog.tilde(CustomThemes.fileOf(page.themeId)) : "Built-in, read-only (duplicate to edit)"
                },
                {
                    "id": "themeDelete",
                    "kind": "button",
                    "label": "Delete this theme",
                    "keywords": "remove theme custom",
                    "value": () => page.custom && CustomThemes.sourceOf(page.themeId) !== "" ? `then ${Themes.palettes.hasOwnProperty(CustomThemes.sourceOf(page.themeId)) ? CustomThemes.sourceOf(page.themeId) : "noir"}` : "",
                    "action": "Delete",
                    "confirm": () => `Delete "${page.themeId}"?`,
                    "enabled": () => page.custom,
                    "run": () => {
                        const id = page.themeId;
                        CustomThemes.remove(id);
                        SettingsApp.toast(`Deleted "${id}"`, null);
                    }
                }
            ]
        },
        {
            "title": "Surfaces",
            "options": [
                page.role("island", "Island and panels", "background black bar"),
                page.role("base", "Base (theme card, kitty and GTK background)", "background window"),
                page.role("surface", "Surface (cards)", "card tile"),
                page.role("surfaceHigh", "Raised surface (controls, inactive border)", "control field sidebar"),
                page.role("muted", "Muted", "inactive border line"),
                page.role("wsOccupied", "Workspace, occupied", "capsule pill"),
                page.role("wsEmpty", "Workspace, empty", "capsule pill")
            ]
        },
        {
            "title": "Text and accent",
            "options": [
                page.role("text", "Text", "foreground font"),
                page.role("textSecondary", "Text, secondary", "foreground grey"),
                page.role("textDim", "Text, dim", "foreground grey hint"),
                page.role("accent", "Accent", "highlight active slider toggle"),
                page.role("onAccent", "Text on accent", "contrast foreground")
            ]
        },
        {
            "title": "Swatches (theme picker dots, terminal colours 1-6)",
            "options": [
                page.role("swatches.0", "Red", "ansi swatch"),
                page.role("swatches.1", "Green", "ansi swatch"),
                page.role("swatches.2", "Yellow", "ansi swatch"),
                page.role("swatches.3", "Blue", "ansi swatch"),
                page.role("swatches.4", "Magenta", "ansi swatch"),
                page.role("swatches.5", "Cyan", "ansi swatch"),
                {
                    "id": "themeEditorNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "text": "The accent picked under Appearance > Accent still wins over the theme's own. The power button stays red in every theme."
                }
            ]
        }
    ]
}
