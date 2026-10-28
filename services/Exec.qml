pragma Singleton
import QtQuick
import Quickshell
import qs.config

// The one gate for every action that changes system state (Wi-Fi, Bluetooth,
// volume, default sink, per-app volume, brightness, lock). LUXSHELL_DRYRUN=1
// turns them into log lines ("luxshell[dry]: ..."), so clicks and keys can be
// tested in the sandbox without touching the machine. luxshell-local state
// (config/Settings, hyprctl against the compositor the shell runs in, i.e. the
// nested Hyprland in the sandbox) is not gated.
Singleton {
    id: root

    readonly property bool dry: Env.get("LUXSHELL_DRYRUN") === "1"

    // true = go ahead; false = dry run, already logged
    function allow(what: string): bool {
        if (!dry)
            return true;
        console.info(`luxshell[dry]: ${what}`);
        return false;
    }

    function run(argv: var, what: string): void {
        if (allow(`${what}: ${argv.join(" ")}`))
            Quickshell.execDetached(argv);
    }
}
