pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.config

// Lock screen state + authentication. lock/LockScreen.qml (WlSessionLock) follows `locked`,
// every lock surface (one per screen) renders the state below and forwards keys here.
//
//   lock()      IPC `luxshell lock` (keybind, idle daemon lock_cmd). Locks the compositor
//               qs is connected to: in the sandbox that is the nested Hyprland.
//   phase       idle      hint line ("Press Any Key to Enter Password")
//               input     password pill (first key or click)
//               checking  PAM (or the test password) is running, keys are ignored
//               unlocking success: surfaces fade out, then the lock is released
//   failed()    wrong password: surfaces shake the pill, the buffer is already empty
//
// PAM: <shell>/pam/luxshell-lock (system-auth without pam_faillock, see the file), or the
// service named in Settings.lockPam from /etc/pam.d. The password lives only in `buffer`
// (never logged, never written) and is dropped after a failed try, Esc, or forgetMs idle.
//
// TEST MODE (sandbox only): LUXSHELL_LOCK_TEST_PASSWORD=<pw> together with LUXSHELL_DRYRUN=1
// compares the typed text with <pw> instead of asking PAM, so unlocking can be tested
// without the real password. Without DRYRUN the variable is ignored (warning at start).
Singleton {
    id: root

    property bool locked: false
    property string phase: "idle"
    property string buffer: ""
    property bool caps: false
    property string message: ""            // PAM error text, shown under the pill

    signal failed

    readonly property string user: Env.get("USER")
    readonly property bool testMode: Env.lockTestPassword !== "" && Exec.dry

    // ---- backdrop: the applied wallpaper, a still of a video wallpaper, else the screenshot
    readonly property string wallpaper: Settings.wallpaper
    readonly property bool wallpaperVideo: wallpaper !== "" && Wallpapers.isVideo(wallpaper)
    readonly property string stillPath: wallpaperVideo ? `${Wallpapers.cacheDir}/lock/${Qt.md5(wallpaper)}.jpg` : ""
    property string still: ""              // stillPath once the frame exists
    readonly property string backdrop: wallpaper === "" ? "" : wallpaperVideo ? still : wallpaper

    // ---- avatar: Settings.lockAvatar; ~/.face, ~/.face.icon, AccountsService icon
    property string avatar: ""

    function lock(): void {
        if (locked)
            return;
        reset();
        locked = true;
        readCaps();
    }

    // LockScreen: the compositor refused or ended the lock (another lock client, compositor reset)
    function lost(): void {
        if (!locked)
            return;
        console.warn("luxshell: session lock was not granted or ended by the compositor");
        pam.abortIfActive();
        locked = false;
        reset();
    }

    function reset(): void {
        phase = "idle";
        buffer = "";
        message = "";
        idle.stop();
    }

    // ---- input (from the focused surface) -------------------------------------
    function reveal(): void {
        if (!locked || phase === "checking" || phase === "unlocking")
            return;
        phase = "input";
        idle.restart();
    }

    function type(text: string, shift: bool): void {
        if (phase === "checking" || phase === "unlocking")
            return;
        // Caps Lock from the letter case: an upper-case letter without Shift (or lower with)
        const up = text.toUpperCase(), low = text.toLowerCase();
        if (text.length === 1 && up !== low)
            caps = (text === up) !== shift;
        buffer += text;
        message = "";
        reveal();
    }

    function erase(all: bool): void {
        if (phase === "checking" || phase === "unlocking")
            return;
        buffer = all ? "" : buffer.slice(0, -1);
        reveal();
    }

    function cancel(): void {
        if (phase === "checking" || phase === "unlocking")
            return;
        buffer = "";
        message = "";
        phase = "idle";
        idle.stop();
    }

    function submit(): void {
        if (phase === "checking" || phase === "unlocking")
            return;
        if (buffer === "") {
            reveal();
            return;
        }
        phase = "checking";
        idle.stop();
        message = "";
        if (testMode) {
            testCheck.restart();
            return;
        }
        pam.pending = buffer;
        if (!pam.start()) {
            pam.pending = "";
            fail("Authentication could not be started");
        }
    }

    function succeed(): void {
        buffer = "";
        phase = "unlocking";
        release.restart();
    }

    function fail(text: string): void {
        buffer = "";
        message = text;
        phase = "input";
        idle.restart();
        failed();
    }

    // Caps Lock from the compositor (main keyboard): at lock time and after the Caps key
    function readCaps(): void {
        capsProc.running = false;
        capsProc.running = true;
    }
    function capsKey(): void {
        capsDelay.restart();
    }

    // ---- test password (only with LUXSHELL_DRYRUN=1) ---------------------------
    Timer {
        id: testCheck
        interval: Motion.ms(450) // stands in for PAM's round trip
        onTriggered: {
            const ok = root.buffer === Env.lockTestPassword;
            console.info(`luxshell[test]: lock password checked against LUXSHELL_LOCK_TEST_PASSWORD (PAM bypassed): ${ok ? "match" : "no match"}`);
            if (ok)
                root.succeed();
            else
                root.fail("");
        }
    }

    // ---- PAM -----------------------------------------------------------------
    PamContext {
        id: pam

        property string pending: ""
        property bool answered: false

        function abortIfActive(): void {
            pending = "";
            if (active)
                abort();
        }

        configDirectory: Settings.lockPam !== "" ? "/etc/pam.d" : Quickshell.shellPath("pam")
        config: Settings.lockPam !== "" ? Settings.lockPam : "luxshell-lock"

        onActiveChanged: if (active)
            answered = false
        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            if (!answered && pending !== "") {
                answered = true;
                respond(pending);
                pending = "";
            } else {
                // a second prompt (OTP, new password ...) is not supported on the lock screen
                pending = "";
                abort();
                root.fail(message !== "" ? message : "Unsupported authentication step");
            }
        }
        onCompleted: result => {
            pending = "";
            if (result === PamResult.Success)
                root.succeed();
            else if (root.phase === "checking")
                root.fail(result === PamResult.MaxTries ? "Too many attempts" : result === PamResult.Error ? "Authentication error" : "");
        }
        onError: error => {
            pending = "";
            console.warn(`luxshell: lock PAM error: ${PamError.toString(error)}`);
            if (root.phase === "checking")
                root.fail("Authentication error");
        }
        // error texts from the stack ("account locked" ...); prompts themselves are not shown
        onPamMessage: if (messageIsError && message !== "")
            root.message = message
    }

    // ---- unlock: surfaces fade out first (lock/LockSurface), then the lock is released
    Timer {
        id: release
        interval: Motion.ms(Theme.lock.unlockOut)
        onTriggered: {
            root.locked = false;
            root.reset();
        }
    }

    // ---- idle: an empty field falls back to the hint, a typed password is forgotten
    Timer {
        id: idle
        interval: root.buffer === "" ? Theme.lock.idleMs : Theme.lock.forgetMs
        onTriggered: root.cancel()
    }
    onBufferChanged: if (phase === "input")
        idle.restart()

    // ---- caps lock: hyprctl devices (compositor qs runs in, nested in the sandbox)
    Timer {
        id: capsDelay
        interval: 60 // the keyboard state changes after the key reached the compositor
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

    // ---- video wallpaper -> one still frame (cached, nice/ionice, one thread)
    onStillPathChanged: makeStill()
    function makeStill(): void {
        still = "";
        if (stillPath === "")
            return;
        stillProc.running = false;
        stillProc.command = ["sh", "-c", `
src=$1; dst=$2
mkdir -p "\${dst%/*}" || exit 1
if [ -s "$dst" ] && [ "$dst" -nt "$src" ]; then echo "$dst"; exit 0; fi
tmp="$dst.part.jpg"
nice -n 19 ionice -c 3 ffmpeg -nostdin -v error -threads 1 -ss 1 -i "$src" -frames:v 1 -vf "scale=1920:-2" -q:v 3 -update 1 -y "$tmp" </dev/null
[ -s "$tmp" ] || nice -n 19 ionice -c 3 ffmpeg -nostdin -v error -threads 1 -i "$src" -frames:v 1 -vf "scale=1920:-2" -q:v 3 -update 1 -y "$tmp" </dev/null
[ -s "$tmp" ] && mv -f "$tmp" "$dst" && echo "$dst"`, "luxshell-lock-still", wallpaper, stillPath];
        stillProc.running = true;
    }
    Process {
        id: stillProc
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p !== "" && p === root.stillPath)
                    root.still = p;
                else if (root.stillPath !== "")
                    console.info(`luxshell: no lock screen still for ${root.wallpaper}`);
            }
        }
    }

    // ---- avatar lookup (first existing file wins)
    readonly property bool wantAvatar: Settings.lockAvatar
    onWantAvatarChanged: findAvatar()
    function findAvatar(): void {
        avatar = "";
        if (!wantAvatar)
            return;
        const home = Env.get("HOME");
        avatarProc.command = ["sh", "-c", 'for f in "$@"; do [ -s "$f" ] && { echo "$f"; exit 0; }; done', "luxshell-avatar", `${home}/.face`, `${home}/.face.icon`, `/var/lib/AccountsService/icons/${user}`];
        avatarProc.running = true;
    }
    Process {
        id: avatarProc
        stdout: StdioCollector {
            onStreamFinished: root.avatar = text.trim()
        }
    }

    Component.onCompleted: {
        if (Env.lockTestPassword !== "") {
            if (Exec.dry)
                console.warn("luxshell: lock screen TEST MODE - LUXSHELL_LOCK_TEST_PASSWORD replaces PAM (LUXSHELL_DRYRUN=1)");
            else
                console.warn("luxshell: LUXSHELL_LOCK_TEST_PASSWORD ignored - only honoured with LUXSHELL_DRYRUN=1");
        }
        makeStill();
        findAvatar();
    }
}
