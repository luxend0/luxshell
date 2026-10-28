import QtQuick
import Quickshell.Io
import qs.config
import qs.services

// Launcher: modes (on/off, order, prefixes), results (rows, ranking, history), terminal and
// web search, hidden apps. Keys: launcher* (+ terminal, searchEngine, webResults from before
// the prefixes).
SettingsPage {
    id: page

    // installed terminals only (the saved one always stays in the list)
    readonly property var terminalCandidates: ["kitty", "foot", "alacritty", "ghostty", "wezterm", "konsole", "xterm"]
    property var terminals: [Settings.terminal]

    Process {
        running: true
        command: ["sh", "-c", 'for t in "$@"; do command -v "$t" >/dev/null 2>&1 && echo "$t"; done', "sh", ...page.terminalCandidates]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(s => s !== "");
                page.terminals = found.includes(Settings.terminal) ? found : [Settings.terminal, ...found];
            }
        }
    }

    Component {
        id: hiddenList
        HiddenList {}
    }

    readonly property var modes: [
        {
            "value": "calc",
            "label": "Calculator (12*7, sqrt(2))",
            "icon": page.glyph(0xF00EC)
        },
        {
            "value": "apps",
            "label": "Apps",
            "icon": page.glyph(0xF003B)
        },
        {
            "value": "windows",
            "label": "Open windows",
            "icon": page.glyph(0xF05B2)
        },
        {
            "value": "commands",
            "label": "Commands (run in the terminal)",
            "icon": page.glyph(0xF018D)
        },
        {
            "value": "web",
            "label": "Web search",
            "icon": page.glyph(0xF059F)
        }
    ]

    function modeOn(id: string): bool {
        return Array.from(Settings.launcherProviders).includes(id);
    }

    // prefixes: never empty, never one another's; a bare word ("w") gets its space back,
    // otherwise typing "word" would switch to that mode
    function cleanPrefix(t: string): string {
        const p = t.replace(/^\s+/, "");
        return /^[A-Za-z0-9]+$/.test(p) ? p + " " : p;
    }
    function prefixValid(id: string, t: string): bool {
        const p = cleanPrefix(t);
        if (p.trim() === "" || p.length > 6)
            return false;
        const all = Settings.launcherPrefixes ?? {};
        return !Object.keys(all).some(k => k !== id && all[k] === p);
    }
    function prefixRow(id: string, label: string, keywords: string, fallback: string): var {
        return {
            "id": "launcherPrefix." + id,
            "kind": "text",
            "key": "launcherPrefixes." + id,
            "label": label,
            "keywords": "prefix mode trigger " + keywords,
            "placeholder": `Default: ${fallback.trim()}`,
            "enabled": () => page.modeOn(id),
            "valid": t => page.prefixValid(id, t),
            "apply": t => {
                if (page.prefixValid(id, t))
                    Settings.set("launcherPrefixes." + id, page.cleanPrefix(t));
            }
        };
    }

    function appCandidates(): var {
        return Apps.all.map(e => ({
                    "value": e.id,
                    "label": e.name,
                    "detail": e.id,
                    "icon": Apps.iconSource(e)
                }));
    }

    pageId: "launcher"
    title: "Launcher"
    subtitle: "Modes, results, terminal and web search."
    icon: 0xF0349
    sections: [
        {
            "title": "Modes",
            "options": [
                {
                    "id": "launcherProviders",
                    "kind": "list",
                    "key": "launcherProviders",
                    "label": "Modes, in result order",
                    "keywords": "providers calculator apps windows commands web order enable",
                    "items": () => page.modes
                },
                page.prefixRow("calc", "Calculator prefix", "calculator math =", "="),
                page.prefixRow("windows", "Windows prefix", "windows switch w", "w "),
                page.prefixRow("commands", "Commands prefix", "command terminal run >", ">"),
                page.prefixRow("web", "Web search prefix", "web internet ?", "?")
            ]
        },
        {
            "title": "Results",
            "options": [
                {
                    "id": "launcherRows",
                    "kind": "slider",
                    "key": "launcherRows",
                    "label": "Visible rows",
                    "keywords": "results list height rows lines",
                    "min": 3,
                    "max": 12,
                    "step": 1,
                    "format": v => `${Math.round(v)}`
                },
                {
                    "id": "launcherRankUsage",
                    "kind": "switch",
                    "key": "launcherRankUsage",
                    "label": "Rank apps by use (off: A-Z, nothing recorded)",
                    "keywords": "ranking frecency usage history recent sort"
                },
                {
                    "id": "launcherClearHistory",
                    "kind": "button",
                    "label": "History",
                    "keywords": "clear history usage recent commands forget",
                    "value": () => {
                        const a = AppUsage.count, c = LaunchStats.commands.length;
                        return a === 0 && c === 0 ? "Empty" : `${a} app${a === 1 ? "" : "s"}, ${c} command${c === 1 ? "" : "s"}`;
                    },
                    "action": "Clear",
                    "confirm": "Forget app use and recent commands?",
                    "enabled": () => AppUsage.count > 0 || LaunchStats.commands.length > 0,
                    "run": () => {
                        AppUsage.clear();
                        LaunchStats.clear();
                    }
                },
                {
                    "id": "webResults",
                    "kind": "switch",
                    "key": "webResults",
                    "label": "Web search row under every query",
                    "keywords": "internet results",
                    "enabled": () => page.modeOn("web")
                }
            ]
        },
        {
            "title": "Terminal and web",
            "options": [
                {
                    "id": "terminal",
                    "kind": "choice",
                    "key": "terminal",
                    "label": "Terminal",
                    "keywords": "kitty foot shell command console",
                    "options": () => page.terminals.map(t => ({
                                "value": t,
                                "label": t,
                                "detail": ""
                            }))
                },
                {
                    "id": "searchEngine",
                    "kind": "choice",
                    "key": "searchEngine",
                    "label": "Search engine",
                    "keywords": "web google duckduckgo browser",
                    "options": () => SearchEngines.list.map(e => ({
                                "value": e.id,
                                "label": e.name,
                                "detail": ""
                            }))
                }
            ]
        },
        {
            "title": "Hidden apps",
            "options": [
                {
                    "id": "launcherHiddenApps",
                    "kind": "custom",
                    "key": "launcherHiddenApps",
                    "label": "Never listed in the launcher",
                    "keywords": "hide apps exclude blacklist desktop entries",
                    "component": hiddenList,
                    "candidates": () => page.appCandidates(),
                    "describe": v => ({
                            "label": v,
                            "detail": "not installed",
                            "icon": ""
                        }),
                    "addLabel": "Hide an app",
                    "emptyText": "Every app is listed"
                }
            ]
        }
    ]
}
