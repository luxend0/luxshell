pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Settings > Integrations, Hyprland (opt-in, default off), via `hyprctl eval` (Lua config)
// against the compositor this shell runs in (the nested one in the sandbox):
//
//   look  window border (active = accent, inactive = the theme's raised surface, width),
//         gaps (in / out) and window rounding (px x the corner radius factor). Like
//         services/GameMode the values it replaces are read first (hyprctl -j getoption) and
//         kept in Settings.integrationHyprSaved; switching a part off puts its saved value
//         back, switching the integration off restores all of them. After a config reload
//         (the user's values are back) they are read again and the look re-applied.
//   blur  layer rule "luxshell-blur" for the island's layer namespace while the island or
//         a panel is translucent (Theme.look.translucent) and Settings.integrationBlur is on;
//         pixels below ignore_alpha (the transparent surface around the island) stay sharp.
//         Needs Hyprland's decoration:blur:enabled.
//
// Game mode (services/GameMode) owns the gaps while it is on: the look leaves them alone,
// and when the look is switched off meanwhile, game mode's saved gaps become the originals.
Singleton {
    id: root

    readonly property bool on: Settings.integrationHypr
    readonly property var options: ["general:col.active_border", "general:col.inactive_border", "general:border_size", "general:gaps_in", "general:gaps_out", "decoration:rounding"]
    readonly property var gapOptions: ["general:gaps_in", "general:gaps_out"]

    // what the look wants right now ({} while off)
    readonly property var wanted: {
        const v = {};
        if (!on)
            return v;
        if (Settings.integrationHyprBorder) {
            v["general:col.active_border"] = rgba(Theme.accent);
            v["general:col.inactive_border"] = rgba(Theme.surfaceHigh);
            v["general:border_size"] = Settings.integrationHyprBorderSize;
        }
        if (Settings.integrationHyprGaps && !Settings.gameMode) {
            v["general:gaps_in"] = Settings.integrationHyprGapsIn;
            v["general:gaps_out"] = Settings.integrationHyprGapsOut;
        }
        if (Settings.integrationHyprRounding)
            v["decoration:rounding"] = Math.round(Settings.integrationHyprRadius * Theme.radiusScale);
        return v;
    }
    readonly property var saved: {
        try {
            return JSON.parse(Settings.integrationHyprSaved || "{}");
        } catch (e) {
            return {};
        }
    }
    readonly property bool busy: reader.running || writer.running
    property string lastError: ""

    onWantedChanged: if (Settings.ready)
        applyTimer.restart()

    Connections {
        target: Settings
        function onReadyChanged(): void {
            if (Settings.ready) {
                applyTimer.restart();
                blurTimer.restart();
            }
        }
    }
    Component.onCompleted: if (Settings.ready) {
        applyTimer.restart();
        blurTimer.restart();
    }

    // config reload: Hyprland is back on the user's values (and runtime rules are gone)
    Connections {
        target: Hyprland
        function onRawEvent(event: var): void {
            if (event.name !== "configreloaded")
                return;
            if (root.on)
                root.readAgain = true;
            applyTimer.restart();
            root.blurDone = "";
            blurTimer.restart();
        }
    }
    property bool readAgain: false

    Timer {
        id: applyTimer
        interval: 150 // slider drags, theme picker preview
        onTriggered: root.apply()
    }

    function apply(): void {
        if (busy) {
            applyTimer.restart();
            return;
        }
        const haveSaved = Object.keys(saved).length > 0;
        if (on && (!haveSaved || readAgain)) {
            readAgain = false;
            reader.running = true; // saves, then comes back here
            return;
        }
        if (on) {
            // everything the look wants, plus the saved value of parts switched off
            const v = Object.assign({}, wanted);
            for (const k of options)
                if (!(k in v) && k in saved && !(Settings.gameMode && gapOptions.includes(k)))
                    v[k] = saved[k];
            run(v, "");
            return;
        }
        if (!haveSaved)
            return;
        const v = Object.assign({}, saved);
        if (Settings.gameMode) {
            // game mode holds the gaps at 0 and restores its own copy later: make that copy the originals
            let gm = {};
            try {
                gm = JSON.parse(Settings.gameModeSaved || "{}");
            } catch (e) {}
            for (const k of gapOptions) {
                if (k in v && k in gm)
                    gm[k] = v[k];
                delete v[k];
            }
            Settings.set("gameModeSaved", JSON.stringify(gm));
        }
        run(v, "restore");
    }

    function run(values: var, then: string): void {
        if (Object.keys(values).length === 0) {
            if (then === "restore")
                Settings.set("integrationHyprSaved", "");
            return;
        }
        writer.then = then;
        writer.command = ["hyprctl", "eval", lua(values)];
        writer.running = true;
    }

    // ---- values ------------------------------------------------------------------------
    function hex2(v: real): string {
        return Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
    }
    function rgba(c: color): string {
        return `rgba(${hex2(c.r)}${hex2(c.g)}${hex2(c.b)}ff)`;
    }

    // getoption output, one compact JSON object per line -> { option: value }
    function parse(text: string): var {
        const out = {};
        for (const line of text.split("\n")) {
            if (line.trim() === "")
                continue;
            try {
                const o = JSON.parse(line);
                const v = o.gradient ?? o.bool ?? o.int ?? o.float ?? o.css ?? o.str ?? o.custom;
                if (o.option && v !== undefined)
                    out[o.option] = v;
            } catch (e) {
                console.warn(`luxshell: Hyprland look could not parse "${line}"`);
            }
        }
        return out;
    }

    // { "general:gaps_in": 5, "general:col.active_border": "ee33ccff ee00ff99 45deg", ... }
    // -> hl.config({ general = { gaps_in = 5, col = { active_border = { colors = {...}, angle = 45 } } } })
    function lua(values: var): string {
        const tree = {};
        for (const key of Object.keys(values)) {
            // "general:col.active_border": col.* is one more table level in the Lua config
            const path = [];
            for (const p of key.split(":")) {
                if (p.startsWith("col."))
                    path.push("col", p.slice(4));
                else
                    path.push(p);
            }
            let node = tree;
            for (let i = 0; i < path.length - 1; i++)
                node = node[path[i]] = node[path[i]] ?? {};
            node[path[path.length - 1]] = {
                "leaf": true,
                "key": key,
                "v": values[key]
            };
        }
        const leaf = (key, v) => {
            if (typeof v === "boolean" || typeof v === "number")
                return String(v);
            const s = String(v).trim();
            if (key.includes(":col.")) {
                if (s.startsWith("rgb"))
                    return JSON.stringify(s);
                // getoption gradient: "AARRGGBB [AARRGGBB ...] [Ndeg]"
                const parts = s.split(/\s+/);
                let angle = 0;
                const colors = [];
                for (const p of parts) {
                    if (/deg$/.test(p))
                        angle = parseFloat(p) || 0;
                    else if (/^[0-9a-fA-F]{8}$/.test(p))
                        colors.push(`"rgba(${p.slice(2)}${p.slice(0, 2)})"`);
                }
                return colors.length === 0 ? JSON.stringify(s) : `{ colors = { ${colors.join(", ")} }, angle = ${angle} }`;
            }
            if (/^-?\d+( -?\d+){3}$/.test(s)) {
                const [t, r, b, l] = s.split(" ");
                return `{ top = ${t}, right = ${r}, bottom = ${b}, left = ${l} }`;
            }
            return /^-?\d+(\.\d+)?$/.test(s) ? s : JSON.stringify(s);
        };
        const node = n => n.leaf ? leaf(n.key, n.v) : "{ " + Object.keys(n).map(k => `${k} = ${node(n[k])}`).join(", ") + " }";
        return `hl.config(${node(tree)})`;
    }

    Process {
        id: reader
        command: ["sh", "-c", 'for o in "$@"; do hyprctl -j getoption "$o" | tr -d "\\n"; echo; done', "sh", ...root.options]
        stdout: StdioCollector {
            onStreamFinished: {
                const got = root.parse(text);
                if (Object.keys(got).length !== root.options.length) {
                    root.lastError = "could not read the current Hyprland values";
                    console.warn(`luxshell: Hyprland look: ${root.lastError}, not applying`);
                    return;
                }
                // values game mode is holding are not the user's: keep the ones it saved
                if (Settings.gameMode) {
                    let gm = {};
                    try {
                        gm = JSON.parse(Settings.gameModeSaved || "{}");
                    } catch (e) {}
                    for (const k of root.gapOptions)
                        if (k in gm)
                            got[k] = gm[k];
                        else if (k in root.saved)
                            got[k] = root.saved[k];
                }
                root.lastError = "";
                Settings.set("integrationHyprSaved", JSON.stringify(got));
                applyTimer.restart();
            }
        }
    }

    Process {
        id: writer
        property string then: ""
        stdout: StdioCollector {
            id: writerOut
        }
        onExited: code => {
            const msg = writerOut.text.trim();
            if (code !== 0 || (msg !== "" && msg !== "ok")) {
                root.lastError = msg;
                console.warn(`luxshell: Hyprland look: ${msg}`);
            } else {
                root.lastError = "";
                if (writer.then === "restore")
                    Settings.set("integrationHyprSaved", "");
            }
        }
    }

    // ---- blur layer rule ------------------------------------------------------------------
    readonly property bool blurWanted: Settings.integrationBlur && Theme.look.translucent
    // pixels below this alpha get no blur: the transparent surface and a faint shadow
    readonly property real ignoreAlpha: Math.max(0.05, Math.min(Theme.look.islandOpacity, Theme.look.panelOpacity) - 0.08)
    readonly property string blurRule: blurWanted ? `hl.layer_rule({ name = "luxshell-blur", match = { namespace = "^luxshell$" }, blur = true, ignore_alpha = ${ignoreAlpha.toFixed(2)} })` : `hl.layer_rule({ name = "luxshell-blur", match = { namespace = "^luxshell$" }, blur = false })`
    property string blurDone: ""
    onBlurRuleChanged: if (Settings.ready)
        blurTimer.restart()

    Timer {
        id: blurTimer
        interval: 200
        onTriggered: {
            if (blurProc.running) {
                restart();
                return;
            }
            // nothing to undo at a plain start
            if (root.blurRule === root.blurDone || (root.blurDone === "" && !root.blurWanted && !root.blurEver))
                return;
            root.blurEver = true;
            blurProc.rule = root.blurRule;
            blurProc.command = ["hyprctl", "eval", root.blurRule];
            blurProc.running = true;
        }
    }
    // a rule from an earlier luxshell run (same compositor) is switched off once at start
    property bool blurEver: Settings.integrationBlur

    Process {
        id: blurProc
        property string rule: ""
        stdout: StdioCollector {
            id: blurOut
        }
        onExited: code => {
            const msg = blurOut.text.trim();
            if (code !== 0 || (msg !== "" && msg !== "ok"))
                console.warn(`luxshell: blur layer rule: ${msg}`);
            else
                root.blurDone = blurProc.rule;
        }
    }
}
