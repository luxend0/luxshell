import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.services

// "w " lists open windows (Hyprland.toplevels), most recently focused first; the
// focused window goes last (switching to it is a no-op). Enter focuses through
// the Lua dispatcher: hl.dsp.focus({window="address:0x..."}).
Provider {
    prefix: Settings.launcherPrefixes?.windows ?? "w " // settings app, Launcher page
    inDefault: false
    label: "Windows"
    glyph: "app-window"

    function opened(): void {
        Hyprland.refreshToplevels(); // fills lastIpcObject (class, focus history)
    }

    function address(t: var): string {
        const a = t.address ?? "";
        return a === "" ? "" : a.startsWith("0x") ? a : "0x" + a;
    }

    function match(query: string, exclusive: bool): var {
        const q = query.trim().toLowerCase();
        const wins = Hyprland.toplevels.values.map(t => {
            const ipc = t.lastIpcObject ?? {};
            const appId = t.wayland?.appId || ipc.class || "";
            const app = Apps.entryFor(appId)?.name || appId;
            const hist = ipc.focusHistoryID ?? 999;
            const ws = t.workspace?.name || String(t.workspace?.id ?? "?");
            return {
                "t": t,
                "appId": appId,
                "app": app,
                "ws": ws,
                "order": hist === 0 ? 10000 : hist,
                "score": q === "" ? 1 : Math.max(Apps.fuzzy(t.title, q), Apps.fuzzy(app, q), Apps.fuzzy(appId, q) * 0.8)
            };
        }).filter(w => w.score > 0 && address(w.t) !== "");
        wins.sort((a, b) => q === "" ? a.order - b.order : b.score - a.score || a.order - b.order);
        if (wins.length === 0)
            return [hint(q === "" ? "No open windows" : "No matching window", q === "" ? "Nothing to switch to" : query.trim())];
        return wins.map(w => ({
                    "key": "win:" + address(w.t),
                    "title": w.t.title || w.app,
                    "subtitle": `${w.app}  ·  Workspace ${w.ws}`,
                    "icon": Apps.iconFor(w.appId),
                    "glyph": "app-window",
                    "run": () => Hyprland.dispatch(`hl.dsp.focus({window="address:${address(w.t)}"})`)
                }));
    }
}
