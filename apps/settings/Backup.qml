pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Settings backup (System page, IPC "settings exportFile/importFile"): the preferences as
// one JSON file (Settings.exportData(); runtime state like game mode stays out). Import
// replaces every preference (missing keys = default) and can be undone from the toast.
Singleton {
    id: root

    property string file: "~/luxshell-settings.json"   // System page "Backup file" (not saved)
    property string exportStatus: ""
    property string importStatus: ""
    readonly property bool busy: writer.running || reader.running
    property string pending: ""

    function now(): string {
        return Qt.formatTime(new Date(), "hh:mm");
    }

    function exportTo(path: string): void {
        const p = Catalog.expand(path.trim());
        if (p === "" || writer.running)
            return;
        pending = Catalog.tilde(p);
        const json = JSON.stringify(Settings.exportData(), null, 2) + "\n";
        // temp file + rename: an existing backup is never half written
        writer.command = ["sh", "-c", 'set -e; d=$(dirname -- "$1"); mkdir -p -- "$d"; t=$(mktemp -- "$1.XXXXXX"); printf "%s" "$2" > "$t"; mv -f -- "$t" "$1"', "sh", p, json];
        writer.running = true;
    }

    function importFrom(path: string): void {
        const p = Catalog.expand(path.trim());
        if (p === "" || reader.running)
            return;
        pending = Catalog.tilde(p);
        reader.command = ["sh", "-c", 'if [ -f "$1" ] && [ -r "$1" ]; then cat -- "$1"; else echo "__luxshell_no_file__"; fi', "sh", p];
        reader.running = true;
    }

    // result line for IPC and the toast
    function applyText(text: string): string {
        if (text.trim() === "__luxshell_no_file__")
            return `No file at ${pending}`;
        let obj;
        try {
            obj = JSON.parse(text);
        } catch (e) {
            return `${pending} is no JSON file`;
        }
        const snap = Settings.snapshot();
        const res = Settings.importData(obj);
        if (!res.ok)
            return `${pending} holds no settings`;
        let msg = `Imported ${res.applied} setting${res.applied === 1 ? "" : "s"}`;
        const left = res.skipped.length + res.unknown.length;
        if (left > 0)
            msg += `, ${left} skipped`;
        if (res.skipped.length > 0)
            console.warn(`luxshell: import ${pending}: wrong type, skipped: ${res.skipped.join(", ")}`);
        if (res.unknown.length > 0)
            console.info(`luxshell: import ${pending}: unknown keys ignored: ${res.unknown.join(", ")}`);
        SettingsApp.toast(msg, snap);
        return msg;
    }

    signal finished(string message)

    Process {
        id: writer
        stderr: StdioCollector {
            id: writeErr
        }
        onExited: code => {
            root.exportStatus = code === 0 ? `Saved ${root.now()}` : "Could not write the file";
            if (code !== 0)
                console.warn(`luxshell: export to ${root.pending} failed: ${writeErr.text.trim()}`);
            root.finished(code === 0 ? `Exported to ${root.pending}` : root.exportStatus);
        }
    }

    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                const msg = root.applyText(text);
                root.importStatus = msg.startsWith("Imported") ? `Imported ${root.now()}` : msg;
                root.finished(msg);
            }
        }
    }
}
