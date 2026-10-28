import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// qs -c luxshell ipc call luxshell <fn> [args]
IpcHandler {
    target: "luxshell"

    // touching CcNav creates its IPC target "controlcenter" at shell start, not on first open
    Component.onCompleted: CcNav.pending = ""

    function toggle(panel: string): void {
        Ui.toggle(panel);
    }
    function open(panel: string): void {
        Ui.open(panel);
    }
    function close(): void {
        Ui.close();
    }
    function preview(state: string): void {
        Ui.preview(state);
    }
    function flash(panel: string, ms: int): void {
        Ui.flash(panel, ms);
    }
    function theme(name: string): void {
        if (Themes.resolve(name) !== name)
            console.warn(`luxshell: unknown theme "${name}"`);
        else
            Settings.set("theme", name);
    }
    function state(): string {
        return JSON.stringify({
            "panel": Ui.panel,
            "panelScreen": Ui.panelScreen,
            "overlay": Ui.overlay,
            "forced": Ui.forced,
            "theme": Theme.name,
            "themes": Themes.names,
            "panels": Panels.ids,
            "controlcenter": CcNav.open ? (CcNav.page || "main") : "",
            "settings": Settings.path,
            "window": Hypr.hasWindow ? `${Hypr.appId}: ${Hypr.title}` : "",
            "net": `${Net.kind} ${Net.bars}`,
            "volume": Audio.ready ? Math.round(Audio.volume * 100) : -1,
            "notifications": Notifs.count
        });
    }
}
