import QtQuick
import Quickshell.Io
import qs.config
import qs.services

// Launcher: terminal, web search. Keys: launcher* (terminal, searchEngine, webResults exist).
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

    pageId: "launcher"
    title: "Launcher"
    subtitle: "Terminal for commands and the web search row."
    icon: 0xF0349
    sections: [
        {
            "title": "",
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
                },
                {
                    "id": "webResults",
                    "kind": "switch",
                    "key": "webResults",
                    "label": "Web search row (under every query)",
                    "keywords": "internet results"
                }
            ]
        }
    ]
}
