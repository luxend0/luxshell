pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.core

// Settings app state: open/closed, current page, back/forward history, search text.
// The window itself (SettingsWindow.qml) exists only while open (SettingsHost.qml).
//
//   qs -c luxshell ipc call luxshell open settings         (island gear, keybinds)
//   qs -c luxshell ipc call settings open [page]           page id, "" = last page
//   qs -c luxshell ipc call settings toggle | close
//   qs -c luxshell ipc call settings back | forward
//   qs -c luxshell ipc call settings search <text>         open with the search filled in
//   qs -c luxshell ipc call settings state
//
// Page ids: Catalog.pages (bar, clock, appearance, motion, launcher, notifications,
// controlcenter, system).
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
