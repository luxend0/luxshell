import QtQuick
import Quickshell
import qs.config
import qs.core
import qs.apps.settings

// Appearance (ref/12): theme, accent, type, shape, transparency, scale. Keys: look* (plus
// theme, accent, fontFamily, fontSize, uiScale, integrationBlur). Every default is the
// video's look; everything applies live except the interface scale (restart).
SettingsPage {
    id: page

    pageId: "appearance"
    title: "Appearance"
    subtitle: "Theme, accent colour, fonts, corners, transparency and scale."
    icon: 0xF03D8

    // ---- restart (interface scale is read by tools/run.sh at start) ----------------------
    // the scale this instance runs with (QT_SCALE_FACTOR from tools/run.sh)
    readonly property real runningScale: parseFloat(Env.get("QT_SCALE_FACTOR")) || 1
    function restart(): void {
        const dir = Quickshell.shellDir;
        const live = dir === Env.get("HOME") + "/.config/quickshell/luxshell";
        // a new instance through the start path waits for this one to exit; outside the
        // live config (sandbox, candidates) it starts the same folder again
        const argv = ["env", `LUXSHELL_WAIT_PID=${Quickshell.processId}`];
        if (!live)
            argv.push(`LUXSHELL_SHELL_PATH=${dir}`);
        argv.push(dir + "/tools/run.sh");
        console.info(`luxshell: restarting (${argv.join(" ")})`);
        Quickshell.execDetached(argv);
        quitTimer.start();
    }
    Timer {
        id: quitTimer
        interval: 150 // settings.json is written 60 ms after a change: let it land first
        onTriggered: Qt.quit()
    }

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
                    "id": "themeEditorLink",
                    "kind": "link",
                    "label": "Create and edit themes",
                    "keywords": "custom theme editor colours colors duplicate own palette",
                    "value": () => {
                        const n = CustomThemes.ids.length;
                        return n === 0 ? "Duplicate one" : n === 1 ? "1 custom" : `${n} custom`;
                    },
                    "run": () => SettingsApp.navigate("themeeditor")
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
                    "mono": true,
                    "value": () => page.hex(Theme.accent),
                    "placeholder": "#rrggbb",
                    "valid": t => /^#?[0-9a-fA-F]{6}$/.test(t.trim()) || t.trim() === "",
                    "apply": t => {
                        const v = t.trim();
                        Settings.set("accent", v === "" ? "" : (v.startsWith("#") ? v : "#" + v).toLowerCase());
                    }
                }
            ]
        },
        {
            "title": "Type",
            "options": [
                {
                    "id": "fontFamily",
                    "kind": "font",
                    "key": "fontFamily",
                    "label": "Font (whole shell)",
                    "keywords": "typeface family inter island panels"
                },
                {
                    "id": "lookFontScale",
                    "kind": "slider",
                    "key": "lookFontScale",
                    "label": "Text size (whole shell)",
                    "keywords": "font size scale bigger smaller island panels factor",
                    "min": 0.8,
                    "max": 1.3,
                    "step": 0.05,
                    "format": v => `${Math.round(v * 100)} %`
                },
                {
                    "id": "lookMonoFont",
                    "kind": "choice",
                    "key": "lookMonoFont",
                    "label": "Monospace font",
                    "keywords": "mono code terminal typeface launcher command calculator hex",
                    "searchable": true,
                    // the monospace list comes from fc-list on first use (Catalog); asked outside the binding
                    "options": () => {
                        if (!Catalog.monoAsked)
                            Qt.callLater(() => Catalog.fontOptions(true, ""));
                        const cur = Settings.lookMonoFont;
                        const fams = Catalog.monoFamilies.includes(cur) || cur === "" ? Catalog.monoFamilies : [cur, ...Catalog.monoFamilies];
                        return [
                            {
                                "value": "",
                                "label": "Same as the font",
                                "detail": ""
                            },
                            ...fams.map(f => ({
                                        "value": f,
                                        "label": f,
                                        "detail": "",
                                        "font": f
                                    }))
                        ];
                    }
                },
                {
                    "id": "fontSize",
                    "kind": "slider",
                    "key": "fontSize",
                    "label": "Settings window text",
                    "keywords": "font size text scale settings app",
                    "min": 12,
                    "max": 20,
                    "step": 1,
                    "format": v => `${v} px`
                }
            ]
        },
        {
            "title": "Shape",
            "options": [
                {
                    "id": "lookRadiusScale",
                    "kind": "slider",
                    "key": "lookRadiusScale",
                    "label": "Corner radius (island, panels, cards)",
                    "keywords": "rounding round corners square radius factor",
                    "min": 0,
                    "max": 1.6,
                    "step": 0.05,
                    "format": v => v === 0 ? "Square" : `${Math.round(v * 100)} %`
                },
                {
                    "id": "lookEars",
                    "kind": "switch",
                    "key": "lookEars",
                    "label": "Ears (concave corners at the screen edge)",
                    "keywords": "fillet concave corners island edge notch"
                },
                {
                    "id": "lookBorder",
                    "kind": "switch",
                    "key": "lookBorder",
                    "label": "Outline (island and panels)",
                    "keywords": "border stroke line edge frame"
                },
                {
                    "id": "lookBorderWidth",
                    "kind": "slider",
                    "key": "lookBorderWidth",
                    "label": "Outline width",
                    "keywords": "border stroke thickness",
                    "enabled": () => Settings.lookBorder,
                    "min": 0.5,
                    "max": 4,
                    "step": 0.5,
                    "format": v => `${page.trim(v)} px`
                },
                {
                    "id": "lookBorderColor",
                    "kind": "color",
                    "key": "lookBorderColor",
                    "label": "Outline colour",
                    "keywords": "border stroke colour color",
                    "enabled": () => Settings.lookBorder,
                    "allowEmpty": true,
                    "emptyLabel": "Theme",
                    "fallback": () => Theme.mix(Theme.island, Theme.text, 0.2)
                },
                {
                    "id": "lookShadow",
                    "kind": "switch",
                    "key": "lookShadow",
                    "label": "Shadow (island and panels)",
                    "keywords": "drop shadow depth elevation"
                },
                {
                    "id": "lookShadowStrength",
                    "kind": "slider",
                    "key": "lookShadowStrength",
                    "label": "Shadow strength",
                    "keywords": "drop shadow depth blur opacity",
                    "enabled": () => Settings.lookShadow,
                    "min": 0,
                    "max": 1,
                    "step": 0.05,
                    "format": v => `${Math.round(v * 100)} %`
                }
            ]
        },
        {
            "title": "Transparency",
            "options": [
                {
                    "id": "lookIslandOpacity",
                    "kind": "slider",
                    "key": "lookIslandOpacity",
                    "label": "Island opacity",
                    "keywords": "transparency translucent see through alpha bar",
                    "min": 0.3,
                    "max": 1,
                    "step": 0.05,
                    "format": v => `${Math.round(v * 100)} %`
                },
                {
                    "id": "lookPanelOpacity",
                    "kind": "slider",
                    "key": "lookPanelOpacity",
                    "label": "Panel opacity",
                    "keywords": "transparency translucent see through alpha control center launcher",
                    "min": 0.3,
                    "max": 1,
                    "step": 0.05,
                    "format": v => `${Math.round(v * 100)} %`
                },
                {
                    "id": "integrationBlurLook",
                    "kind": "switch",
                    "key": "integrationBlur",
                    "resettable": false, // its home is Integrations > Hyprland
                    "label": "Blur behind (Hyprland layer rule, below 100 %)",
                    "keywords": "blur frosted glass layer rule hyprland",
                    "enabled": () => Theme.look.translucent
                }
            ]
        },
        {
            "title": "Scale",
            "options": [
                {
                    "id": "uiScale",
                    "kind": "slider",
                    "key": "uiScale",
                    "label": "Interface scale (restart)",
                    "keywords": "size scale zoom bigger smaller dpi interface",
                    "min": 0.6,
                    "max": 1.2,
                    "step": 0.05,
                    "format": v => `${Math.round(v * 100)} %`
                },
                {
                    "id": "restart",
                    "kind": "button",
                    "label": "Restart luxshell now",
                    "keywords": "restart reload scale apply relaunch",
                    "value": () => Math.abs(Settings.uiScale - page.runningScale) > 0.001 ? `Running at ${Math.round(page.runningScale * 100)} %` : "",
                    "action": "Restart",
                    "run": () => page.restart()
                }
            ]
        }
    ]
}
