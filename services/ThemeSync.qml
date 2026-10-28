pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "palette.js" as Palette

// 1. The "wallpaper" theme: its palette is derived from the applied wallpaper
//    (palette.js) and handed to Themes.derived. Extraction = one small magick run
//    (videos: one ffmpeg frame first), nice 19 + ionice idle, only when the wallpaper
//    changes; the colours are cached in <cacheDir>/wallpaper-colors.json.
//
// 2. Theme export: the APPLIED theme (never the picker's live preview) is written to
//    luxshell's own cache only, files are replaced only when their content changed:
//
//      <cacheDir>/kitty-theme.conf   kitty colours
//      <cacheDir>/gtk.css            GTK 4 / libadwaita named colours (+ GTK 3 aliases)
//      <cacheDir>/palette.json       every role + ansi, for scripts
//
//    luxshell edits no other config on its own. To use them (cacheDir = ~/.cache/luxshell):
//      kitty   kitty.conf:   include ~/.cache/luxshell/kitty-theme.conf
//              live reload:  kitty @ set-colors --all --configured ~/.cache/luxshell/kitty-theme.conf
//                            (needs allow_remote_control), or ctrl+shift+f5 in kitty
//      GTK 4   ~/.config/gtk-4.0/gtk.css:  @import url("file:///home/USER/.cache/luxshell/gtk.css");
//      GTK 3   same line in ~/.config/gtk-3.0/gtk.css (adw-gtk3 reads the same colour names)
//    Settings.themeExport = false turns the export off (unless the kitty / GTK integration
//    needs it). Settings > Integrations can add / remove those include lines itself
//    (services/AppThemes, opt-in).
Singleton {
    id: root

    readonly property bool active: true

    // ---- 1. wallpaper palette --------------------------------------------------------
    readonly property string wallpaper: Settings.wallpaper
    readonly property string colorsPath: Wallpapers.cacheDir + "/wallpaper-colors.json"
    property string derivedFrom: ""
    property bool cacheTried: false

    onWallpaperChanged: sync()

    function sync(): void {
        if (wallpaper === "") {
            Themes.derived = null;
            derivedFrom = "";
            return;
        }
        if (wallpaper === derivedFrom)
            return;
        if (!cacheTried)
            return; // cacheFile.onLoaded / onLoadFailed come back here
        if (cacheFile.loaded) try {
            const c = JSON.parse(cacheFile.text());
            if (c.source === wallpaper && c.colors?.length > 0) {
                use(c.colors, wallpaper);
                return;
            }
        } catch (e) {}
        extract();
    }

    function use(colors: var, source: string): void {
        const p = Palette.derive(colors);
        if (!p)
            return;
        p.source = source;
        Themes.derived = p;
        derivedFrom = source;
    }

    function extract(): void {
        if (wallpaper === "")
            return;
        if (extractor.running) {
            extractAgain = true;
            return;
        }
        extractor.source = wallpaper;
        extractor.command = ["sh", "-c", extractScript, "luxshell-palette", wallpaper, Wallpapers.isVideo(wallpaper) ? "v" : "i"];
        extractor.running = true;
    }
    property bool extractAgain: false

    readonly property string extractScript: `
src=$1
q="-dither None -colors 12 -depth 8 -format %c histogram:info:-"
if [ "$2" = v ]; then
    nice -n 19 ionice -c 3 ffmpeg -nostdin -v error -threads 1 -ss 1 -i "$src" -frames:v 1 -vf scale=160:-2 -f image2pipe -vcodec ppm - </dev/null \\
        | nice -n 19 magick -limit thread 1 ppm:- $q
else
    nice -n 19 ionice -c 3 magick -limit thread 1 -define jpeg:size=320x320 "$src[0]" -resize 160x160 $q
fi`

    Process {
        id: extractor
        property string source: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const colors = Palette.parseHistogram(text);
                if (colors.length === 0) {
                    console.warn(`luxshell: no colours from ${extractor.source}`);
                    return;
                }
                root.use(colors, extractor.source);
                root.write({
                    "wallpaper-colors.json": JSON.stringify({
                        "source": extractor.source,
                        "colors": colors
                    }) + "\n"
                });
            }
        }
        onExited: if (root.extractAgain || root.wallpaper !== root.derivedFrom) {
            root.extractAgain = false;
            if (root.wallpaper !== root.derivedFrom && root.wallpaper !== "")
                root.extract();
        }
    }

    FileView {
        id: cacheFile
        path: root.colorsPath
        printErrors: false
        onLoaded: {
            root.cacheTried = true;
            root.sync();
        }
        onLoadFailed: {
            root.cacheTried = true;
            root.sync();
        }
    }

    // ---- 2. export of the applied theme ----------------------------------------------
    // (custom themes load from disk: a saved custom theme is waited for, never exported as noir;
    // the accent picked in the settings app replaces the theme's own; the kitty/GTK integrations
    // (services/AppThemes) need the files even with the export switch off)
    readonly property string appliedName: Themes.palettes.hasOwnProperty(Settings.theme) ? Settings.theme : "noir"
    readonly property bool known: Themes.palettes.hasOwnProperty(Settings.theme) || CustomThemes.ready
    readonly property var applied: Settings.accent === "" ? Themes.palettes[appliedName] : Object.assign({}, Themes.palettes[appliedName], {
        "accent": Settings.accent
    })
    readonly property bool exporting: Settings.themeExport || Settings.integrationKitty || Settings.integrationGtk
    // files the last export replaced (names in cacheDir), e.g. ["kitty-theme.conf"]
    signal exported(var names)
    onAppliedChanged: exportTimer.restart()
    onExportingChanged: exportTimer.restart()
    onKnownChanged: exportTimer.restart()
    Component.onCompleted: exportTimer.restart()

    Timer {
        id: exportTimer
        interval: 400
        onTriggered: if (root.exporting && root.known)
            root.write({
                "kitty-theme.conf": root.kitty(root.appliedName, root.applied),
                "gtk.css": root.gtk(root.appliedName, root.applied),
                "palette.json": JSON.stringify(Object.assign({
                    "name": root.appliedName
                }, root.applied), null, 2) + "\n"
            })
    }

    function lighten(c: string, t: real): string {
        return Themes.mix(c, "#ffffff", t);
    }

    function kitty(name: string, p: var): string {
        const a = p.ansi ?? p.swatches;
        const lines = [`# luxshell theme "${name}" - generated by luxshell, edits are overwritten`, `# kitty.conf: include ${Wallpapers.cacheDir}/kitty-theme.conf`, `foreground ${p.text}`, `background ${p.base}`, `selection_foreground ${p.text}`, `selection_background ${Themes.mix(p.base, p.accent, 0.3)}`, `cursor ${p.accent}`, `cursor_text_color ${p.base}`, `url_color ${p.accent}`, `active_border_color ${p.accent}`, `inactive_border_color ${p.muted}`, `active_tab_foreground ${p.onAccent}`, `active_tab_background ${p.accent}`, `inactive_tab_foreground ${p.textDim}`, `inactive_tab_background ${p.surface}`, `tab_bar_background ${p.surface}`, `color0 ${Themes.mix(p.base, p.text, 0.12)}`, `color8 ${p.muted}`];
        for (let i = 0; i < 6; i++) {
            lines.push(`color${i + 1} ${a[i]}`);
            lines.push(`color${i + 9} ${lighten(a[i], 0.14)}`);
        }
        lines.push(`color7 ${p.textSecondary}`, `color15 ${p.text}`);
        return lines.join("\n") + "\n";
    }

    function gtk(name: string, p: var): string {
        const view = Themes.scale(p.base, 0.85);
        const card = Themes.mix(p.base, p.text, 0.05);
        const pairs = [["accent_color", p.accent], ["accent_bg_color", p.accent], ["accent_fg_color", p.onAccent], ["window_bg_color", p.base], ["window_fg_color", p.text], ["view_bg_color", view], ["view_fg_color", p.text], ["headerbar_bg_color", p.base], ["headerbar_fg_color", p.text], ["headerbar_backdrop_color", p.base], ["sidebar_bg_color", p.surfaceHigh], ["sidebar_fg_color", p.text], ["card_bg_color", card], ["card_fg_color", p.text], ["dialog_bg_color", card], ["dialog_fg_color", p.text], ["popover_bg_color", card], ["popover_fg_color", p.text], ["destructive_color", "#e5484d"], ["destructive_bg_color", "#e5484d"], ["destructive_fg_color", "#ffffff"],
            // GTK 3 / adw-gtk3
            ["theme_bg_color", p.base], ["theme_fg_color", p.text], ["theme_base_color", view], ["theme_text_color", p.text], ["theme_selected_bg_color", p.accent], ["theme_selected_fg_color", p.onAccent], ["insensitive_fg_color", p.textDim], ["borders", p.muted]];
        return `/* luxshell theme "${name}" - generated by luxshell, edits are overwritten.\n   use: @import url("file://${Wallpapers.cacheDir}/gtk.css"); in ~/.config/gtk-4.0/gtk.css */\n` + pairs.map(([k, v]) => `@define-color ${k} ${v};`).join("\n") + "\n";
    }

    // ---- writer: one job at a time, mkdir, atomic replace, unchanged files untouched ----
    property var pending: ({})

    function write(files: var): void {
        pending = Object.assign({}, pending, files);
        if (!writer.running)
            flush();
    }
    function flush(): void {
        const names = Object.keys(pending);
        if (names.length === 0)
            return;
        const args = [];
        for (const n of names)
            args.push(n, pending[n]);
        pending = {};
        writer.command = ["sh", "-c", `d=$1; shift; mkdir -p "$d" || exit 1
while [ $# -ge 2 ]; do
    f="$d/$1"; printf '%s' "$2" >"$f.part"
    if cmp -s "$f.part" "$f"; then rm -f "$f.part"; else mv -f "$f.part" "$f" && echo "$1"; fi
    shift 2
done`, "luxshell-write", Wallpapers.cacheDir, ...args];
        writer.running = true;
    }

    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.split("\n").filter(n => n !== "");
                if (names.length > 0)
                    root.exported(names);
            }
        }
        onExited: root.flush()
    }
}
