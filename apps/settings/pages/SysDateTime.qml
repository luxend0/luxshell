import QtQuick
import qs.config
import qs.services
import qs.apps.settings

// System > Date, Time & Language: time zone and network time (services/SysClock, timedatectl),
// system language and formats (services/SysLocale, localectl -> /etc/locale.conf). Changes go
// through Exec.call (polkit asks; a refusal shows as a warning row until dismissed). The 12/24-hour
// clock and the keyboard layout have their own pages: linked, not copied. No luxshell keys.
SettingsPage {
    id: page

    pageId: "datetime"
    group: "system"
    title: "Date, Time & Language"
    subtitle: "Time zone, network time, language and formats of the system."
    icon: 0xF124A // md-web-clock

    // NTP sync and zone offsets change on their own: read again while the page shows
    Timer {
        running: SettingsApp.open && (SettingsApp.page === page.pageId || SettingsApp.query !== "") // search shows the rows too
        repeat: true
        triggeredOnStart: true
        interval: 15000
        onTriggered: {
            SysClock.refresh();
            SysLocale.refresh();
        }
    }
    Component.onCompleted: Xkb.load() // layout names for the keyboard link
    Connections {
        target: SysClock
        function onNotice(text: string): void {
            SettingsApp.toast(text, null);
        }
    }
    Connections {
        target: SysLocale
        function onNotice(text: string): void {
            SettingsApp.toast(text, null);
        }
    }

    Component {
        id: note
        Note {}
    }
    Component {
        id: errorNote
        ErrorNote {}
    }

    readonly property var timeFormats: ({
            "24h": "24-hour",
            "12h": "12-hour",
            "12h-ampm": "12-hour, AM/PM"
        })

    function nowText(): string {
        const w = SysClock.wall;
        return `${w.toLocaleDateString(Clock.locale, "dddd, d MMMM yyyy")}, ${Clock.formatTime(w, Settings.clockFormat)}`;
    }
    function syncText(): string {
        if (!SysClock.ready)
            return "Reading...";
        if (!SysClock.canNtp)
            return "No time service (systemd-timesyncd)";
        if (!SysClock.ntp)
            return "Off: the clock keeps its own time";
        return SysClock.synced ? "In sync with a time server" : "Waiting for a time server";
    }
    function localeOptions(withSame: bool, mixed: bool): var {
        const out = withSame ? [
            {
                "value": "",
                "label": "Same as language",
                "detail": SysLocale.label(SysLocale.vars.LANG ?? "C")
            }
        ] : [];
        for (const l of SysLocale.locales)
            out.push({
                "value": l,
                "label": SysLocale.label(l),
                "detail": l
            });
        if (mixed)
            out.push({
                "value": "mixed",
                "label": "Mixed",
                "detail": "set one by one below"
            });
        return out;
    }
    function groupRow(gr: var): var {
        return {
            "id": `locale-${gr.id}`,
            "kind": "choice",
            "label": gr.label,
            "keywords": `locale format region ${gr.vars.join(" ")} ${gr.words}`,
            "resettable": false,
            "enabled": () => SysLocale.ready && SysLocale.busy === "",
            "value": () => SysLocale.valueOf(gr.vars),
            "set": v => SysLocale.setVars(gr.vars, v, gr.label.toLowerCase()),
            "options": () => {
                const mixed = SysLocale.valueOf(gr.vars) === "mixed";
                const base = page.localeOptions(true, mixed);
                return base.map(o => {
                    if (o.value === "mixed")
                        return o;
                    const s = SysLocale.sample(gr.id, o.value, Clock.now);
                    return Object.assign({}, o, {
                        "detail": s !== "" ? s : o.detail
                    });
                });
            }
        };
    }

    // a failed change (polkit refused, ...) as a warning row under the rows it belongs to (added
    // after them, so the keyboard focus stays on the row that was changed)
    function errorRow(id: string, svc: var): var {
        return {
            "id": id,
            "kind": "custom",
            "label": "",
            "component": errorNote,
            "keywords": "error polkit",
            "text": () => svc.error,
            "dismiss": () => svc.error = ""
        };
    }
    readonly property bool clockError: SysClock.error !== ""
    readonly property bool localeError: SysLocale.error !== ""

    sections: [
        {
            "title": "Time",
            "options": [
                {
                    "id": "timeNow",
                    "kind": "info",
                    "label": "Date and time",
                    "keywords": "current time date now clock today",
                    "value": () => page.nowText()
                },
                {
                    "id": "timeNtp",
                    "kind": "switch",
                    "label": "Set the time automatically",
                    "keywords": "ntp network time sync synchronize automatic timesyncd internet",
                    "resettable": false,
                    "enabled": () => SysClock.ready && SysClock.canNtp && SysClock.busy === "",
                    "value": () => SysClock.ntp,
                    "set": v => SysClock.setNtp(v)
                },
                {
                    "id": "timeSync",
                    "kind": "info",
                    "label": "Network time",
                    "keywords": "ntp synchronized sync status time server",
                    "value": () => page.syncText()
                },
                {
                    "id": "timeZone",
                    "kind": "choice",
                    "label": "Time zone",
                    "keywords": "timezone zone region city utc offset gmt timedatectl",
                    "searchable": true,
                    "resettable": false,
                    "enabled": () => SysClock.ready && SysClock.zones.length > 0 && SysClock.busy === "",
                    "value": () => SysClock.zone,
                    "set": v => SysClock.setZone(v),
                    "options": () => SysClock.zones.length > 0 ? SysClock.zones.map(z => ({
                                "value": z.name,
                                "label": z.name.replace(/_/g, " "),
                                "detail": SysClock.zoneDetail(z.name)
                            })) : [
                            {
                                "value": SysClock.zone,
                                "label": SysClock.zone !== "" ? SysClock.zone.replace(/_/g, " ") : "Reading...",
                                "detail": ""
                            }
                        ]
                },
                {
                    "id": "timeFormatLink",
                    "kind": "link",
                    "label": "Time format",
                    "keywords": "12 24 hour am pm clock format",
                    "value": () => page.timeFormats[Settings.clockFormat] ?? Settings.clockFormat,
                    "run": () => SettingsApp.navigate("clock")
                }
            ].concat(page.clockError ? [page.errorRow("clockError", SysClock)] : [])
        },
        {
            "title": "Language and formats",
            "options": [
                {
                    "id": "localeLanguage",
                    "kind": "choice",
                    "label": "Language",
                    "keywords": "language locale lang system localectl translation messages",
                    "resettable": false,
                    "enabled": () => SysLocale.ready && SysLocale.locales.length > 0 && SysLocale.busy === "",
                    "value": () => SysLocale.vars.LANG ?? "",
                    "set": v => SysLocale.setLanguage(v),
                    "options": () => {
                        const list = page.localeOptions(false, false);
                        const cur = SysLocale.vars.LANG ?? "";
                        return cur === "" || list.some(o => o.value === cur) ? list : [
                            {
                                "value": cur,
                                "label": SysLocale.label(cur),
                                "detail": `${cur} (not generated)`
                            }
                        ].concat(list);
                    }
                },
                {
                    "id": "localeFormats",
                    "kind": "choice",
                    "label": "Formats",
                    "keywords": "formats region locale lc_time lc_numeric lc_monetary date number currency",
                    "resettable": false,
                    "enabled": () => SysLocale.ready && SysLocale.busy === "",
                    "value": () => SysLocale.valueOf(SysLocale.formatVars),
                    "set": v => SysLocale.setVars(SysLocale.formatVars, v, "formats"),
                    "options": () => page.localeOptions(true, SysLocale.valueOf(SysLocale.formatVars) === "mixed")
                }
            ].concat(SysLocale.groups.map(gr => page.groupRow(gr))).concat(page.localeError ? [page.errorRow("localeError", SysLocale)] : []).concat([
                {
                    "id": "localeExample",
                    "kind": "info",
                    "label": "Example",
                    "keywords": "preview example format date number currency",
                    "value": () => [SysLocale.sample("time", SysLocale.effective("LC_TIME"), Clock.now), SysLocale.sample("numbers", SysLocale.effective("LC_NUMERIC"), Clock.now), SysLocale.sample("money", SysLocale.effective("LC_MONETARY"), Clock.now)].join("   ")
                },
                {
                    "id": "localeNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "keywords": "locale.conf localectl login",
                    "text": "For the whole system (/etc/locale.conf, localectl): programs see a change from the next login. Only generated locales can be picked (locale-gen). luxshell's island clock keeps its own format (Clock & Date)."
                }
            ])
        },
        {
            "title": "Keyboard",
            "options": [
                {
                    "id": "keyboardLink",
                    "kind": "link",
                    "label": "Keyboard layout",
                    "keywords": "keyboard layout input language xkb",
                    "value": () => String(HyprSystem.current("input.kb_layout") ?? "").split(",").filter(s => s !== "").map(l => Xkb.layoutName(l.trim())).join(", "),
                    "run": () => SettingsApp.navigate("input")
                }
            ]
        }
    ]
}
