pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.core
import qs.services

// Settings app state: open/closed, current page, back/forward history, search text.
// The window itself (SettingsWindow.qml) exists only while open (SettingsHost.qml).
//
//   qs -c luxshell ipc call luxshell open settings         (island gear, keybinds)
//   qs -c luxshell ipc call settings open [page]           page id, "" = last page
//   qs -c luxshell ipc call settings toggle | close
//   qs -c luxshell ipc call settings back | forward
//   qs -c luxshell ipc call settings search <text>         open with the search filled in
//   qs -c luxshell ipc call settings state
//   qs -c luxshell ipc call settings get <key|path>         JSON of the value
//   qs -c luxshell ipc call settings set <key|path> <json>  JSON value (a bare word = string; start an
//                                                           array with a space: ' ["a", "b"]', the qs CLI splits [a,b])
//   qs -c luxshell ipc call settings reset <key|path>
//   qs -c luxshell ipc call settings resetPage <page>
//   qs -c luxshell ipc call settings changed                 keys that differ from the default
//   qs -c luxshell ipc call settings exportFile <path>      backup (Backup.qml)
//   qs -c luxshell ipc call settings importFile <path>      replaces every preference
//
// Page ids: Catalog.pages (bar, media, clock, appearance, wallpaper, motion, launcher,
// notifications, controlcenter, lockscreen, keybinds, integrations, system, demo; group
// "system": input); empty ones are hidden.
//
// Before the first open a window rule for this window is registered in the running
// Hyprland (hyprctl eval, like services/GameMode): floating, no border/shadow/blur,
// so the window's own rounded corners show (1:1 with the video).
Singleton {
    id: root

    readonly property string title: "luxshell Settings"

    property bool open: false
    property string page: "appearance"
    property string query: ""
    property string screenName: ""   // monitor the window opens on (frozen while open)
    property var backStack: []
    property var forwardStack: []

    readonly property bool canBack: backStack.length > 0
    readonly property bool canForward: forwardStack.length > 0

    signal searchRequested   // window: focus the search field
    signal pageShown(string id)

    // bottom toast of the window ("Reset 3 options  Undo"); undo: a function, a
    // Settings.snapshot() to restore, or null (no Undo)
    property string toastText: ""
    property var toastUndo: null
    property int toastSeq: 0
    function toast(text: string, undo: var): void {
        toastText = text;
        toastUndo = undo ?? null;
        toastSeq++;
    }
    function undoToast(): void {
        if (typeof toastUndo === "function")
            toastUndo();
        else if (toastUndo)
            Settings.restore(toastUndo);
        toastUndo = null;
        toastText = "";
        toastSeq++;
    }

    // ---- "Keep these settings?" (KeepDialog.qml, over the window) ----------------------------
    // askKeep({ title, text, seconds, keepLabel, revertLabel, icon, keep, revert }): the change is
    // already live; the dialog counts down (default 15 s). Keep calls keep(); Revert, Esc, the
    // end of the countdown and closing the window call revert(). Opens the window when closed.
    // A request while one is open replaces it and starts the countdown again; the first one's
    // callbacks are dropped (HyprSystem.begin/commit/rollback span both changes).
    //   HyprSystem.begin(); HyprSystem.setMonitor("DP-3", { scale: 1.25 });
    //   SettingsApp.askKeep({ title: "Keep this display setting?", keep: () => HyprSystem.commit(), revert: () => HyprSystem.rollback() });
    property var keepRequest: null
    property int keepSeq: 0
    function askKeep(req: var): void {
        keepRequest = Object.assign({
            "title": "Keep these settings?",
            "text": "",
            "seconds": 15,
            "keepLabel": "Keep",
            "revertLabel": "Revert",
            "icon": 0xF02DA // md-history
        }, req ?? {});
        keepSeq++;
        if (!open && !pendingOpen)
            show("");
    }
    function settleKeep(kept: bool): void {
        const r = keepRequest;
        if (!r)
            return;
        keepRequest = null;
        keepSeq++;
        const fn = kept ? r.keep : r.revert;
        if (typeof fn === "function")
            fn();
    }

    function show(id: string): void {
        if (id !== undefined && id !== "") {
            if (open || pendingOpen)
                navigate(id);
            else if (Catalog.visible(id)) { // a fresh window starts on the page, no history entry
                page = id;
                query = "";
            }
        }
        if (open)
            return;
        screenName = Ui.focusedScreen();
        if (ruled) {
            open = true;
        } else {
            pendingOpen = true;
            if (!rule.running)
                rule.running = true;
        }
    }
    function hide(): void {
        settleKeep(false); // a pending "Keep these settings?" can no longer be answered: revert
        pendingOpen = false;
        open = false;
        query = ""; // a new window starts on its page, not on old results
    }
    function toggle(): void {
        if (open || pendingOpen)
            hide();
        else
            show("");
    }

    function navigate(id: string): void {
        if (!Catalog.visible(id)) {
            console.info(`luxshell: no settings page "${id}"`);
            return;
        }
        query = "";
        if (id === page)
            return;
        backStack = [...backStack, page];
        forwardStack = [];
        page = id;
        pageShown(id);
    }
    function back(): void {
        if (!canBack)
            return;
        query = "";
        forwardStack = [page, ...forwardStack];
        page = backStack[backStack.length - 1];
        backStack = backStack.slice(0, -1);
        pageShown(page);
    }
    function forward(): void {
        if (!canForward)
            return;
        query = "";
        backStack = [...backStack, page];
        page = forwardStack[0];
        forwardStack = forwardStack.slice(1);
        pageShown(page);
    }

    // ---- window rule (once per shell start) ---------------------------------------
    property bool ruled: false
    property bool pendingOpen: false

    Process {
        id: rule
        command: ["hyprctl", "eval", `hl.window_rule({ name = "luxshell-settings", match = { class = "org.quickshell", title = "${root.title}" }, float = true, border_size = 0, no_shadow = true, no_blur = true })`]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "" && text.trim() !== "ok")
                console.info(`luxshell: settings window rule: ${text.trim()}`)
        }
        onExited: {
            root.ruled = true;
            if (root.pendingOpen) {
                root.pendingOpen = false;
                root.open = true;
            }
        }
    }

    IpcHandler {
        target: "settings"

        function open(page: string): void {
            root.show(page);
        }
        function close(): void {
            root.hide();
        }
        function toggle(): void {
            root.toggle();
        }
        function back(): void {
            root.back();
        }
        function forward(): void {
            root.forward();
        }
        function search(text: string): void {
            root.show("");
            root.query = text;
            root.searchRequested();
        }
        function get(path: string): string {
            return JSON.stringify(Settings.get(path)) ?? "undefined";
        }
        function set(path: string, value: string): string {
            let v;
            try {
                v = JSON.parse(value);
            } catch (e) {
                v = value;
            }
            return Settings.set(path, v) ? "ok" : "error (see log)";
        }
        function reset(path: string): string {
            Settings.reset(path);
            return Settings.isDefault(path) ? "ok" : "error (see log)";
        }
        function resetPage(page: string): string {
            const p = Catalog.pages.find(x => x.id === page);
            return p ? `reset ${Catalog.resetPage(p)}` : `no page "${page}"`;
        }
        function changed(): string {
            return JSON.stringify(Settings.keys().filter(k => !Settings.isDefault(k)));
        }
        // try a monitor change with the "Keep these settings?" countdown (Displays page, tests):
        // qs ipc call settings tryMonitor HEADLESS-1 '{"scale": 1.25}'
        function tryMonitor(output: string, fields: string): string {
            let f;
            try {
                f = JSON.parse(fields);
            } catch (e) {
                return "fields: no JSON object";
            }
            HyprSystem.begin();
            HyprSystem.setMonitor(output, f);
            root.askKeep({
                "title": "Keep this display setting?",
                "text": `${output}: ${Object.keys(f).map(k => `${k} ${f[k]}`).join(", ")}`,
                "icon": 0xF0379, // md-monitor
                "keep": () => HyprSystem.commit(),
                "revert": () => HyprSystem.rollback()
            });
            return "ok";
        }
        function exportFile(path: string): void {
            Backup.exportTo(path);
        }
        function importFile(path: string): void {
            Backup.importFrom(path);
        }
        function state(): string {
            return JSON.stringify({
                "open": root.open,
                "page": root.page,
                "query": root.query,
                "pages": Catalog.visiblePages.map(p => p.id),
                "back": root.backStack,
                "forward": root.forwardStack
            });
        }
    }
}
