pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Game mode: animations, blur and gaps off via `hyprctl eval` (Lua config).
// The previous values are read with `hyprctl -j getoption` first and restored
// on the way back, so nothing in the user's config gets overwritten for good.
// hyprctl talks to $HYPRLAND_INSTANCE_SIGNATURE, i.e. the compositor this shell
// runs in (the nested one in the sandbox). State lives in config/Settings
// (gameMode, gameModeSaved).
Singleton {
    id: root

    readonly property bool active: Settings.gameMode
    readonly property bool busy: read.running || apply.running
    readonly property var options: ["animations:enabled", "decoration:blur:enabled", "general:gaps_in", "general:gaps_out"]
    readonly property var offValues: ({
            "animations:enabled": false,
            "decoration:blur:enabled": false,
            "general:gaps_in": 0,
            "general:gaps_out": 0
        })

    property bool pendingOn: false

    function toggle(): void {
        set(!active);
    }

    function set(on: bool): void {
        if (busy || on === active)
            return;
        pendingOn = on;
        if (on) {
            read.running = true; // saves, then applies offValues
            return;
        }
        let saved = {};
        try {
            saved = JSON.parse(Settings.gameModeSaved || "{}");
        } catch (e) {}
        if (Object.keys(saved).length === 0) {
            console.warn("luxshell: game mode has no saved values, reloading the Hyprland config instead");
            apply.command = ["hyprctl", "reload"];
        } else {
            apply.command = ["hyprctl", "eval", lua(saved)];
        }
        apply.running = true;
    }

    // {"general:gaps_in": "5 5 5 5", ...} -> hl.config({ general = { gaps_in = {...} } })
    function lua(values: var): string {
        const tree = {};
        for (const key of Object.keys(values)) {
            const path = key.split(":");
            let node = tree;
            for (let i = 0; i < path.length - 1; i++)
                node = node[path[i]] = node[path[i]] ?? {};
            node[path[path.length - 1]] = values[key];
        }
        const val = v => {
            if (typeof v === "boolean" || typeof v === "number")
                return String(v);
            if (typeof v === "string" && /^-?\d+( -?\d+){3}$/.test(v)) {
                const [t, r, b, l] = v.split(" ");
                return `{ top = ${t}, right = ${r}, bottom = ${b}, left = ${l} }`;
            }
            if (typeof v === "string")
                return /^-?\d+(\.\d+)?$/.test(v) ? v : JSON.stringify(v);
            return "{ " + Object.keys(v).map(k => `${k} = ${val(v[k])}`).join(", ") + " }";
        };
        return `hl.config(${val(tree)})`;
    }

    // one compact JSON object per line
    function parse(text: string): var {
        const out = {};
        for (const line of text.split("\n")) {
            if (line.trim() === "")
                continue;
            try {
                const o = JSON.parse(line);
                const v = o.bool ?? o.int ?? o.float ?? o.css ?? o.str ?? o.custom;
                if (o.option && v !== undefined)
                    out[o.option] = v;
            } catch (e) {
                console.warn(`luxshell: game mode could not parse "${line}"`);
            }
        }
        return out;
    }

    Process {
        id: read
        command: ["sh", "-c", 'for o in "$@"; do hyprctl -j getoption "$o" | tr -d "\\n"; echo; done', "sh", ...root.options]
        stdout: StdioCollector {
            onStreamFinished: {
                const saved = root.parse(text);
                if (Object.keys(saved).length !== root.options.length) {
                    console.warn(`luxshell: game mode could not read the current Hyprland values, not enabling`);
                    return;
                }
                Settings.set("gameModeSaved", JSON.stringify(saved));
                apply.command = ["hyprctl", "eval", root.lua(root.offValues)];
                apply.running = true;
            }
        }
    }

    Process {
        id: apply
        stdout: StdioCollector {
            id: applyOut
        }
        onExited: code => {
            if (code === 0)
                Settings.set("gameMode", root.pendingOn);
            else
                console.warn(`luxshell: game mode: ${applyOut.text.trim()}`);
        }
    }

    // a stale flag (compositor restarted while game mode was on) is dropped
    Process {
        id: verify
        command: ["hyprctl", "-j", "getoption", "animations:enabled"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (JSON.parse(text).bool === true && Settings.gameMode)
                        Settings.set("gameMode", false);
                } catch (e) {}
            }
        }
    }
    Timer {
        // Settings loads asynchronously; check once it had a moment
        interval: 1500
        running: true
        onTriggered: if (Settings.gameMode)
            verify.running = true
    }
}
