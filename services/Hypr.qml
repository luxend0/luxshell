pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Workspaces 1..count and the focused window. Event driven (Hyprland IPC socket).
Singleton {
    id: root

    readonly property int count: Math.max(2, Math.min(6, Settings.workspaceCount || 5)) // settings app, Bar & Island

    // activeToplevel is only set by focus events; right after a (re)start fall back
    // to the client Hyprland reports as most recently focused
    readonly property var toplevel: Hyprland.activeToplevel ?? Hyprland.toplevels.values.find(t => t.lastIpcObject?.focusHistoryID === 0) ?? null
    // a window counts only while its workspace is visible; empty workspace = "Desktop"
    readonly property bool hasWindow: !!toplevel && (toplevel.workspace?.active ?? true) && title !== ""
    readonly property string title: toplevel?.title ?? ""
    readonly property string appId: toplevel?.wayland?.appId ?? toplevel?.lastIpcObject?.class ?? ""

    function activeFor(screen): int {
        const mon = screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor;
        return mon?.activeWorkspace?.id ?? 1;
    }

    function occupied(id: int): bool {
        const ws = Hyprland.workspaces.values.find(w => w.id === id);
        return !!ws && ws.toplevels.values.length > 0;
    }

    Component.onCompleted: Hyprland.refreshToplevels()

    function focus(id: int): void {
        Hyprland.dispatch(`hl.dsp.focus({workspace="${id}"})`);
    }
}
