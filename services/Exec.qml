pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
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

    // ---- hyprctl eval (Hyprland Lua config) ---------------------------------------------
    // Changes to the compositor's settings (services/HyprSystem: input, devices, monitors).
    // done(ok, answer) gets Hyprland's reply ("ok" or the Lua error); in a dry run it is
    // called with (true, "dry run") after the log line. LUXSHELL_HYPR_LIVE=1 lets the call
    // through even in a dry run: the sandbox's nested Hyprland (never the real desktop).
    readonly property bool hyprLive: Env.get("LUXSHELL_HYPR_LIVE") === "1"

    function hyprEval(lua: string, what: string, done: var): void {
        if (dry && !hyprLive) {
            allow(`${what}: hyprctl eval ${lua}`);
            if (done)
                done(true, "dry run");
            return;
        }
        if (dry)
            console.info(`luxshell[dry, nested hyprctl]: ${what}: ${lua}`);
        const p = evalProc.createObject(root, {
            "done": done ?? null
        });
        p.command = ["hyprctl", "eval", lua];
        p.running = true;
    }

    // ---- a command with an answer (nmcli, pactl, bluetoothctl) ---------------------------
    // Like run(), but done(ok, text) gets the exit (code 0) and stdout + stderr, so the caller
    // can re-read state or show the error (System > Sound, Network & Bluetooth). In a dry run
    // only the log line, then done(true, "dry run").
    function runDone(argv: var, what: string, done: var): void {
        if (!allow(`${what}: ${argv.join(" ")}`)) {
            if (done)
                done(true, "dry run");
            return;
        }
        const p = cmdProc.createObject(root, {
            "done": done ?? null
        });
        p.command = argv;
        p.running = true;
    }

    Component {
        id: cmdProc
        Process {
            id: cp
            property var done: null
            property int code: -1
            property int pending: 3 // stdout, stderr, exit
            function step(): void {
                if (--pending > 0)
                    return;
                const text = (cpOut.text + "\n" + cpErr.text).trim();
                if (code !== 0)
                    console.warn(`luxshell: ${command[0]}: ${text || "exit " + code}`);
                if (done)
                    done(code === 0, text);
                destroy();
            }
            stdout: StdioCollector {
                id: cpOut
                onStreamFinished: cp.step()
            }
            stderr: StdioCollector {
                id: cpErr
                onStreamFinished: cp.step()
            }
            onExited: c => {
                code = c;
                step();
            }
        }
    }

    Component {
        id: evalProc
        Process {
            id: proc
            property var done: null
            property int code: -1
            property bool exited: false
            property bool gotOutput: false
            function finish(): void {
                if (!exited || !gotOutput)
                    return;
                const text = evalOut.text.trim();
                const ok = code === 0 && (text === "ok" || text === "");
                if (!ok)
                    console.warn(`luxshell: hyprctl eval: ${text || "exit " + code}`);
                if (done)
                    done(ok, text);
                destroy();
            }
            stdout: StdioCollector {
                id: evalOut
                onStreamFinished: {
                    proc.gotOutput = true;
                    proc.finish();
                }
            }
            onExited: c => {
                code = c;
                exited = true;
                finish();
            }
        }
    }
}
