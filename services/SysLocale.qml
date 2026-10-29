pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// System language and formats (Settings > System > Date, Time & Language), systemd-localed,
// i.e. /etc/locale.conf:
//   read   `localectl status` (System Locale: LANG=..., LC_*=...) and `localectl list-locales`
//          (the generated ones, what can be chosen)
//   write  `localectl set-locale VAR=value ...` through Exec.call with every variable that stays set
//          (localed replaces the whole set); polkit asks, a refusal lands in `error`. Programs see a
//          change from the next login on.
//   vars     { LANG: "en_US.UTF-8", LC_TIME: "en_GB.UTF-8", ... } (only the set ones)
//   groups   the LC_* the page offers one by one; formatVars = all of them ("Formats")
Singleton {
    id: root

    readonly property var groups: [
        {
            "id": "time",
            "label": "Dates and times",
            "vars": ["LC_TIME"],
            "words": "date time calendar week day month"
        },
        {
            "id": "numbers",
            "label": "Numbers",
            "vars": ["LC_NUMERIC"],
            "words": "number decimal separator comma point thousands"
        },
        {
            "id": "money",
            "label": "Currency",
            "vars": ["LC_MONETARY"],
            "words": "currency money euro dollar monetary"
        },
        {
            "id": "measure",
            "label": "Measurement and paper",
            "vars": ["LC_MEASUREMENT", "LC_PAPER"],
            "words": "measurement metric imperial units paper size a4 letter"
        },
        {
            "id": "address",
            "label": "Addresses, names, phone numbers",
            "vars": ["LC_ADDRESS", "LC_NAME", "LC_TELEPHONE"],
            "words": "address name telephone phone postal"
        }
    ]
    readonly property var formatVars: groups.reduce((a, g) => a.concat(g.vars), [])

    property var vars: ({})
    property var locales: []     // ["de_DE.UTF-8", ...]
    property bool ready: false
    property string busy: ""
    property string error: ""
    signal notice(string text)

    function refresh(): void {
        if (!status.running)
            status.running = true;
        if (!lister.running)
            lister.running = true;
    }

    // what a variable resolves to: its own value, else LANG, else C
    function effective(v: string): string {
        return vars[v] ?? vars.LANG ?? "C";
    }
    // one value for a set of variables: "" = all follow LANG, "mixed" = they differ
    function valueOf(list: var): string {
        const vals = list.map(v => vars[v] ?? "");
        return vals.every(x => x === vals[0]) ? vals[0] : "mixed";
    }
    function qtName(locale: string): string {
        return String(locale).split(/[.@]/)[0];
    }
    function label(locale: string): string {
        if (locale === "")
            return "Same as language";
        const base = qtName(locale);
        if (base === "C" || base === "POSIX")
            return "C (POSIX, no language)";
        const l = Qt.locale(base);
        if (l.name === "C")
            return locale;
        const lang = l.nativeLanguageName;
        const land = l.nativeTerritoryName;
        if (lang === "")
            return locale;
        // "American English", "British English" already name the region
        return land !== "" && !lang.includes(land) && !/\s/.test(lang.trim()) ? `${cap(lang)} (${land})` : cap(lang);
    }
    function cap(s: string): string {
        return s.length > 0 ? s[0].toUpperCase() + s.slice(1) : s;
    }

    // examples of a locale's formats (dropdown details, preview rows)
    function sample(group: string, locale: string, when: date): string {
        const l = Qt.locale(qtName(locale === "" ? effective("LANG") : locale));
        switch (group) {
        case "time":
            return when.toLocaleDateString(l, Locale.ShortFormat) + "  " + when.toLocaleTimeString(l, Locale.ShortFormat);
        case "numbers":
            return Number(1234567.89).toLocaleString(l, "f", 2);
        case "money":
            return Number(1234.5).toLocaleCurrencyString(l);
        case "measure":
            return l.measurementSystem === Locale.ImperialUSSystem ? "Imperial (US), Letter" : l.measurementSystem === Locale.ImperialUKSystem ? "Imperial (UK), A4" : "Metric, A4";
        }
        return "";
    }

    // set some variables ("" = unset, follows LANG) and keep every other one
    function apply(changes: var, what: string): void {
        if (busy !== "")
            return;
        const next = Object.assign({}, vars);
        for (const k in changes) {
            if (changes[k] === "")
                delete next[k];
            else
                next[k] = changes[k];
        }
        if (!next.LANG)
            next.LANG = vars.LANG ?? "C.UTF-8";
        if (JSON.stringify(next) === JSON.stringify(vars))
            return;
        const order = ["LANG"].concat(Object.keys(next).filter(k => k !== "LANG").sort());
        const args = order.map(k => `${k}=${next[k]}`);
        busy = what;
        Exec.call(["localectl", "set-locale", ...args], `set the system locale (${what})`, (ok, text) => {
            root.busy = "";
            root.error = ok ? "" : root.tidy(text, "Could not change the system locale");
            if (ok)
                root.notice(text === "dry run" ? `Dry run: ${what} (localectl not run)` : `${root.cap(what)}: from the next login`);
            root.refresh();
        });
    }
    function setLanguage(locale: string): void {
        if (locale !== "" && locale !== vars.LANG)
            apply({
                "LANG": locale
            }, `language ${locale}`);
    }
    function setVars(list: var, locale: string, what: string): void {
        if (locale === "mixed")
            return;
        const c = {};
        for (const v of list)
            c[v] = locale;
        apply(c, locale === "" ? `${what} like the language` : `${what} ${locale}`);
    }
    function tidy(text: string, fallback: string): string {
        const t = String(text ?? "").split("\n").map(s => s.trim()).filter(s => s !== "").pop() ?? "";
        return t !== "" ? t : fallback;
    }

    // "System Locale: LANG=en_US.UTF-8" then "               LC_TIME=en_GB.UTF-8" lines
    Process {
        id: status
        command: ["localectl", "status"]
        environment: ({
                "LC_ALL": "C"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {};
                let inLocale = false;
                for (const line of text.split("\n")) {
                    const m = /^\s*([A-Za-z0-9 ]+):\s*(.*)$/.exec(line);
                    let rest = line.trim();
                    if (m && !/^[A-Z_]+=/.test(rest)) {
                        inLocale = m[1].trim() === "System Locale";
                        rest = m[2].trim();
                    }
                    if (!inLocale)
                        continue;
                    const kv = /^([A-Z_]+)=(.*)$/.exec(rest);
                    if (kv)
                        v[kv[1]] = kv[2];
                }
                root.vars = v;
                root.ready = true;
            }
        }
    }
    Process {
        id: lister
        command: ["localectl", "list-locales"]
        stdout: StdioCollector {
            onStreamFinished: root.locales = text.split("\n").map(s => s.trim()).filter(s => s !== "")
        }
    }
}
