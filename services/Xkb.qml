pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Keyboard layouts, variants and layout-switch keys known to XKB (/usr/share/X11/xkb/rules/
// evdev.lst), read once on first use (Settings > Input).
//
//   layouts      [{ value: "de", label: "German" }]                     sorted by label
//   variants(l)  [{ value: "nodeadkeys", label: "German (no dead keys)" }]  of one layout
//   switches     [{ value: "grp:alt_shift_toggle", label: "Alt+Shift" }]    "grp:" options
//   layoutName(l)
Singleton {
    id: root

    property bool asked: false
    property var layouts: []
    property var variantMap: ({})
    property var switches: []

    function load(): void {
        if (asked)
            return;
        asked = true;
        view.path = "/usr/share/X11/xkb/rules/evdev.lst";
    }
    function variants(layout: string): var {
        load();
        return variantMap[layout] ?? [];
    }
    function layoutName(layout: string): string {
        load();
        return layouts.find(l => l.value === layout)?.label ?? layout;
    }

    FileView {
        id: view
        printErrors: false
        onLoaded: root.parse(text())
        onLoadFailed: console.warn("luxshell: no XKB rules list (/usr/share/X11/xkb/rules/evdev.lst)")
    }

    function parse(text: string): void {
        let part = "";
        const lay = [], vars = {}, sw = [];
        for (const line of text.split("\n")) {
            const head = /^! (\w+)/.exec(line);
            if (head) {
                part = head[1];
                continue;
            }
            const m = /^\s+(\S+)\s+(.*)$/.exec(line);
            if (!m)
                continue;
            if (part === "layout") {
                lay.push({
                    "value": m[1],
                    "label": m[2].trim()
                });
            } else if (part === "variant") {
                const v = /^(\S+):\s*(.*)$/.exec(m[2]);
                if (!v)
                    continue;
                (vars[v[1]] = vars[v[1]] ?? []).push({
                    "value": m[1],
                    "label": v[2].trim()
                });
            } else if (part === "option" && m[1].startsWith("grp:")) {
                sw.push({
                    "value": m[1],
                    "label": m[2].trim()
                });
            }
        }
        layouts = lay.sort((a, b) => a.label.localeCompare(b.label));
        variantMap = vars;
        switches = sw;
    }
}
