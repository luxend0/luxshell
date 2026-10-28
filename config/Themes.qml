pragma Singleton
import QtQuick
import Quickshell

// Theme data only. A theme is a flat palette; Theme.qml maps it to semantic roles.
// The island itself stays black in every theme (video), themes tint accent,
// text and the swatches the theme picker shows. Red (#e5484d) is not themable,
// it belongs to the power button only (Theme.danger).
//
// Keys every palette must define:
//   island base surface surfaceHigh text textSecondary textDim muted
//   accent onAccent wsOccupied wsEmpty swatches[6]
// optional: ansi[6] (terminal export, defaults to swatches)
//
// base is the theme's own background (theme picker card, kitty/gtk export), the
// surfaces are darker versions of it so they sit on the black island. swatches are
// in ANSI order: red green yellow blue magenta cyan.
//
// Most palettes are built by define() from the theme's published colours
// (background, foreground, accent, six ANSI colours); noir, nord and kanagawa are
// hand tuned. "wallpaper" is derived at runtime from the applied wallpaper
// (services/ThemeSync + services/palette.js) and written into `derived`.
Singleton {
    id: root

    // theme picker live preview: while set, the applied theme (Theme.name passes
    // Settings.theme) resolves to it. Never saved; Esc / closing the picker clears it.
    property string preview: ""

    // "wallpaper" palette (services/ThemeSync), null until a wallpaper is known
    property var derived: null

    readonly property var fixed: ({
            "noir": {
                "island": "#000000",
                "base": "#0a0a0a",
                "surface": "#0b0b0b",
                "surfaceHigh": "#232323",
                "text": "#ececec",
                "textSecondary": "#a8a8a8",
                "textDim": "#8a8a8a",
                "muted": "#4a4a4a",
                "accent": "#e8e8e8",
                "onAccent": "#0a0a0a",
                "wsOccupied": "#636363",
                "wsEmpty": "#282828",
                "swatches": ["#d9d9d9", "#bdbdbd", "#a3a3a3", "#8c8c8c", "#737373", "#ececec"]
            },
            "nord": {
                "island": "#000000",
                "base": "#2e3440",
                "surface": "#0d1016",
                "surfaceHigh": "#1d222c",
                "text": "#eceff4",
                "textSecondary": "#aeb6c6",
                "textDim": "#8790a2",
                "muted": "#434c5e",
                "accent": "#88c0d0",
                "onAccent": "#0d1016",
                "wsOccupied": "#5d6880",
                "wsEmpty": "#262c38",
                "swatches": ["#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#88c0d0"]
            },
            "kanagawa": {
                "island": "#000000",
                "base": "#1f1f28",
                "surface": "#0f0f14",
                "surfaceHigh": "#1f1f28",
                "text": "#dcd7ba",
                "textSecondary": "#b5b09a",
                "textDim": "#8a8678",
                "muted": "#4a4a5a",
                "accent": "#7e9cd8",
                "onAccent": "#0f0f14",
                "wsOccupied": "#5c5c74",
                "wsEmpty": "#26262f",
                "swatches": ["#c34043", "#76946a", "#c0a36e", "#7e9cd8", "#957fb8", "#6a9589"]
            },
            //                 background  foreground  accent      red        green      yellow     blue       magenta    cyan
            "ayu": define("#0b0e14", "#bfbdb6", "#e6b450", ["#f07178", "#aad94c", "#e6b450", "#59c2ff", "#d2a6ff", "#95e6cb"]),
            "carbonfox": define("#161616", "#f2f4f8", "#78a9ff", ["#ee5396", "#25be6a", "#08bdba", "#78a9ff", "#be95ff", "#33b1ff"]),
            "catppuccin": define("#1e1e2e", "#cdd6f4", "#cba6f7", ["#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#cba6f7", "#94e2d5"]),
            "dracula": define("#282a36", "#f8f8f2", "#bd93f9", ["#ff5555", "#50fa7b", "#f1fa8c", "#bd93f9", "#ff79c6", "#8be9fd"]),
            "everforest": define("#2d353b", "#d3c6aa", "#a7c080", ["#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092"]),
            "github-dark": define("#0d1117", "#e6edf3", "#58a6ff", ["#ff7b72", "#3fb950", "#d29922", "#58a6ff", "#bc8cff", "#39c5cf"]),
            "gruvbox": define("#282828", "#ebdbb2", "#fabd2f", ["#fb4934", "#b8bb26", "#fabd2f", "#83a598", "#d3869b", "#8ec07c"]),
            // steel and concrete, safety amber (the video's own theme, colours not published)
            "industrial": define("#1b1c1e", "#d6d3cc", "#f0a030", ["#c8553d", "#8a9a5b", "#e0a030", "#6b8aa6", "#9a7fa8", "#5f9e96"]),
            "monokai": define("#272822", "#f8f8f2", "#a6e22e", ["#f92672", "#a6e22e", "#e6db74", "#66d9ef", "#ae81ff", "#a1efe4"]),
            "nightfox": define("#192330", "#cdcecf", "#719cd6", ["#c94f6d", "#81b29a", "#dbc074", "#719cd6", "#9d79d6", "#63cdcf"]),
            // card order like the video: love pine gold foam iris rose
            "rose-pine": define("#191724", "#e0def4", "#ebbcba", ["#eb6f92", "#31748f", "#f6c177", "#9ccfd8", "#c4a7e7", "#ebbcba"]),
            "solarized": define("#002b36", "#93a1a1", "#268bd2", ["#dc322f", "#859900", "#b58900", "#268bd2", "#d33682", "#2aa198"]),
            "tokyo-night": define("#1a1b26", "#c0caf5", "#7aa2f7", ["#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff"]),
            "vira-palenight": define("#292d3e", "#bfc7d5", "#80cbc4", ["#f07178", "#c3e88d", "#ffcb6b", "#82aaff", "#c792ea", "#89ddff"])
        })

    // "wallpaper" before a wallpaper is known: noir with grey swatches
    readonly property var wallpaperFallback: Object.assign({}, fixed.noir, {
        "swatches": ["#bdbdbd", "#a3a3a3", "#8c8c8c", "#737373", "#5c5c5c", "#d9d9d9"]
    })

    readonly property var palettes: Object.assign({}, fixed, {
        "wallpaper": derived ?? wallpaperFallback
    })

    // picker order: the derived theme first, then A-Z (18 themes, nord = 14/18 like ref/05)
    readonly property var names: ["wallpaper", ...Object.keys(fixed).sort()]

    function resolve(name: string): string {
        const n = preview !== "" && name === Settings.theme ? preview : name;
        return palettes.hasOwnProperty(n) ? n : "noir";
    }

    // ---- palette builder ---------------------------------------------------------
    function rgb(h: string): var {
        const v = parseInt(h.slice(1), 16);
        return [(v >> 16) & 255, (v >> 8) & 255, v & 255];
    }
    function hex(c: var): string {
        return "#" + c.map(v => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, "0")).join("");
    }
    function mix(a: string, b: string, t: real): string {
        const x = rgb(a), y = rgb(b);
        return hex(x.map((v, i) => v + (y[i] - v) * t));
    }
    function scale(a: string, t: real): string {
        return hex(rgb(a).map(v => v * t));
    }
    // c, raised toward `to` until its brightest channel reaches `floor` (very dark themes)
    function lift(c: string, to: string, floor: real): string {
        const m = Math.max(...rgb(c)) / 255;
        if (m >= floor)
            return c;
        const n = Math.max(...rgb(to)) / 255;
        return mix(c, to, (floor - m) / Math.max(0.01, n - m));
    }

    function define(base: string, text: string, accent: string, swatches: var): var {
        return {
            "island": "#000000",
            "base": base,
            "surface": lift(scale(base, 0.34), text, 0.045),
            "surfaceHigh": lift(scale(base, 0.64), text, 0.125),
            "text": text,
            "textSecondary": mix(base, text, 0.74),
            "textDim": mix(base, text, 0.56),
            "muted": mix(scale(base, 0.7), text, 0.22),
            "accent": accent,
            "onAccent": scale(base, 0.45),
            "wsOccupied": mix(scale(base, 0.6), text, 0.36),
            "wsEmpty": lift(mix(scale(base, 0.75), text, 0.06), text, 0.15),
            "swatches": swatches
        };
    }
}
