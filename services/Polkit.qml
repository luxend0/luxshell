pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import qs.config
import qs.core

// Polkit authentication agent (Quickshell.Services.Polkit) and the state of the prompt
// (panels/PolkitPrompt.qml, registry id "polkit"). Lock screen language: the password lives in
// `buffer` here (never logged, never written), the panel only renders it and forwards keys.
//
//   Registration: ONLY with LUXSHELL_POLKIT=1 (config/Env.qml). One agent per session: while
//   another one (Ambxst, polkit-gnome ...) is registered, ours is refused (warning in the log).
//
//   flow       the request on screen: the agent's AuthFlow, or a fake one with the same surface
//              (FakeFlow below), so the panel and this file run one code path for both
//   phase      idle      nothing asked
//              input     prompt open, typing
//              checking  password handed to polkit, waiting for the verdict (dots breathe)
//              success   authorised: the pill shows a check, the prompt closes a moment later
//   failed()   wrong password: the panel shakes the pill, the buffer is already empty
//
// A new request opens the prompt on the focused monitor; Esc / Cancel cancel the request.
// Another panel may take the island meanwhile (launcher ...): when it closes, the prompt comes
// back with what was typed. Requests arriving while one is open wait (the agent queues them).
//
// Test hook (no polkit involved): LUXSHELL_FAKE_POLKIT=1 enables `qs -p <shell> ipc call polkit
// fake <kind>` (single | multi | service | long), a kind as the value also starts one at start.
// The fake password is "test". `... polkit cancel`, `... polkit state`.
Singleton {
    id: root

    // ---- agent -------------------------------------------------------------------------------
    readonly property bool enabled: Env.polkit
    property QtObject agent: null
    readonly property bool registered: agent?.isRegistered ?? false
    readonly property bool fakeEnabled: Env.fakePolkit !== ""

    // ---- request -------------------------------------------------------------------------------
    property QtObject fakeFlow: null
    readonly property QtObject flow: fakeFlow ?? agent?.flow ?? null
    property QtObject current: null // the flow the prompt shows (flow, followed in onFlowChanged)

    property string phase: "idle"
    property string buffer: ""
    property string note: ""        // under the pill: wrong password, PAM messages, caps lock
    property bool noteError: false
    property bool caps: false
    property int misses: 0
    property string screen: ""      // monitor the prompt was opened on
    property bool pendingSubmit: false
    property var avatars: ({})      // user name -> picture path (~/.face, AccountsService)

    signal failed

    readonly property string user: Env.get("USER")
    readonly property string message: current?.message ?? ""
    readonly property string actionId: current?.actionId ?? ""
    readonly property string iconName: current?.iconName ?? ""
    readonly property bool echo: current?.responseVisible ?? false
    readonly property string inputPrompt: current?.inputPrompt ?? ""
    readonly property bool ready: current?.isResponseRequired ?? false

    // identities as plain values: { ref, name, display, uid, group, avatar }
    readonly property var identities: {
        const out = [];
        const list = current?.identities ?? [];
        for (let i = 0; i < list.length; i++) {
            const id = list[i];
            const name = String(id.string ?? id.id);
            out.push({
                "ref": id,
                "name": name,
                "display": id.displayName && id.displayName !== name ? String(id.displayName) : "",
                "uid": id.id,
                "group": !!id.isGroup,
                "avatar": id.isGroup ? "" : (avatars[name] ?? "")
            });
        }
        return out;
    }
    readonly property int selected: {
        // by value: a fake flow's plain objects come back as copies from its var property
        const sel = current?.selectedIdentity ?? null;
        if (!sel)
            return 0;
        for (let i = 0; i < identities.length; i++) {
            const c = identities[i];
            if (c.uid === sel.id && c.group === !!sel.isGroup && c.name === String(sel.string ?? sel.id))
                return i;
        }
        return 0;
    }
    readonly property var identity: identities[selected] ?? null

    // who asks: a label + themed icon from the action id (polkit names no process); the
    // action's own icon_name wins when it has one
    readonly property var requesterTable: [
        ["org.freedesktop.policykit.exec", "pkexec", "utilities-terminal"],
        ["org.freedesktop.udisks2.", "Disks", "drive-harddisk"],
        ["org.freedesktop.login1.", "Power and sessions", "system-shutdown"],
        ["org.freedesktop.NetworkManager", "Network", "network-wired"],
        ["org.freedesktop.network1.", "Network", "network-wired"],
        ["org.freedesktop.resolve1.", "Network", "network-wired"],
        ["org.freedesktop.Flatpak.", "Flatpak", "system-software-install"],
        ["org.freedesktop.packagekit.", "Software", "system-software-install"],
        ["org.freedesktop.sysupdate1.", "System update", "system-software-update"],
        ["org.freedesktop.timedate1.", "Date and time", "preferences-system-time"],
        ["org.freedesktop.timesync1.", "Date and time", "preferences-system-time"],
        ["org.freedesktop.locale1.", "Language and keyboard", "preferences-desktop-locale"],
        ["org.freedesktop.hostname1.", "Hostname", "computer"],
        ["org.freedesktop.accounts.", "User accounts", "system-users"],
        ["org.freedesktop.home1.", "User accounts", "system-users"],
        ["org.freedesktop.UPower", "Power", "system-shutdown"],
        ["org.freedesktop.RealtimeKit1.", "RealtimeKit", "audio-card"],
        ["org.freedesktop.systemd1.", "systemd", "preferences-system"],
        ["org.freedesktop.machine1.", "systemd", "computer"],
        ["org.freedesktop.import1.", "systemd", "computer"],
        ["org.freedesktop.portable1.", "systemd", "computer"],
        ["io.systemd.", "systemd", "preferences-system"],
        ["org.bluez", "Bluetooth", "bluetooth"],
        ["org.opensuse.cupspkhelper", "Printers", "printer"],
        ["org.gtk.vfs.", "Files", "system-file-manager"],
        ["com.feralinteractive.GameMode", "GameMode", "input-gaming"],
        ["org.debian.pcsc-lite.", "Smart card", "security-high"]
    ]
    readonly property var requester: {
        const a = actionId;
        let label = "", icon = "";
        for (const r of requesterTable)
            if (a === r[0] || a.startsWith(r[0])) {
                label = r[1];
                icon = r[2];
                break;
            }
        if (label === "" && a !== "") {
            // an app's own action (org.gnome.gparted, org.kde.kpmcore...): its desktop entry
            const parts = a.split(".");
            for (let i = parts.length - 1; i >= 1 && label === ""; i--) {
                const e = DesktopEntries.heuristicLookup(parts[i]);
                if (e) {
                    label = e.name;
                    icon = e.icon;
                }
            }
            if (label === "")
                label = parts.length > 1 ? parts[1].charAt(0).toUpperCase() + parts[1].slice(1) : a;
        }
        if (iconName !== "")
            icon = iconName;
        return {
            "label": label !== "" ? label : "System",
            "icon": icon !== "" ? Quickshell.iconPath(icon, true) : ""
        };
    }

    // what the prompt shows: a copy of the live values above, kept after the request ended so
    // the card does not go blank while it fades out
    property var view: ({
            "message": "",
            "actionId": "",
            "iconName": "",
            "requester": {
                "label": "",
                "icon": ""
            },
            "identities": [],
            "selected": 0
        })
    function refreshView(): void {
        if (!current)
            return;
        view = {
            "message": message,
            "actionId": actionId,
            "iconName": iconName,
            "requester": requester,
            "identities": identities.map(i => ({
                        "name": i.name,
                        "display": i.display,
                        "uid": i.uid,
                        "group": i.group,
                        "avatar": i.group ? "" : (avatars[i.name] ?? "") // not i.avatar: may still be stale here
                    })),
            "selected": selected
        };
    }
    onAvatarsChanged: refreshView()

    // ---- flow changes ----------------------------------------------------------------------
    onFlowChanged: {
        const prev = current;
        if (prev && prev !== flow)
            finish(prev);
        current = flow;
        if (flow)
            begin();
    }

    function begin(): void {
        closeLater.stop();
        phase = "input";
        buffer = "";
        note = "";
        noteError = false;
        misses = 0;
        pendingSubmit = false;
        // the user's own identity first, if polkit offers it (admin rules list wheel members)
        const own = identities.findIndex(i => !i.group && i.name === user);
        if (own > 0)
            select(own);
        refreshView();
        findAvatars();
        readCaps();
        console.info(`luxshell: polkit request ${actionId} (${identities.length} identit${identities.length === 1 ? "y" : "ies"})${current === fakeFlow ? " [fake]" : ""}`);
        screen = Ui.focusedScreen();
        Ui.open("polkit", screen);
    }

    function finish(prev: QtObject): void {
        const ok = prev.isSuccessful === true;
        console.info(`luxshell: polkit request ${prev.actionId} ${ok ? "authorised" : prev.isCancelled ? "cancelled" : "ended"}`);
        buffer = "";
        pendingSubmit = false;
        if (ok) {
            phase = "success";
            note = "";
            closeLater.restart();
        } else {
            phase = "idle";
            if (Ui.panel === "polkit")
                Ui.close();
        }
    }

    Timer {
        id: closeLater
        interval: Motion.ms(Theme.polkit.successHold)
        onTriggered: {
            if (root.current)
                return; // the next queued request already took over
            root.phase = "idle";
            if (Ui.panel === "polkit")
                Ui.close();
        }
    }

    // another panel took the island (or something closed it): back as soon as it is free
    Connections {
        target: Ui
        function onPanelChanged() {
            if (Ui.panel === "" && root.current && (root.phase === "input" || root.phase === "checking"))
                Qt.callLater(root.reopen);
        }
    }
    function reopen(): void {
        if (Ui.panel === "" && current && (phase === "input" || phase === "checking"))
            Ui.open("polkit", Quickshell.screens.some(s => s.name === screen) ? screen : Ui.focusedScreen());
    }

    // ---- verdicts from the flow ------------------------------------------------------------------
    Connections {
        target: root.current
        ignoreUnknownSignals: true

        function onAuthenticationFailed() {
            if (root.phase !== "checking")
                return; // a session restarted by an identity switch, not a wrong password
            root.buffer = "";
            root.misses++;
            root.phase = "input";
            const s = root.current?.supplementaryMessage ?? "";
            root.note = s !== "" && root.current.supplementaryIsError ? s : "Wrong password, try again";
            root.noteError = true;
            root.failed();
        }
        function onIsResponseRequiredChanged() {
            if (root.current?.isResponseRequired && root.pendingSubmit) {
                root.pendingSubmit = false;
                root.send();
            }
        }
        function onSelectedIdentityChanged() {
            Qt.callLater(root.refreshView); // after `selected` followed the same signal
        }
        function onSupplementaryMessageChanged() {
            const s = root.current?.supplementaryMessage ?? "";
            if (s !== "") {
                root.note = s;
                root.noteError = root.current.supplementaryIsError;
            }
        }
    }

    // ---- input (from the prompt) -------------------------------------------------------------
    function type(text: string, shift: bool): void {
        if (!current || phase !== "input")
            return;
        const up = text.toUpperCase(), low = text.toLowerCase();
        if (text.length === 1 && up !== low)
            caps = (text === up) !== shift;
        buffer += text;
        if (noteError) { // a typed key drops the "wrong password" line (lock screen)
            note = "";
            noteError = false;
        }
    }

    function erase(all: bool): void {
        if (!current || phase !== "input")
            return;
        buffer = all ? "" : buffer.slice(0, -1);
    }

    function submit(): void {
        if (!current || phase !== "input" || buffer === "")
            return;
        phase = "checking";
        note = "";
        noteError = false;
        if (current.isResponseRequired)
            send();
        else
            pendingSubmit = true; // the session is still starting (after a miss / identity switch)
    }
    function send(): void {
        if (current && phase === "checking")
            current.submit(buffer);
    }

    function cancel(): void {
        buffer = "";
        pendingSubmit = false;
        if (current)
            current.cancelAuthenticationRequest();
        else if (Ui.panel === "polkit")
            Ui.close();
    }

    function select(i: int): void {
        if (!current || i < 0 || i >= identities.length || i === selected || phase === "checking")
            return;
        buffer = "";
        note = "";
        noteError = false;
        pendingSubmit = false;
        current.selectedIdentity = identities[i].ref;
    }
    function step(delta: int): void {
        const n = identities.length;
        if (n > 1)
            select(((selected + delta) % n + n) % n);
    }

    // ---- caps lock (compositor keyboard state, as services/Lock) ----------------------------
    function readCaps(): void {
        capsProc.running = false;
        capsProc.running = true;
    }
    function capsKey(): void {
        capsDelay.restart();
    }
    Timer {
        id: capsDelay
        interval: 60
        onTriggered: root.readCaps()
    }
    Process {
        id: capsProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards ?? [];
                    const main = kbs.find(k => k.main);
                    root.caps = main ? !!main.capsLock : kbs.some(k => k.capsLock);
                } catch (e) {}
            }
        }
    }

    // ---- avatars: ~/.face, ~/.face.icon, AccountsService (readable files only) -------------------
    function findAvatars(): void {
        const names = identities.filter(i => !i.group).map(i => i.name);
        if (names.length === 0)
            return;
        avatarProc.running = false;
        avatarProc.command = ["sh", "-c", `
for u in "$@"; do
    h=$(getent passwd "$u" | cut -d: -f6)
    for f in "$h/.face" "$h/.face.icon" "/var/lib/AccountsService/icons/$u"; do
        [ -n "$h" ] || [ "\${f#/var}" != "$f" ] || continue
        [ -r "$f" ] && [ -s "$f" ] && { printf '%s\\t%s\\n' "$u" "$f"; break; }
    done
done`, "luxshell-polkit-avatars"].concat(names);
        avatarProc.running = true;
    }
    Process {
        id: avatarProc
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const t = line.indexOf("\t");
                    if (t > 0)
                        map[line.slice(0, t)] = line.slice(t + 1);
                }
                root.avatars = map;
            }
        }
    }

    // ---- real agent (LUXSHELL_POLKIT=1 only) ------------------------------------------------------
    Component {
        id: agentComponent
        PolkitAgent {
            onIsRegisteredChanged: console.info(`luxshell: polkit agent ${isRegistered ? "registered" : "unregistered"} (${path})`)
        }
    }
    Timer {
        id: registerCheck
        interval: 3000
        onTriggered: if (root.agent && !root.agent.isRegistered)
            console.warn("luxshell: polkit agent not registered - is another agent running in this session?")
    }

    // ---- fake requests (LUXSHELL_FAKE_POLKIT, tests + screenshots) --------------------------------
    // Same properties, signals and timing shape as AuthFlow: a session asks for the password
    // shortly after it starts, a wrong one fails and restarts the session, cancel completes.
    component FakeFlow: QtObject {
        id: ff

        property string message: ""
        property string iconName: ""
        property string actionId: ""
        property string cookie: "fake"
        property var identities: [] // plain { id, string, displayName, isGroup } like Identity
        property var selectedIdentity: identities.length > 0 ? identities[0] : null
        property bool isResponseRequired: false
        property string inputPrompt: ""
        property bool responseVisible: false
        property string supplementaryMessage: ""
        property bool supplementaryIsError: false
        property bool isCompleted: false
        property bool isSuccessful: false
        property bool isCancelled: false
        property bool failed: false
        property string answer: ""

        signal authenticationSucceeded
        signal authenticationFailed
        signal authenticationRequestCancelled

        function startSession(): void {
            isResponseRequired = false;
            inputPrompt = "";
            sessionTimer.restart();
        }
        function submit(value: string): void {
            if (isCompleted || !isResponseRequired)
                return;
            answer = value;
            isResponseRequired = false;
            inputPrompt = "";
            checkTimer.restart();
        }
        function cancelAuthenticationRequest(): void {
            if (isCompleted)
                return;
            sessionTimer.stop();
            checkTimer.stop();
            isCancelled = true;
            isCompleted = true;
        }
        onSelectedIdentityChanged: if (!isCompleted)
            startSession()
        Component.onCompleted: startSession()

        readonly property Timer sessionTimer: Timer {
            interval: Motion.ms(140) // polkit-agent-helper-1 starting PAM
            onTriggered: {
                ff.inputPrompt = "Password: ";
                ff.responseVisible = false;
                ff.isResponseRequired = true;
            }
        }
        readonly property Timer checkTimer: Timer {
            interval: Motion.ms(650) // pam_unix's delay
            onTriggered: {
                const ok = ff.answer === "test";
                ff.answer = "";
                console.info(`luxshell[fake]: polkit password ${ok ? "accepted" : "rejected"} (fake flow, no PAM)`);
                if (ok) {
                    ff.isSuccessful = true;
                    ff.isCompleted = true;
                    ff.authenticationSucceeded();
                } else {
                    ff.failed = true;
                    ff.authenticationFailed();
                    ff.startSession();
                }
            }
        }
    }
    Component {
        id: fakeFlowComponent
        FakeFlow {}
    }
    readonly property var fakeKinds: ({
            "single": {
                "message": "Authentication is needed to run `/usr/bin/pacman -Syu' as the super user",
                "actionId": "org.freedesktop.policykit.exec",
                "iconName": "",
                "users": [[1000, "$USER", ""]]
            },
            "multi": {
                "message": "Authentication is required to mount Samsung SSD 990 PRO 2TB (/dev/nvme1n1p2)",
                "actionId": "org.freedesktop.udisks2.filesystem-mount-system",
                "iconName": "",
                "users": [[0, "root", ""], [1000, "$USER", ""], [1001, "admin", "Administrator"]]
            },
            "service": {
                "message": "Authentication is required to restart 'sshd.service'.",
                "actionId": "org.freedesktop.systemd1.manage-units",
                "iconName": "",
                "users": [[1000, "$USER", ""]]
            },
            "long": {
                "message": "Authentication is needed to run `/usr/bin/env LANG=C /usr/lib/luxos/system-maintenance --rebuild-initramfs --all-kernels --verbose' as the super user",
                "actionId": "org.freedesktop.policykit.exec",
                "iconName": "",
                "users": [[1000, "$USER", ""]]
            }
        })

    function fake(kind: string): string {
        if (!fakeEnabled)
            return "fake requests need LUXSHELL_FAKE_POLKIT";
        const k = fakeKinds[kind === "" || kind === "1" ? "single" : kind];
        if (!k)
            return `unknown kind "${kind}" (${Object.keys(fakeKinds).join(" | ")})`;
        if (fakeFlow)
            fakeFlow.cancelAuthenticationRequest();
        const ids = k.users.map(u => ({
                    "id": u[0],
                    "string": u[1] === "$USER" ? user : u[1],
                    "displayName": u[2] !== "" ? u[2] : (u[1] === "$USER" ? user : u[1]),
                    "isGroup": false
                }));
        const f = fakeFlowComponent.createObject(root, {
            "message": k.message,
            "actionId": k.actionId,
            "iconName": k.iconName,
            "identities": ids
        });
        f.isCompletedChanged.connect(() => {
            if (!f.isCompleted)
                return;
            if (root.fakeFlow === f)
                root.fakeFlow = null;
            Qt.callLater(() => f.destroy());
        });
        fakeFlow = f;
        return "ok";
    }

    IpcHandler {
        target: "polkit"

        function fake(kind: string): string {
            return root.fake(kind);
        }
        function cancel(): void {
            root.cancel();
        }
        function state(): string {
            return JSON.stringify({
                "enabled": root.enabled,
                "registered": root.registered,
                "fake": root.fakeEnabled,
                "phase": root.phase,
                "action": root.actionId,
                "message": root.message,
                "requester": root.requester.label,
                "identities": root.identities.map(i => i.name),
                "selected": root.selected,
                "ready": root.ready,
                "prompt": root.inputPrompt,
                "typed": root.buffer.length,
                "misses": root.misses,
                "note": root.note
            });
        }
    }

    Component.onCompleted: {
        if (enabled) {
            agent = agentComponent.createObject(root);
            registerCheck.start();
        }
        if (fakeEnabled && Env.fakePolkit !== "1")
            Qt.callLater(() => root.fake(Env.fakePolkit));
    }
}
