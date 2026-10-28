pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.island.bar

// State of the island editor that outlives the row (page switches, search): which states the
// preview shows, the picked widget, and the undo / redo history of every edit made in the
// editor (layout and widget options; Ctrl+Z / Ctrl+Shift+Z in the editor).
Singleton {
    id: root

    property string view: "both"      // collapsed | hover | both
    property string selected: ""      // widget id whose options show next to the palette
    property var undoStack: []
    property var redoStack: []
    readonly property bool canUndo: undoStack.length > 0
    readonly property bool canRedo: redoStack.length > 0

    // everything the editor writes
    readonly property var keys: ["islandLayout"].concat(BarRegistry.allOptionKeys)

    function snapshot(): var {
        const s = {};
        for (const k of keys)
            s[k] = Settings.get(k);
        return JSON.parse(JSON.stringify(s));
    }
    function apply(s: var): void {
        for (const k of keys)
            if (s[k] !== undefined)
                Settings.set(k, s[k]);
    }

    // call before a change: remembers the current state
    function remember(): void {
        undoStack = undoStack.concat([snapshot()]).slice(-80);
        redoStack = [];
    }
    function undo(): bool {
        if (!canUndo)
            return false;
        const s = undoStack[undoStack.length - 1];
        redoStack = redoStack.concat([snapshot()]);
        undoStack = undoStack.slice(0, -1);
        apply(s);
        return true;
    }
    function redo(): bool {
        if (!canRedo)
            return false;
        const s = redoStack[redoStack.length - 1];
        undoStack = undoStack.concat([snapshot()]);
        redoStack = redoStack.slice(0, -1);
        apply(s);
        return true;
    }

    // ---- edits --------------------------------------------------------------------------------
    function setLayout(lay: var, peekHover: bool): void {
        const n = BarRegistry.normalize(lay);
        if (JSON.stringify(n) === JSON.stringify(BarRegistry.layout))
            return;
        remember();
        Settings.set("islandLayout", n);
        if (peekHover)
            BarRegistry.peek(1800);
    }
    function setOption(key: string, value: var): void {
        if (JSON.stringify(Settings.get(key)) === JSON.stringify(value))
            return;
        remember();
        Settings.set(key, value);
    }
    function resetOptions(id: string): void {
        const ks = BarRegistry.optionKeys(id).filter(k => !Settings.isDefault(k));
        if (ks.length === 0)
            return;
        remember();
        Settings.resetMany(ks);
    }
}
