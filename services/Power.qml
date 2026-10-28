pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Power actions of the power menu (panels/PowerMenu.qml) and the settings page Power.
//
//   catalog        every action in default order: lock logout suspend reboot poweroff firmware
//   shown          ids the menu lists (Settings.powerActions, order kept), firmware only when
//                  logind can reboot into the firmware setup (or a custom command is set)
//   confirm(id)    a second click / Enter is needed (Settings.powerConfirm)
//   run(id)        Settings.powerCommands[id] (sh -c) or the default below; ALWAYS through
//                  services/Exec, LUXSHELL_DRYRUN=1 only logs
//   detail(id)     the info line under an action (keybind, windows, kernel, updates, uptime)
//
// Defaults: lock = luxshell lock screen (services/Lock), logout = hl.dsp.exit() on the
// compositor qs runs in, suspend / reboot / poweroff / firmware = systemctl.
// refresh() reads kernel, uptime, pacman upgrades since boot, firmware support and the lock
// keybind once (one sh + one hyprctl, ~10 ms); the menu calls it on open, nothing polls.
Singleton {
    id: root

    readonly property var catalog: [
        {
            "id": "lock",
            "title": "Lock Screen",
            "glyph": "lock",
            "keywords": "lock screen",
            "verb": "lock",
            "plain": "Apps keep running",
            "def": "luxshell lock screen"
        },
        {
            "id": "logout",
            "title": "Log Out",
            "glyph": "log-out",
            "keywords": "log out logout sign off exit quit session hyprland",
            "verb": "log out",
            "plain": "Quit Hyprland",
            "def": "hl.dsp.exit()"
        },
        {
            "id": "suspend",
            "title": "Sleep",
            "glyph": "moon",
            "keywords": "sleep suspend standby",
            "verb": "sleep",
            "plain": "Resume where you left off",
            "def": "systemctl suspend"
        },
        {
            "id": "reboot",
            "title": "Restart",
            "glyph": "rotate-cw",
            "keywords": "restart reboot",
            "verb": "restart",
            "plain": "Restart the computer",
            "def": "systemctl reboot"
        },
        {
            "id": "poweroff",
            "title": "Shut Down",
            "glyph": "power",
            "keywords": "shut down shutdown power off poweroff halt",
            "verb": "shut down",
            "plain": "Turn the computer off",
            "def": "systemctl poweroff"
        },
        {
            "id": "firmware",
            "title": "Firmware Setup",
            "glyph": "cpu",
            "keywords": "firmware bios uefi setup reboot",
            "verb": "restart into the firmware",
            "plain": "Restart into BIOS / UEFI",
            "def": "systemctl reboot --firmware-setup"
        }
    ]
    readonly property var ids: catalog.map(a => a.id)
    readonly property var argv: ({
            "suspend": ["systemctl", "suspend"],
            "reboot": ["systemctl", "reboot"],
            "poweroff": ["systemctl", "poweroff"],
            "firmware": ["systemctl", "reboot", "--firmware-setup"]
        })

    // ---- facts (refresh) ----------------------------------------------------------------
    property bool firmwareSupported: false   // logind CanRebootToFirmwareSetup: yes | challenge
    property bool firmwareKnown: false
    property string kernel: ""
    property string host: ""
    property real bootEpoch: 0               // s
    property bool kernelPending: false       // running kernel's modules are gone: updated on disk
    property int upgrades: 0                 // pacman "upgraded" lines since boot (-1 = no pacman log)
    property string lockBind: ""             // "Super+L" from hyprctl binds, else Settings.keysBinds.lock
    readonly property string user: Env.get("USER")

    function entry(id: string): var {
        return catalog.find(a => a.id === id) ?? null;
    }
    function command(id: string): string {
        const c = (Settings.powerCommands ?? {})[id];
        return typeof c === "string" ? c.trim() : "";
    }
    function available(id: string): bool {
        return id !== "firmware" || firmwareSupported || command(id) !== "";
    }
    function confirm(id: string): bool {
        return (Settings.powerConfirm ?? {})[id] === true;
    }
    readonly property var shown: {
        const out = [];
        for (const id of Array.from(Settings.powerActions ?? []))
            if (ids.includes(id) && !out.includes(id) && available(id))
                out.push(id);
        return out;
    }

    function run(id: string): void {
        const custom = command(id);
        if (custom !== "") {
            Exec.run(["sh", "-c", custom], `power ${id}`);
            return;
        }
        switch (id) {
        case "lock":
            if (Exec.allow("power lock: luxshell lock screen (Lock.lock)"))
                Lock.lock();
            break;
        case "logout":
            if (Exec.allow("power logout: hl.dsp.exit()"))
                Hyprland.dispatch("hl.dsp.exit()");
            break;
        default:
            if (argv[id])
                Exec.run(argv[id], `power ${id}`);
            else
                console.warn(`luxshell: unknown power action "${id}"`);
        }
    }

    // ---- info lines ---------------------------------------------------------------------
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function duration(s: real): string {
        const m = Math.floor(s / 60), h = Math.floor(m / 60), d = Math.floor(h / 24);
        if (d > 0)
            return `${d} day${d === 1 ? "" : "s"}${h % 24 > 0 ? ` ${h % 24} h` : ""}`;
        if (h > 0)
            return `${h} h${m % 60 > 0 ? ` ${m % 60} min` : ""}`;
        return `${Math.max(1, m)} min`;
    }
    readonly property string uptime: bootEpoch > 0 ? duration(clock.date.getTime() / 1000 - bootEpoch) : ""
    readonly property int windows: Hyprland.toplevels.values.length
    readonly property bool restartHint: kernelPending || upgrades > 0

    // details: false = the plain line of the catalog (Settings.powerDetails off)
    function detail(id: string, details: bool): string {
        const a = entry(id);
        if (!a)
            return "";
        if (!details)
            return a.plain;
        switch (id) {
        case "lock":
            return lockBind !== "" ? lockBind : a.plain;
        case "logout":
            return windows > 0 ? `Quits Hyprland, ${windows} window${windows === 1 ? "" : "s"} open` : a.plain;
        case "reboot":
            if (kernelPending)
                return "Kernel updated, restart to load it";
            if (upgrades > 0)
                return `${upgrades} update${upgrades === 1 ? "" : "s"} installed since boot`;
            return kernel !== "" ? `Kernel ${kernel}` : a.plain;
        case "poweroff":
            return uptime !== "" ? `Up ${uptime}` : a.plain;
        default:
            return a.plain;
        }
    }

    // ---- refresh ------------------------------------------------------------------------
    function refresh(): void {
        if (!facts.running)
            facts.running = true;
        if (!binds.running)
            binds.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: facts
        command: ["sh", "-c", `
k=$(uname -r)
echo "kernel=$k"
echo "host=$(cat /proc/sys/kernel/hostname 2>/dev/null)"
read up _ < /proc/uptime
boot=$(( $(date +%s) - \${up%.*} ))
echo "boot=$boot"
[ -d "/usr/lib/modules/$k" ] && echo pending=0 || echo pending=1
if [ -r /var/log/pacman.log ]; then
  since=$(date -d "@$boot" +%Y-%m-%dT%H:%M:%S)
  tail -n 6000 /var/log/pacman.log | awk -v s="$since" 'substr($1, 2, 19) > s && $2 == "[ALPM]" && $3 == "upgraded" { n++ } END { print "upgrades=" n + 0 }'
else
  echo upgrades=-1
fi
fw=$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanRebootToFirmwareSetup 2>/dev/null)
echo "firmware=\${fw#s }"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        v[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                root.kernel = v.kernel ?? "";
                root.host = v.host ?? "";
                root.bootEpoch = parseFloat(v.boot) || 0;
                root.kernelPending = v.pending === "1" && root.kernel !== "";
                root.upgrades = parseInt(v.upgrades) || 0;
                const fake = Env.get("LUXSHELL_FAKE_UPGRADES"); // screenshots (config/Env)
                if (fake === "kernel")
                    root.kernelPending = true;
                else if (fake !== "")
                    root.upgrades = parseInt(fake) || 0;
                const fw = (v.firmware ?? "").replace(/"/g, "");
                root.firmwareSupported = fw === "yes" || fw === "challenge";
                root.firmwareKnown = true;
            }
        }
    }

    // the keybind that locks (hyprctl binds of the compositor qs runs in)
    Process {
        id: binds
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.lockBind = root.findLockBind(text)
        }
    }

    function formatBind(mask: int, key: string): string {
        const mods = [];
        if (mask & 64)
            mods.push("Super");
        if (mask & 4)
            mods.push("Ctrl");
        if (mask & 8)
            mods.push("Alt");
        if (mask & 1)
            mods.push("Shift");
        const names = {
            "escape": "Esc",
            "return": "Enter",
            "space": "Space",
            "delete": "Del"
        };
        const k = names[key.toLowerCase()] ?? (key.length === 1 ? key.toUpperCase() : key);
        return [...mods, k].join("+");
    }

    function findLockBind(json: string): string {
        let list = [];
        try {
            list = JSON.parse(json);
        } catch (e) {
            list = [];
        }
        const re = /lock-session|hyprlock|swaylock|gtklock|waylock|luxshell\s+lock|\block\b/i;
        for (const b of Array.isArray(list) ? list : []) {
            const what = `${b.arg ?? ""} ${b.description ?? ""}`;
            if (b.key && re.test(what) && !/unlock/i.test(what) && !b.release && !b.mouse)
                return formatBind(b.modmask ?? 0, String(b.key));
        }
        // the luxshell keybind file (Settings > Keybinds), when it is in use
        const own = Settings.keysEnabled ? String((Settings.keysBinds ?? {}).lock ?? "") : "";
        return own.split("+").map(s => s.trim()).filter(s => s !== "").map(s => s === "SUPER" ? "Super" : s === "SHIFT" ? "Shift" : s === "CTRL" || s === "CONTROL" ? "Ctrl" : s === "ALT" ? "Alt" : s.length === 1 ? s.toUpperCase() : s).join("+");
    }
}
