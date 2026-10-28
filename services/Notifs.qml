pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config
import qs.core

// Notifications: store (history for the control center + hover status) and the
// island peek ("live activity", panels/NotifOverlay.qml, overlay id "notif").
//
// The D-Bus server only runs with LUXSHELL_NOTIFS=1 (Ambxst owns
// org.freedesktop.Notifications during the transition); otherwise the store stays
// empty and count is LUXSHELL_FAKE_NOTIFS (default 0).
//
// Store: `entries`, newest first, plain copies (the D-Bus object may be gone later):
//   key, id (D-Bus id), app, group, icon, picture (icon is a photo), image, summary,
//   body, urgency (0 low, 1 normal, 2 critical), time (ms), actions [{ id, text }],
//   hasDefault, alive (actions still invocable), seen
// `groups`: the same entries per app (group = desktop entry, else app name).
// Actions for the control center: dismiss(key), clearGroup(group), clear(),
// invoke(key, actionId), markAllRead().
//
// Peek: one entry at a time in the island. A notification of the app that is
// peeking replaces it (newest wins, the badge counts the app's notifications);
// others queue and shorten the current peek. Hover/click on the peek expands it to
// the full card (expanded) and holds it; drag up hides it (it stays in the history).
// Settings.dnd: no peeks, critical ones excepted. Priority: an open panel hides
// the peek (paused; the control center consumes it), an activity OSD preempts it
// (the peek comes back for its remaining time).
Singleton {
    id: root

    readonly property bool live: Env.notifs

    // ---- store ------------------------------------------------------------------------
    property var entries: []
    property int nextKey: 1
    property var objs: ({}) // key -> Notification (not reactive; alive mirrors it)

    readonly property int count: live ? entries.length : Env.fakeNotifs
    readonly property int unread: entries.filter(e => !e.seen).length
    readonly property string status: count === 0 ? (Settings.dnd ? "Focus on" : "All caught up") : count === 1 ? "1 notification" : `${count} notifications`

    readonly property var groups: {
        const map = {};
        const out = [];
        for (const e of entries) {
            let g = map[e.group];
            if (!g) {
                g = map[e.group] = {
                    "group": e.group,
                    "app": e.app,
                    "icon": e.icon,
                    "picture": e.picture,
                    "entries": []
                };
                out.push(g);
            }
            g.entries.push(e);
        }
        return out;
    }

    function groupEntries(group: string): var {
        return entries.filter(e => e.group === group);
    }
    function groupCount(group: string): int {
        let n = 0;
        for (const e of entries)
            if (e.group === group)
                n++;
        return n;
    }
    function find(key: int): var {
        return entries.find(e => e.key === key) ?? null;
    }

    // themed icon / file / URL for a notification, "" if nothing resolves
    function iconFor(n: var): string {
        const ai = n.appIcon ?? "";
        if (ai.startsWith("/"))
            return "file://" + ai;
        if (ai.includes("://"))
            return ai;
        if (ai !== "") {
            const p = Quickshell.iconPath(ai, true);
            if (p !== "")
                return p;
        }
        for (const id of [n.desktopEntry, n.appName]) {
            if (!id)
                continue;
            const s = Apps.iconSource(DesktopEntries.heuristicLookup(id));
            if (s !== "")
                return s;
        }
        return "";
    }

    function makeEntry(n: var, key: int, old: var): var {
        const icon = iconFor(n);
        // a themed icon passed as image (libnotify does that with actions) is no picture
        const raw = n.image ?? "";
        const themed = raw.startsWith("image://icon/");
        const image = themed || raw === icon ? "" : raw;
        const actions = [];
        let hasDefault = false;
        for (const a of n.actions) {
            if (a.identifier === "default")
                hasDefault = true;
            else if (a.text !== "")
                actions.push({
                    "id": a.identifier,
                    "text": a.text
                });
        }
        return {
            "key": key,
            "id": n.id,
            "app": n.appName || n.desktopEntry || "Notification",
            "group": n.desktopEntry || n.appName || "unknown",
            // no app icon but an image (avatar, cover): the image stands in for the icon
            "icon": icon !== "" ? icon : (image !== "" ? image : raw),
            "picture": icon === "" && image !== "",
            "image": icon !== "" ? image : "",
            "summary": n.summary || n.appName || "",
            "body": n.body ?? "",
            "urgency": n.urgency === NotificationUrgency.Critical ? 2 : n.urgency === NotificationUrgency.Low ? 0 : 1,
            "time": old ? old.time : Date.now(),
            "actions": actions,
            "hasDefault": hasDefault,
            "transient": n.transient,
            "resident": n.resident,
            "alive": true,
            "seen": false
        };
    }

    function replaceEntry(key: int, fn: var): void {
        entries = entries.map(e => e.key === key ? fn(e) : e);
        if (peek?.key === key)
            peek = find(key);
    }

    function add(n: var): void {
        n.tracked = true;
        const key = nextKey++;
        objs[key] = n;
        const e = makeEntry(n, key, null);
        n.closed.connect(reason => root.closed(key, reason));
        // replaces_id: the server updates the same object; re-read it and peek again
        const changed = () => root.changed(key);
        n.summaryChanged.connect(changed);
        n.bodyChanged.connect(changed);
        n.actionsChanged.connect(changed);
        entries = [e, ...entries];
        arrive(e);
    }

    property var pendingChanges: ({})
    function changed(key: int): void {
        pendingChanges[key] = true;
        Qt.callLater(root.applyChanges);
    }
    function applyChanges(): void {
        const keys = Object.keys(pendingChanges);
        pendingChanges = {};
        for (const k of keys) {
            const key = parseInt(k);
            const n = objs[key];
            const old = find(key);
            if (!n || !old)
                continue;
            replaceEntry(key, e => makeEntry(n, key, e));
            arrive(find(key));
        }
    }

    function closed(key: int, reason: int): void {
        delete objs[key];
        // the app retracted it or it was dismissed: gone; expired (never by us): kept, inert
        if (reason === NotificationCloseReason.Expired)
            replaceEntry(key, e => Object.assign({}, e, {
                "alive": false,
                "actions": []
            }));
        else
            remove(key);
    }

    function remove(key: int): void {
        entries = entries.filter(e => e.key !== key);
        queue = queue.filter(e => e.key !== key);
        if (peek?.key === key)
            next();
    }

    function dismiss(key: int): void {
        const n = objs[key];
        if (n)
            n.dismiss(); // -> closed(Dismissed) -> remove
        else
            remove(key);
    }
    function clearGroup(group: string): void {
        for (const e of groupEntries(group))
            dismiss(e.key);
    }
    function clear(): void {
        for (const e of entries.slice())
            dismiss(e.key);
    }
    function invoke(key: int, actionId: string): void {
        const n = objs[key];
        const a = n ? [...n.actions].find(x => x.identifier === actionId) : null;
        if (a)
            a.invoke(); // non-resident notifications are dismissed by the server
    }
    function markAllRead(): void {
        entries = entries.map(e => e.seen ? e : Object.assign({}, e, {
                "seen": true
            }));
    }
    function markGroupRead(group: string): void {
        entries = entries.map(e => e.seen || e.group !== group ? e : Object.assign({}, e, {
                "seen": true
            }));
        if (peek)
            peek = find(peek.key);
    }

    LazyLoader {
        id: server
        active: root.live

        NotificationServer {
            keepOnReload: false
            bodySupported: true
            bodyMarkupSupported: false // bodies are shown as plain text
            actionsSupported: true
            imageSupported: true
            persistenceSupported: true
            onNotification: n => root.add(n)
        }
    }

    // ---- peek ---------------------------------------------------------------------------
    property var peek: null           // entry shown in the island
    property bool expanded: false     // compact peek -> full card
    property bool held: false         // pointer on it: no timeout
    property bool paused: false       // a panel is open
    property var queue: []
    property string peekScreen: ""
    property double peekUntil: 0
    property int remaining: 0

    // on-screen time; every duration goes through Motion.ms (LUXSHELL_SLOWMO)
    function duration(e: var): int {
        // seconds from the settings app (Notifications page); slow motion applies, animation speed does not
        const s = e.urgency === 2 ? Settings.notifTimeoutCritical : e.urgency === 0 || e.transient ? Settings.notifTimeoutLow : Settings.notifTimeout;
        return Math.round(Math.max(1, s) * 1000 * Motion.slowmo);
    }

    function arrive(e: var): void {
        if (!e)
            return;
        if ((Settings.dnd && e.urgency < 2) || Ui.panel === "controlcenter") {
            // no peek (focus, or the list is on screen already): stored, transient ones dropped
            if (e.transient)
                drop(e);
            return;
        }
        if (peek && peek.group === e.group) {
            peek = e;
            arm(duration(e));
            return;
        }
        if (peek) {
            queue = e.urgency === 2 ? [e, ...queue] : [...queue, e];
            if (!held && peek.urgency < 2)
                shorten(Motion.ms(1500)); // a critical peek keeps its time
            return;
        }
        start(e);
    }

    function start(e: var): void {
        peek = e;
        expanded = false;
        held = false;
        peekScreen = Ui.focusedScreen();
        arm(duration(e));
    }

    function arm(ms: int): void {
        peekUntil = Date.now() + ms;
        timer.interval = ms;
        if (paused)
            remaining = ms;
        else if (!held)
            timer.restart();
        sync();
    }

    function shorten(ms: int): void {
        if (peekUntil - Date.now() > ms)
            arm(ms);
    }

    // transient: shown, never kept in the history
    function drop(e: var): void {
        const n = objs[e.key];
        delete objs[e.key];
        entries = entries.filter(x => x.key !== e.key);
        if (n)
            n.expire();
    }

    function next(): void {
        const was = peek;
        if (was?.transient) {
            peek = null;
            drop(was);
        }
        if (queue.length > 0) {
            const e = queue[0];
            queue = queue.slice(1);
            start(e);
        } else {
            end();
        }
    }

    function end(): void {
        peek = null;
        expanded = false;
        held = false;
        timer.stop();
        sync();
    }

    // Ui owns the overlay slot; mirror the peek into it
    function sync(): void {
        if (!peek) {
            if (Ui.overlay === "notif")
                Ui.flash("notif", 1, Ui.overlayScreen);
            return;
        }
        if (paused || (Ui.overlay !== "" && Ui.overlay !== "notif"))
            return; // a panel or an activity is up; resumed when it ends
        Ui.flash("notif", held ? 600000 : Math.max(200, peekUntil - Date.now()) + Motion.ms(400), peekScreen);
    }

    // pointer on the peek / card (panels/NotifOverlay.qml)
    function hold(on: bool): void {
        if (!peek || held === on)
            return;
        held = on;
        if (on) {
            timer.stop();
            sync();
        } else {
            arm(Motion.ms(2200));
        }
    }

    function setExpanded(on: bool): void {
        if (!peek)
            return;
        expanded = on;
        if (on)
            markGroupRead(peek.group);
        hold(on);
    }

    // drag up: hide the peek, keep the notification
    function swipe(): void {
        if (!peek)
            return;
        markGroupRead(peek.group);
        expanded = false;
        held = false;
        next();
    }

    // drag-up from outside (ipc): the visible card flies up first, then swipe()
    signal swipeRequested
    function requestSwipe(): void {
        if (peek && Ui.overlay === "notif" && Ui.panel === "")
            swipeRequested();
        else
            swipe();
    }

    Timer {
        id: timer
        onTriggered: root.next()
    }

    Connections {
        target: Ui
        function onOverlayChanged() {
            if (Ui.overlay === "" && root.peek)
                root.sync(); // an activity preempted the peek
        }
        function onPanelChanged() {
            if (Ui.panel === "controlcenter") {
                for (const e of root.queue)
                    if (e.transient)
                        root.drop(e);
                root.queue = [];
                root.paused = false;
                if (root.peek?.transient)
                    root.drop(root.peek);
                if (root.peek)
                    root.end();
            } else if (Ui.panel !== "" && root.peek && !root.paused) {
                root.paused = true;
                root.remaining = Math.max(Motion.ms(1500), root.peekUntil - Date.now());
                timer.stop();
            } else if (Ui.panel === "" && root.paused) {
                root.paused = false;
                root.held = false;
                root.arm(root.remaining);
            }
        }
    }

    // ---- test / keybind hooks: qs -c luxshell ipc call notifs <fn> ----------------------
    IpcHandler {
        target: "notifs"

        function expand(on: bool): void {
            root.setExpanded(on);
        }
        function swipe(): void {
            root.requestSwipe();
        }
        function dnd(on: bool): void {
            Settings.set("dnd", on);
        }
        function clear(): void {
            root.clear();
        }
        function state(): string {
            return JSON.stringify({
                "live": root.live,
                "count": root.count,
                "unread": root.unread,
                "dnd": Settings.dnd,
                "peek": root.peek ? `${root.peek.app}: ${root.peek.summary}` : "",
                "icon": root.peek?.icon ?? "",
                "image": root.peek?.image ?? "",
                "expanded": root.expanded,
                "held": root.held,
                "queue": root.queue.map(e => e.summary),
                "groups": root.groups.map(g => `${g.app} (${g.entries.length})`)
            });
        }
    }
}
