pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Control center navigation from outside the panel (IPC, keybinds). The sheet
// state itself lives in panels/ControlCenter.qml; this only hands requests over.
//
//   qs -c luxshell ipc call controlcenter page bluetooth   open the panel (if needed) on a sheet
//   qs -c luxshell ipc call controlcenter page main         back to the main page
//   qs -c luxshell ipc call controlcenter back
//   qs -c luxshell ipc call controlcenter state             "closed" | "main" | <sheet>
//
// core/Ipc.qml references this singleton at shell start, so the IPC target exists
// before the control center was ever opened.
Singleton {
    id: root

    readonly property var panelIds: ["controlcenter", "bluetooth"] // registry ids that are a control center
    readonly property bool open: panelIds.includes(Ui.panel)
    property string page: ""      // reported by the shown control center
    property string pending: ""   // sheet for the next control center that opens

    signal navigate(string page)
    signal backRequested

    function show(name: string): void {
        if (open) {
            navigate(name);
        } else {
            pending = name === "main" ? "" : name;
            Ui.open("controlcenter");
        }
    }

    // the panel takes the pending sheet once, when it is created
    function take(): string {
        const p = pending;
        pending = "";
        return p;
    }

    IpcHandler {
        target: "controlcenter"

        function page(name: string): void {
            root.show(name);
        }
        function back(): void {
            root.backRequested();
        }
        function state(): string {
            return root.open ? (root.page || "main") : "closed";
        }
    }
}
