pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Caffeine tile of the control center: keeps the session awake (hypridle and friends honour
// logind idle inhibitors) by holding `systemd-inhibit --what=idle` while it is on. The lock
// lives as long as this shell: quitting luxshell ends it, so it is runtime state, never
// saved. Turning it on goes through Exec (LUXSHELL_DRYRUN only logs, the tile stays off).
Singleton {
    id: root

    property bool active: false

    function toggle(): void {
        set(!active);
    }

    function set(on: bool): void {
        if (on === active)
            return;
        if (on && !Exec.allow("idle inhibit on: systemd-inhibit --what=idle"))
            return;
        active = on;
    }

    Process {
        running: root.active
        command: ["systemd-inhibit", "--what=idle", "--who=luxshell", "--why=Caffeine (control center)", "--mode=block", "sleep", "infinity"]
        // the inhibitor died on its own (logind restart, killed): the tile follows
        onExited: (code, status) => {
            if (root.active)
                root.active = false;
        }
    }
}
