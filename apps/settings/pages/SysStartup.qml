import QtQuick
import qs.config
import qs.services
import qs.apps.settings

// System > Startup Apps: what starts at login, from three places (services/Autostart), each in
// its own section:
//   luxshell        HyprSystem's autostart list -> luxshell-system.lua (start with Hyprland): add an
//                   app or a command, on/off, remove (Undo in the toast)
//   Hyprland config hl.exec_cmd lines of hyprland.lua and luxos/*.lua, shown only (edit the file)
//   XDG autostart   ~/.config/autostart: on/off = Hidden=, remove asks first; the system's
//                   (/etc/xdg/autostart) can be turned off for this user only (a hiding copy)
// No luxshell keys: nothing to reset here.
SettingsPage {
    id: page

    pageId: "startup"
    group: "system"
    title: "Startup Apps"
    subtitle: "What starts when you log in, and where it is set."
    icon: 0xF14DF // md-rocket-launch-outline

    Timer {
        running: SettingsApp.open && (SettingsApp.page === page.pageId || SettingsApp.query !== "") // search shows the rows too
        repeat: true
        triggeredOnStart: true
        interval: 15000
        onTriggered: Autostart.refresh()
    }
    Connections {
        target: Autostart
        function onNotice(text: string): void {
            SettingsApp.toast(text, null);
        }
    }

    Component {
        id: list
        StartupList {}
    }
    Component {
        id: note
        Note {}
    }
    Component {
        id: errorNote
        ErrorNote {}
    }

    // Icon= of a .desktop file -> image URL ("" = glyph)
    function iconOf(name: string): string {
        return name !== "" ? Apps.iconPath(name) : "";
    }
    function luxshellEntries(): var {
        return Autostart.luxshell.map((e, i) => {
            const app = Autostart.appFor(e.cmd);
            return {
                "key": `lux-${i}`,
                "index": i,
                "label": app ? app.name : e.cmd,
                "detail": app ? e.cmd : "",
                "icon": app ? Apps.iconSource(app) : "",
                "glyph": 0xF018D, // md-console
                "on": e.enabled,
                "toggle": true,
                "remove": true,
                "confirm": false
            };
        });
    }
    function hyprEntries(): var {
        return Autostart.hypr.map((h, i) => {
            const bits = [`${h.short}:${h.line}`];
            if (!h.start)
                bits.push("every config load");
            if (h.nested)
                bits.push("inside a block");
            return {
                "key": `hypr-${i}`,
                "label": h.cmd,
                "detail": bits.join(" · "),
                "icon": "",
                "glyph": 0xF018D,
                "on": true,
                "lock": true
            };
        });
    }
    function xdgDetail(e: var): string {
        const bits = [];
        if (e.skipped)
            bits.push(e.onlyIn.length > 0 ? `only in ${e.onlyIn.join(", ")}` : `not in ${e.notIn.join(", ")}`);
        if (e.override && !e.override.ours)
            bits.push("your copy");
        bits.push(e.exec);
        return bits.join(" · ");
    }
    function userEntries(): var {
        return Autostart.user.map(e => ({
                    "key": e.path,
                    "src": e,
                    "label": e.name,
                    "detail": page.xdgDetail(e),
                    "icon": page.iconOf(e.icon),
                    "glyph": 0xF08C6, // md-application
                    "on": e.on,
                    "dim": e.skipped,
                    "toggle": true,
                    "remove": true,
                    "confirm": true
                }));
    }
    function systemEntries(): var {
        return Autostart.system.map(e => ({
                    "key": e.path,
                    "src": e,
                    "label": e.name,
                    "detail": page.xdgDetail(e),
                    "icon": page.iconOf(e.icon),
                    "glyph": 0xF08C6,
                    "on": e.on,
                    "dim": e.skipped,
                    "toggle": true
                }));
    }
    function runnerText(): string {
        switch (Autostart.runner) {
        case "systemd":
            return "These start through systemd (xdg-desktop-autostart.target).";
        case "dex":
            return "These start through dex (run from the Hyprland config or luxshell's list).";
        case "uwsm":
            return "These start through uwsm.";
        }
        return "Nothing in this session starts XDG entries (no xdg-desktop-autostart.target, dex or uwsm): they stay off whatever their switch says, until something runs them at login (e.g. \"dex -a\" in luxshell's list above).";
    }

    readonly property bool hasError: Autostart.error !== ""

    sections: [
        {
            "title": "luxshell",
            "options": [
                {
                    "id": "startupLuxshell",
                    "kind": "custom",
                    "label": "Start with Hyprland",
                    "keywords": "autostart startup login luxshell exec once hyprland start app command",
                    "component": list,
                    "entries": () => page.luxshellEntries(),
                    "setOn": (e, on) => Autostart.setLuxshell(e.index, on),
                    "remove": e => {
                        const before = Autostart.removeLuxshell(e.index);
                        SettingsApp.toast(`Removed ${e.label}`, () => HyprSystem.setAutostart(before));
                    },
                    "candidates": () => Apps.all.filter(a => Autostart.commandOf(a) !== "" && !Autostart.luxshell.some(x => x.cmd === Autostart.commandOf(a))).map(a => ({
                                "value": a.id,
                                "label": a.name,
                                "detail": ""
                            })),
                    "pick": id => Autostart.addApp(Apps.all.find(a => a.id === id)),
                    "addLabel": "Add an app",
                    "emptyText": "Nothing yet"
                },
                {
                    "id": "startupCommand",
                    "kind": "text",
                    "label": "Add a command",
                    "keywords": "autostart startup command exec shell script",
                    "placeholder": "e.g. nm-applet --indicator",
                    "mono": true,
                    "value": () => "",
                    "apply": t => {
                        if (Autostart.addCommand(t))
                            SettingsApp.toast(`Added ${t.trim()}`, null);
                    }
                },
                {
                    "id": "startupLuxshellNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "keywords": "luxshell-system.lua hyprland.start",
                    "text": () => `Started by Hyprland at login, in this order. luxshell writes them to ${HyprSystem.tilde(HyprSystem.file)}, which hyprland.lua runs at its end; a change counts from the next login.`
                }
            ]
        },
        {
            "title": "Hyprland config",
            "options": [
                {
                    "id": "startupHypr",
                    "kind": "custom",
                    "label": "Managed in hyprland.lua",
                    "keywords": "autostart startup hyprland exec_cmd hyprland.lua config read only",
                    "component": list,
                    "entries": () => page.hyprEntries(),
                    "summary": () => Autostart.hypr.length === 0 ? "" : `${Autostart.hypr.length}`,
                    "emptyText": () => Autostart.ready ? "No exec_cmd lines" : "Reading..."
                },
                {
                    "id": "startupHyprNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "keywords": "hyprland.lua edit",
                    "text": () => `Shown, not changed: these lines live in ${HyprSystem.tilde(Autostart.hyprDir + "/hyprland.lua")} and luxos/*.lua. Edit the file to change them.`
                }
            ]
        },
        {
            "title": "XDG autostart",
            "options": [
                {
                    "id": "startupXdgUser",
                    "kind": "custom",
                    "label": "Yours",
                    "keywords": "autostart startup xdg desktop ~/.config/autostart hidden",
                    "component": list,
                    "entries": () => page.userEntries(),
                    "setOn": (e, on) => Autostart.setXdg(e.src, on),
                    "remove": e => Autostart.removeXdg(e.src),
                    "emptyText": () => Autostart.ready ? "None in ~/.config/autostart" : "Reading..."
                },
                {
                    "id": "startupXdgSystem",
                    "kind": "custom",
                    "label": "System (all users)",
                    "keywords": "autostart startup xdg system /etc/xdg/autostart hide",
                    "component": list,
                    "entries": () => page.systemEntries(),
                    "setOn": (e, on) => Autostart.setSystem(e.src, on),
                    "emptyText": () => Autostart.ready ? "None in /etc/xdg/autostart" : "Reading..."
                }
            ].concat(page.hasError ? [
                    {
                        "id": "startupError",
                        "kind": "custom",
                        "label": "",
                        "component": errorNote,
                        "keywords": "error",
                        "text": () => Autostart.error,
                        "dismiss": () => Autostart.error = ""
                    }
                ] : []).concat([
                {
                    "id": "startupXdgNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "keywords": "xdg autostart runner systemd dex uwsm hidden",
                    "text": () => page.runnerText() + " Turning a system entry off hides it for you only: a copy with Hidden=true in ~/.config/autostart, deleted again when you turn it on."
                }
            ])
        }
    ]
}
