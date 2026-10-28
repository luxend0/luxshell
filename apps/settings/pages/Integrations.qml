import QtQuick
import qs.config
import qs.services
import qs.apps.settings

// Integrations: theme for other apps (kitty, GTK), Hyprland look and blur. Everything
// here changes something outside luxshell, so it is opt-in (default off) and each
// switch says what it touches and how it is undone. Keys: integration* (plus themeExport).
// Logic: services/AppThemes (kitty, GTK), services/HyprLook (Hyprland, blur), services/ThemeSync.
SettingsPage {
    id: page

    pageId: "integrations"
    title: "Integrations"
    subtitle: "Carry the shell's look into other apps. All off until you switch them on."
    icon: 0xF0431

    function state(file: string): string {
        if (AppThemes.blocked)
            return "Dry run: not touched";
        switch (AppThemes.statusOf(file)) {
        case "on":
            return "Included";
        case "off":
            return "Not included";
        case "missing":
            return "No such file";
        }
        return "...";
    }
    function shortPath(p: string): string {
        return AppThemes.tilde(p);
    }
    function savedText(): string {
        const s = HyprLook.saved;
        if (Object.keys(s).length === 0)
            return "Nothing replaced";
        const n = v => String(v).split(" ")[0];
        const parts = [];
        if ("general:border_size" in s)
            parts.push(`border ${s["general:border_size"]}`);
        if ("general:gaps_in" in s)
            parts.push(`gaps ${n(s["general:gaps_in"])}/${n(s["general:gaps_out"])}`);
        if ("decoration:rounding" in s)
            parts.push(`rounding ${s["decoration:rounding"]}`);
        return parts.join(", ");
    }

    Component {
        id: note
        Note {}
    }

    sections: [
        {
            "title": "Theme files",
            "options": [
                {
                    "id": "themeExport",
                    "kind": "switch",
                    "key": "themeExport",
                    "label": "Write theme files to the cache",
                    "keywords": "theme export cache kitty gtk palette json"
                },
                {
                    "id": "themeExportNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "text": () => `kitty-theme.conf, gtk.css and palette.json in ${page.shortPath(Wallpapers.cacheDir)}, rewritten on every theme or accent change. Only luxshell's own cache: nothing reads them until you hook an app up below (which keeps them written even with this switch off).`
                }
            ]
        },
        {
            "title": "kitty",
            "options": [
                {
                    "id": "integrationKitty",
                    "kind": "switch",
                    "key": "integrationKitty",
                    "label": "Theme kitty",
                    "keywords": "terminal kitty colours colors include"
                },
                {
                    "id": "integrationKittyState",
                    "kind": "info",
                    "label": "kitty.conf",
                    "keywords": "kitty config include status",
                    "value": () => `${page.state(AppThemes.kittyConf)}`
                },
                {
                    "id": "integrationKittyNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "text": () => `On: adds two lines at the end of ${page.shortPath(AppThemes.kittyConf)}, a "# luxshell theme" comment and "include ${page.shortPath(AppThemes.kittyTheme)}" (the file is created if missing; the first edit keeps a copy as kitty.conf.bak-luxshell). Running kitty windows reload their config (SIGUSR1) now and on every theme change. Off: exactly those two lines are removed again and kitty reloads with your own colours.`
                }
            ]
        },
        {
            "title": "GTK 3 and 4",
            "options": [
                {
                    "id": "integrationGtk",
                    "kind": "switch",
                    "key": "integrationGtk",
                    "label": "Theme GTK apps",
                    "keywords": "gtk gtk3 gtk4 libadwaita adwaita css colours colors import"
                },
                {
                    "id": "integrationGtk3State",
                    "kind": "info",
                    "label": "gtk-3.0/gtk.css",
                    "keywords": "gtk3 config import status",
                    "value": () => page.state(AppThemes.gtkFiles[0])
                },
                {
                    "id": "integrationGtk4State",
                    "kind": "info",
                    "label": "gtk-4.0/gtk.css",
                    "keywords": "gtk4 libadwaita config import status",
                    "value": () => page.state(AppThemes.gtkFiles[1])
                },
                {
                    "id": "integrationGtkNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "text": () => `On: puts one line, @import url("file://${page.shortPath(AppThemes.gtkTheme)}") with a "luxshell theme" comment, at the top of gtk.css in ${page.shortPath(AppThemes.configHome)}/gtk-3.0 and gtk-4.0 (files created if missing, first edit kept as gtk.css.bak-luxshell). GTK apps (libadwaita, adw-gtk3) read the accent and background colours when they start. Off: that line is removed from both files.`
                }
            ]
        },
        {
            "title": "Hyprland",
            "options": [
                {
                    "id": "integrationHypr",
                    "kind": "switch",
                    "key": "integrationHypr",
                    "label": "Match Hyprland to the shell",
                    "keywords": "hyprland border gaps rounding windows look compositor"
                },
                {
                    "id": "integrationHyprNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "text": "On: sets the parts below live with hyprctl eval (nothing is written to your Hyprland config). The values they replace are read first and kept; switching a part off puts its value back, switching this off restores all of them. A config reload brings your own values back, then they are read again and the look re-applied. Another shell that sets the same options (Ambxst) overrides it on its next apply."
                },
                {
                    "id": "integrationHyprBorder",
                    "kind": "switch",
                    "key": "integrationHyprBorder",
                    "label": "Window border in the accent colour",
                    "keywords": "hyprland border active inactive colour color",
                    "enabled": () => Settings.integrationHypr
                },
                {
                    "id": "integrationHyprBorderSize",
                    "kind": "slider",
                    "key": "integrationHyprBorderSize",
                    "label": "Border width",
                    "keywords": "hyprland border size thickness",
                    "enabled": () => Settings.integrationHypr && Settings.integrationHyprBorder,
                    "min": 0,
                    "max": 6,
                    "step": 1,
                    "format": v => `${v} px`
                },
                {
                    "id": "integrationHyprGaps",
                    "kind": "switch",
                    "key": "integrationHyprGaps",
                    "label": "Gaps",
                    "keywords": "hyprland gaps spacing windows",
                    "enabled": () => Settings.integrationHypr
                },
                {
                    "id": "integrationHyprGapsIn",
                    "kind": "slider",
                    "key": "integrationHyprGapsIn",
                    "label": "Gaps between windows",
                    "keywords": "hyprland gaps_in inner",
                    "enabled": () => Settings.integrationHypr && Settings.integrationHyprGaps,
                    "min": 0,
                    "max": 30,
                    "step": 1,
                    "format": v => `${v} px`
                },
                {
                    "id": "integrationHyprGapsOut",
                    "kind": "slider",
                    "key": "integrationHyprGapsOut",
                    "label": "Gaps to the screen edge",
                    "keywords": "hyprland gaps_out outer",
                    "enabled": () => Settings.integrationHypr && Settings.integrationHyprGaps,
                    "min": 0,
                    "max": 60,
                    "step": 1,
                    "format": v => `${v} px`
                },
                {
                    "id": "integrationHyprRounding",
                    "kind": "switch",
                    "key": "integrationHyprRounding",
                    "label": "Window rounding",
                    "keywords": "hyprland rounding corners radius",
                    "enabled": () => Settings.integrationHypr
                },
                {
                    "id": "integrationHyprRadius",
                    "kind": "slider",
                    "key": "integrationHyprRadius",
                    "label": "Rounding (× Appearance corner radius)",
                    "keywords": "hyprland rounding corners radius px",
                    "enabled": () => Settings.integrationHypr && Settings.integrationHyprRounding,
                    "min": 0,
                    "max": 30,
                    "step": 1,
                    "format": v => Theme.radiusScale === 1 ? `${v} px` : `${v} px → ${Math.round(v * Theme.radiusScale)} px`
                },
                {
                    "id": "integrationHyprSaved",
                    "kind": "info",
                    "label": "Saved to restore",
                    "keywords": "hyprland original values restore",
                    "value": () => HyprLook.lastError !== "" ? HyprLook.lastError : page.savedText()
                }
            ]
        },
        {
            "title": "Blur",
            "options": [
                {
                    "id": "integrationBlur",
                    "kind": "switch",
                    "key": "integrationBlur",
                    "label": "Blur behind the island and panels",
                    "keywords": "blur frosted glass layer rule hyprland transparency"
                },
                {
                    "id": "integrationBlurNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "text": () => `Adds the Hyprland layer rule "luxshell-blur" for the island while it is translucent (Appearance > Transparency below 100 %${Theme.look.translucent ? "" : ", now 100 %: no rule"}); needs blur enabled in Hyprland. Nothing is written to your config. Off, or back at 100 %: the rule is switched off; a config reload removes it too.`
                }
            ]
        }
    ]
}
