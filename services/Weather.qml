pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Current weather from wttr.in for the island's weather widget. Sparing: nothing runs until
// a widget registers (use()/release()); then one request per 30 minutes, the answer cached in
// <cacheDir>/weather.json so restarts within that time do not ask again.
// Location: Settings.islandWeatherLocation ("" = by IP), unit Settings.islandWeatherUnit.
// LUXSHELL_FAKE_WEATHER="m|+12°C|Partly cloudy" (wttr.in %x|%t|%C) answers without network.
Singleton {
    id: root

    property int users: 0
    property string symbol: ""       // wttr.in plain-text symbol (%x): o sunny, m partly cloudy, mm cloudy ...
    property string temp: ""         // "+12°C"
    property string condition: ""    // "Partly cloudy"
    property double fetched: 0       // ms since epoch of the shown answer
    readonly property bool ready: temp !== ""

    readonly property string location: Settings.islandWeatherLocation.trim()
    readonly property string unit: Settings.islandWeatherUnit === "f" ? "u" : "m"
    readonly property string query: `${location}|${unit}`
    readonly property string fake: Env.fakeWeather
    readonly property string cacheDir: {
        const own = Env.get("LUXSHELL_CACHE_DIR");
        if (own !== "")
            return own;
        const xdg = Env.get("XDG_CACHE_HOME");
        return (xdg !== "" ? xdg : Env.get("HOME") + "/.cache") + "/luxshell";
    }
    readonly property int maxAge: 30 * 60 * 1000

    // "+12°C" -> "12°", "-3°F" -> "-3°"
    readonly property string short: temp.replace(/^\+/, "").replace(/[CF]$/, "")
    readonly property string icon: {
        const s = symbol;
        if (s === "o")
            return "sun";
        if (s === "m")
            return "cloud-sun";
        if (s === "mm" || s === "mmm")
            return "cloud";
        if (s === "=")
            return "cloud-fog";
        if (s.includes("!"))
            return "cloud-lightning";
        if (s.includes("*") || s.includes("x"))
            return "cloud-snow";
        if (s === "." || s === "/")
            return "cloud-drizzle";
        if (s.includes("/"))
            return "cloud-rain";
        return "cloud-sun";
    }

    function use(): void {
        users++;
        if (users === 1)
            start();
    }
    function release(): void {
        users = Math.max(0, users - 1);
    }

    function parse(text: string): bool {
        const p = text.trim().split("|");
        if (p.length < 3 || p[1].indexOf("°") < 0)
            return false;
        symbol = p[0].trim();
        temp = p[1].trim();
        condition = p[2].trim();
        return true;
    }

    function start(): void {
        if (fake !== "") {
            parse(fake);
            fetched = Date.now();
            return;
        }
        cache.reload();
    }
    function refresh(): void {
        if (users === 0 || fake !== "" || curl.running)
            return;
        curl.command = ["curl", "-sf", "--max-time", "12", `https://wttr.in/${encodeURIComponent(location)}?format=%x|%t|%C&${unit}`];
        curl.running = true;
    }

    onQueryChanged: if (users > 0) {
        temp = "";
        refresh();
    }

    Timer {
        running: root.users > 0 && root.fake === ""
        repeat: true
        interval: 5 * 60 * 1000 // checks the age; asks only when the answer is 30 min old
        onTriggered: if (Date.now() - root.fetched >= root.maxAge)
            root.refresh()
    }

    FileView {
        id: cache
        path: root.cacheDir + "/weather.json"
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text());
                if (o.query === root.query && Date.now() - o.time < root.maxAge && root.parse(o.answer)) {
                    root.fetched = o.time;
                    return;
                }
            } catch (e) {}
            root.refresh();
        }
        onLoadFailed: root.refresh()
    }

    Process {
        id: curl
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.parse(text))
                    return;
                root.fetched = Date.now();
                save.command = ["sh", "-c", 'mkdir -p "$1" && printf %s "$2" > "$1/weather.json"', "sh", root.cacheDir, JSON.stringify({
                        "query": root.query,
                        "time": root.fetched,
                        "answer": text.trim()
                    })];
                save.running = true;
            }
        }
    }
    Process {
        id: save
    }
}
