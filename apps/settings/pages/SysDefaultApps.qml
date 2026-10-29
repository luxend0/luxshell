import QtQuick
import qs.config
import qs.services
import qs.apps.settings

// System > Default Apps: which app opens links and files of each kind (services/DefaultApps:
// xdg-mime query / default, i.e. $XDG_CONFIG_HOME/mimeapps.list). A row offers the launcher's apps
// that can open that kind; picking one sets every type of the kind the app lists. The terminal is
// luxshell's own setting (Settings.terminal, the Launcher page's row): same key, same list of
// installed terminals, no copy. No luxshell keys: rows have no reset arrow (there is no default
// to go back to), the page's "Reset page" leaves them alone.
SettingsPage {
    id: page

    pageId: "defaultapps"
    group: "system"
    title: "Default Apps"
    subtitle: "Which app opens links, folders and files of each kind."
    icon: 0xF1577 // md-application-cog-outline

    // other programs change mimeapps.list too: read again while the page shows
    Timer {
        running: SettingsApp.open && (SettingsApp.page === page.pageId || SettingsApp.query !== "") // search shows the rows too
        repeat: true
        triggeredOnStart: true
        interval: 60000
        onTriggered: DefaultApps.refresh()
    }
    Connections {
        target: DefaultApps
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

    function appRow(c: var): var {
        return {
            "id": `default-${c.id}`,
            "kind": "choice",
            "label": c.label,
            "keywords": `default app application open with mime xdg ${c.words}`,
            "resettable": false,
            "enabled": () => DefaultApps.ready && DefaultApps.busy === "",
            "value": () => DefaultApps.ready ? DefaultApps.value(c.id) : "",
            "set": v => DefaultApps.set(c.id, v),
            "options": () => DefaultApps.ready ? DefaultApps.candidates(c.id) : [
                    {
                        "value": "",
                        "label": "Reading...",
                        "detail": ""
                    }
                ]
        };
    }

    // the Launcher page's list of installed terminals (it runs the check once)
    function terminals(): var {
        const launcher = Array.from(Catalog.sources).find(s => s.pageId === "launcher");
        const list = launcher ? Array.from(launcher.terminals) : [];
        return list.includes(Settings.terminal) ? list : [Settings.terminal, ...list];
    }
    readonly property var terminalRow: ({
            "id": "default-terminal",
            "kind": "choice",
            "key": "terminal",
            "resettable": false, // the Launcher page owns the key (and its reset)
            "label": "Terminal",
            "keywords": "default app terminal console shell kitty foot alacritty launcher",
            "options": () => page.terminals().map(t => ({
                        "value": t,
                        "label": t,
                        "detail": t === Settings.terminal ? "also Launcher > Terminal" : ""
                    }))
        })

    readonly property var rows: {
        const out = [];
        for (const c of DefaultApps.categories) {
            out.push(appRow(c));
            if (c.id === "files")
                out.push(terminalRow);
        }
        return out;
    }

    readonly property bool hasError: DefaultApps.error !== ""

    sections: [
        {
            "title": "",
            "options": page.rows.concat(page.hasError ? [
                    {
                        "id": "defaultAppsError",
                        "kind": "custom",
                        "label": "",
                        "component": errorNote,
                        "keywords": "error",
                        "text": () => DefaultApps.error,
                        "dismiss": () => DefaultApps.error = ""
                    }
                ] : [])
        },
        {
            "title": "",
            "options": [
                {
                    "id": "defaultAppsNote",
                    "kind": "custom",
                    "label": "",
                    "component": note,
                    "keywords": "mimeapps xdg-mime file types",
                    "text": () => `Saved in ${HyprSystem.tilde(Exec.configHome + "/mimeapps.list")} (xdg-mime), for every program that opens files the XDG way. A row sets all file types of its kind that the app can open. The terminal is luxshell's own: launcher commands and apps that need a terminal open in it.`
                }
            ]
        }
    ]
}
