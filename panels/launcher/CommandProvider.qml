import QtQuick
import Quickshell
import qs.services

// "> cmd" runs cmd through $SHELL in the terminal (kitty --hold: stays open at a
// prompt). Recent commands below, most recent first.
Provider {
    prefix: ">"
    inDefault: false
    label: "Run in kitty"
    glyph: "terminal"
    limit: 12

    readonly property string shell: Quickshell.env("SHELL") || "/bin/sh"

    function run(cmd: string): void {
        LaunchStats.addCommand(cmd);
        Apps.runInTerminal([shell, "-c", cmd], true, "");
    }

    function match(query: string, exclusive: bool): var {
        const q = query.trim();
        const recent = LaunchStats.commands.filter(c => c !== q && c.toLowerCase().includes(q.toLowerCase())).map(c => ({
                    "key": "cmd:" + c,
                    "title": c,
                    "subtitle": "Recent command",
                    "icon": "",
                    "glyph": "history",
                    "run": () => run(c)
                }));
        if (q === "")
            return recent.length > 0 ? recent : [hint("Type a command", "Runs in kitty, the window stays open")];
        return [
            {
                "key": "run",
                "title": q,
                "subtitle": "Run in kitty",
                "icon": "",
                "glyph": "terminal",
                "run": () => run(q)
            }
        ].concat(recent);
    }
}
