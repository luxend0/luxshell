pragma Singleton
import QtQuick
import Quickshell
import qs.config

// Screenshot button of the control center: grim (+ slurp for a region), saved to
// Settings.ccScreenshotDir as <date>_<time>.png and copied to the clipboard (wl-copy).
// take() waits until the island has folded away, so it is not in the picture. Through
// Exec: LUXSHELL_DRYRUN only logs.
Singleton {
    id: root

    readonly property string home: Env.get("HOME")
    function expand(p: string): string {
        return p === "~" ? home : p.startsWith("~/") ? home + p.slice(1) : p;
    }

    readonly property string script: 'd=$1; mode=$2; mkdir -p "$d" || exit 1; f="$d/$(date +%Y-%m-%d_%H-%M-%S).png"; ' + 'if [ "$mode" = region ]; then g=$(slurp) || exit 0; grim -g "$g" "$f"; else grim "$f"; fi && ' + '{ command -v wl-copy >/dev/null && wl-copy --type image/png < "$f"; true; }'

    function take(): void {
        delay.restart();
    }

    Timer {
        id: delay
        interval: Motion.ms(450) // panel morph back into the collapsed island
        onTriggered: {
            const dir = root.expand(Settings.ccScreenshotDir || "~/Pictures/Screenshots");
            const mode = Settings.ccScreenshotMode === "screen" ? "screen" : "region";
            Exec.run(["sh", "-c", root.script, "luxshell-screenshot", dir, mode], `screenshot (${mode}) to ${dir}`);
        }
    }
}
