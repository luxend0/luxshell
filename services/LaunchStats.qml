pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// ">" command history, persisted in <Env.configDir>/commands.json:
//   commands  [ "most recent first", ... ]   (max 30)
// App usage lives in AppUsage (launcher.json). Read on start and on external edits;
// written only by addCommand(),
// so a plain start never touches the disk.
Singleton {
    id: root

    readonly property string path: Env.configDir + "/commands.json"
    readonly property var commands: Array.isArray(adapter.commands) ? adapter.commands.filter(c => typeof c === "string") : []

    function addCommand(cmd: string): void {
        const old = Array.isArray(adapter.commands) ? adapter.commands : [];
        adapter.commands = [cmd, ...old.filter(c => c !== cmd)].slice(0, 30);
        save();
    }

    // settings app, Launcher page "Clear history"
    function clear(): void {
        if (commands.length === 0)
            return;
        adapter.commands = [];
        save();
    }

    function save(): void {
        mkdir.running = true; // writeAdapter() once the directory exists
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", Env.configDir]
        onExited: file.writeAdapter()
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        // a file created by our first save is not watched yet; reloading arms the watch
        onSaved: if (!loaded)
            reload()
        onSaveFailed: err => console.warn(`luxshell: could not save ${root.path}: ${err}`)

        JsonAdapter {
            id: adapter
            property var commands: []
        }
    }
}
