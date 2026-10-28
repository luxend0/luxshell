pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Launch history for launcher ranking, persisted in <Env.configDir>/launcher.json:
//   { "version": 1, "apps": { "<desktop id>": {
//       "count": <total launches>,
//       "recent": [<unix s>, ...],          newest first, at most 10
//       "queries": { "<query>": <hits> }    what was typed when it was picked, at most 12 } } }
// Read on start and on external edits; written (debounced) only after a launch, so a
// plain start never creates the file.
Singleton {
    id: root

    readonly property string path: Env.configDir + "/launcher.json"
    property var apps: ({})
    property int revision: 0 // bumps on every change; read it in bindings that rank

    readonly property int maxRecent: 10
    readonly property int maxQueries: 12

    // Firefox-style frecency: total count x mean weight of the sampled recent launches
    function frecency(id: string): real {
        const a = apps[id];
        if (!a || !a.recent || a.recent.length === 0)
            return 0;
        const now = Date.now() / 1000;
        let sum = 0;
        for (const t of a.recent) {
            const h = (now - t) / 3600;
            sum += h < 6 ? 100 : h < 24 ? 80 : h < 96 ? 60 : h < 336 ? 40 : h < 744 ? 25 : h < 2160 ? 12 : 5;
        }
        return (a.count ?? a.recent.length) * sum / a.recent.length;
    }

    // ranking points for usage, 0..14 (one launch today ~4.6, five ~12)
    function boost(id: string): real {
        const f = frecency(id);
        return f > 0 ? 14 * (1 - Math.exp(-f / 250)) : 0;
    }

    // ranking points for "picked this app after typing this before", 0..18
    function queryBonus(id: string, q: string): real {
        const a = apps[id];
        if (!a || !a.queries || q === "")
            return 0;
        let hits = 0;
        for (const k in a.queries) {
            if (k === q)
                hits += a.queries[k];
            else if (k.startsWith(q))
                hits += a.queries[k] * 0.5;
        }
        return 18 * Math.min(1, hits / 3);
    }

    function record(id: string, query: string): void {
        if (id === "")
            return;
        const next = Object.assign({}, apps);
        const a = Object.assign({
            "count": 0,
            "recent": [],
            "queries": {}
        }, next[id] ?? {});
        a.count = (a.count ?? 0) + 1;
        a.recent = [Math.round(Date.now() / 1000)].concat(a.recent ?? []).slice(0, maxRecent);
        const q = query.slice(0, 32); // already normalized by Apps (fuzzy.js prepare)
        if (q !== "") {
            const seen = Object.assign({}, a.queries ?? {});
            seen[q] = (seen[q] ?? 0) + 1;
            const keys = Object.keys(seen).sort((x, y) => seen[y] - seen[x]);
            a.queries = {};
            for (const k of keys.slice(0, maxQueries))
                a.queries[k] = seen[k];
        }
        next[id] = a;
        apps = next;
        revision++;
        saveTimer.restart();
    }

    readonly property int count: Object.keys(apps).length

    // forget every launch (settings app, Launcher page "Clear history")
    function clear(): void {
        if (Object.keys(apps).length === 0)
            return;
        apps = {};
        revision++;
        saveTimer.restart();
    }

    function parse(text: string): void {
        try {
            const data = JSON.parse(text);
            apps = data && typeof data.apps === "object" && data.apps !== null ? data.apps : {};
        } catch (e) {
            console.warn(`luxshell: ignoring unreadable ${root.path}: ${e}`);
            apps = {};
        }
        revision++;
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: mkdir.running = true
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", Env.configDir]
        onExited: file.setText(JSON.stringify({
            "version": 1,
            "apps": root.apps
        }, null, 1) + "\n")
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onLoaded: root.parse(text())
        onFileChanged: reload()
        // a file created by our first save is not watched yet; reloading arms the watch
        onSaved: if (!loaded)
            reload()
        onSaveFailed: err => console.warn(`luxshell: could not save ${root.path}: ${err}`)
    }
}
