import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

// Session lock (ext-session-lock-v1) of the compositor qs is connected to. One LockSurface
// per screen (the clock is on every monitor); state + PAM live in services/Lock.qml.
// Trigger: `qs -c luxshell ipc call luxshell lock` (keybind, hypridle lock_cmd).
//
// A config reload (qs reloads on file changes) keeps the lock (PersistentProperties below).
//
// If qs DIES while locked, the session STAYS locked (that is the protocol's promise):
// Hyprland paints its "lockdead" screen ("Oopsie daisy ...") and nothing accepts input.
// Way out (all tested in the sandbox, Hyprland 0.56):
//   1. Another TTY: Ctrl+Alt+F3 (any free VT), log in as the same user.
//   2. Instance number: `hyprctl instances` (usually 0). A hung (not dead) luxshell first:
//        qs kill -c luxshell
//   3. Unlock directly (only works once the lock client is gone):
//        hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'
//      or hand the lock to a fresh luxshell and unlock with the password:
//        hyprctl --instance 0 eval 'hl.config({ misc = { allow_session_lock_restore = true } })'
//        hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("qs -c luxshell -d")'
//        hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("qs -c luxshell ipc call luxshell lock")'
//      WITHOUT allow_session_lock_restore Hyprland refuses that re-lock and the new qs dies
//      with a Wayland protocol error ("invalid object") - set the option first.
//   4. Back to the Hyprland VT: Ctrl+Alt+F1/F2 (the one it was started on), exit the TTY login.
// Sandbox (tools/sandbox.sh): `sandbox.sh hypr <name> eval 'hl.clear_crashed_lockscreen()'`
// or simply `sandbox.sh stop <name>`.
Scope {
    id: root

    // Lock.locked survives a config reload (qs reloads on every file change): a reload
    // must never unlock. The new WlSessionLock takes the lock over from the old one.
    PersistentProperties {
        id: persist
        reloadableId: "luxshellLock"

        property bool locked: false

        onReloaded: if (locked)
            Lock.lock()
    }
    Connections {
        target: Lock
        function onLockedChanged(): void {
            persist.locked = Lock.locked;
            if (Lock.locked)
                Ui.close(); // no panel waiting (with keyboard grab) behind the lock
        }
    }

    WlSessionLock {
        id: session

        locked: Lock.locked || persist.locked

        // refused (another lock client holds the session) or ended by the compositor
        onLockStateChanged: if (!locked && Lock.locked)
            Lock.lost()

        LockSurface {}
    }
}
