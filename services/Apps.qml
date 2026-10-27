pragma Singleton
import QtQuick
import Quickshell

// Desktop entries: icon lookup for windows, search for the launcher.
Singleton {
    id: root

    readonly property var all: [...DesktopEntries.applications.values].filter(e => !e.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    function entryFor(appId: string): var {
        return appId !== "" ? DesktopEntries.heuristicLookup(appId) : null;
    }

    // themed icon path, "" if nothing resolves (caller shows a fallback glyph)
    function iconFor(appId: string): string {
        const name = entryFor(appId)?.icon || appId;
        return name ? Quickshell.iconPath(name, true) : "";
    }

    function iconPath(name: string): string {
        return name ? Quickshell.iconPath(name, true) : "";
    }

    function search(query: string, limit: int): var {
        const q = query.trim().toLowerCase();
        const hits = q === "" ? all : all.filter(e => e.name.toLowerCase().includes(q) || (e.genericName ?? "").toLowerCase().includes(q) || String(e.keywords ?? "").toLowerCase().includes(q));
        return hits.slice(0, limit);
    }
}
