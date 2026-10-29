pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs.config

// Who uses the microphone, the camera or the screen right now (island privacy widget +
// panels/PrivacyPanel). Event driven, no polling:
//   Pipewire  an ACTIVE link from a source into an app's capture stream (Stream/Input/*):
//             Audio/Source -> mic, a video source -> screen (portal cast node, xdph) or
//             camera (v4l2 / libcamera). Sink monitors (desktop audio), passive filter
//             streams, peak meters and luxshell's own streams do not count.
//   Hyprland  "screencast>>1,<owner>" while a client copies the screen continuously
//             (wlr-screencopy: wf-recorder, OBS wlrobs, and the portal itself); shown as
//             "Screen capture" when no Pipewire stream names the app.
// Only the capture streams (and their sources) are bound, read only.
//
//   entries  [{ key, kind: "mic" | "screen" | "camera", app, icon, detail, glyph }]
//   active   anything in use; mic / screen / camera per kind
//
// Test hook: LUXSHELL_FAKE_PRIVACY="mic:Discord:discord,screen:OBS Studio:com.obsproject.Studio"
// (kind:app:icon, comma separated) replaces the live list; same spec over IPC:
// `qs -p <shell> ipc call privacy fake '<spec>'` ("" = live again), `... privacy state`,
// `... privacy dump` (every Pipewire node with its class, for checking the detection).
Singleton {
    id: root

    readonly property var kinds: ({
            "mic": {
                "detail": "Microphone",
                "glyph": "mic"
            },
            "screen": {
                "detail": "Screen sharing",
                "glyph": "screen-share"
            },
            "camera": {
                "detail": "Camera",
                "glyph": "video"
            }
        })

    // ---- Pipewire ----------------------------------------------------------------------------
    readonly property var nodes: Pipewire.nodes.values
    // capture side of apps (Stream/Input/Audio, Stream/Input/Video): streams that are no sink
    readonly property var captures: nodes.filter(n => n && n.isStream && !n.isSink)
    readonly property var groups: Pipewire.linkGroups.values.filter(g => g && g.target && g.source && captures.includes(g.target))
    readonly property var sources: {
        const out = [];
        for (const g of groups)
            if (!out.includes(g.source))
                out.push(g.source);
        return out;
    }
    // the link groups too: unbound, their state stays "unlinked" and no recording ever counted
    // (bar-menus, 2026-10-29: pw-record showed up only with this)
    PwObjectTracker {
        objects: root.captures.concat(root.sources).concat(root.groups)
    }

    function prop(n: var, k: string): string {
        return String(n?.properties?.[k] ?? "");
    }
    function own(n: var): bool {
        return Number(prop(n, "application.process.id")) === Quickshell.processId;
    }
    // meters and filters that hold a capture stream without "using" the device
    function ignored(n: var): bool {
        return own(n) || prop(n, "stream.monitor") === "true" || prop(n, "node.passive") === "true" || /peak detect/i.test(prop(n, "media.name"));
    }
    // media.class once bound, the node type flags until then (VideoSource, AudioSource, ...)
    function kindOf(t: var, s: var): string {
        const tc = prop(t, "media.class") || PwNodeType.toString(t.type);
        const st = PwNodeType.toString(s.type);
        const sc = prop(s, "media.class") || (st === "AudioSource" ? "Audio/Source" : st === "AudioDuplex" ? "Audio/Duplex" : st.includes("Video") ? "Video/Source" : "");
        if (tc.includes("Video") || sc.startsWith("Video/")) {
            const cam = /^(v4l2|libcamera)/.test(s.name ?? "") || ["v4l2", "libcamera"].includes(prop(s, "device.api"));
            return cam ? "camera" : "screen";
        }
        if (sc === "Audio/Source" || sc === "Audio/Source/Virtual" || sc === "Audio/Duplex")
            return "mic";
        return ""; // sink monitor (desktop audio), unbound yet, stream -> stream
    }
    function entryFor(t: var, kind: string): var {
        const k = kinds[kind];
        return {
            "key": `${kind}:${t.id}`,
            "kind": kind,
            "app": Mixer.appName(t),
            "icon": Mixer.appIcon(t),
            "detail": k.detail,
            "glyph": k.glyph
        };
    }

    readonly property var live: {
        const out = [];
        const seen = {};
        for (const g of groups) {
            if (g.state !== PwLinkState.Active || g.source.isStream || ignored(g.target))
                continue;
            const kind = kindOf(g.target, g.source);
            if (kind === "")
                continue;
            const e = entryFor(g.target, kind);
            const id = `${e.app}|${kind}`;
            if (seen[id])
                continue;
            seen[id] = true;
            out.push(e);
        }
        if (casts > 0 && !out.some(e => e.kind === "screen"))
            out.push({
                "key": "screen:hyprland",
                "kind": "screen",
                "app": "Screen capture",
                "icon": "",
                "detail": castOwner === "1" ? "A window is being captured" : "The screen is being captured",
                "glyph": "screen-share"
            });
        return out;
    }

    // ---- Hyprland screencopy -----------------------------------------------------------------
    property int casts: 0
    property string castOwner: ""
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "screencast")
                return;
            const p = ev.data.split(",");
            root.casts = Math.max(0, root.casts + (p[0] === "1" ? 1 : -1));
            root.castOwner = p[1] ?? "";
        }
    }

    // ---- fake (tests, screenshots) -------------------------------------------------------------
    property string fakeSpec: Env.get("LUXSHELL_FAKE_PRIVACY")
    readonly property var fake: {
        if (fakeSpec.trim() === "")
            return null;
        const out = [];
        for (const part of fakeSpec.split(",")) {
            const p = part.split(":");
            const kind = (p[0] ?? "").trim();
            if (!kinds[kind])
                continue;
            const icon = (p[2] ?? "").trim();
            const entry = icon !== "" ? DesktopEntries.heuristicLookup(icon) : null;
            out.push({
                "key": `${kind}:fake${out.length}`,
                "kind": kind,
                "app": (p[1] ?? "").trim() || "App",
                "icon": icon !== "" ? Quickshell.iconPath(entry?.icon || icon, true) : "",
                "detail": kinds[kind].detail,
                "glyph": kinds[kind].glyph
            });
        }
        return out;
    }

    readonly property var entries: fake ?? live
    readonly property bool active: entries.length > 0
    readonly property bool mic: entries.some(e => e.kind === "mic")
    readonly property bool screen: entries.some(e => e.kind === "screen")
    readonly property bool camera: entries.some(e => e.kind === "camera")
    // glyphs of what is in use, in a fixed order (widget)
    readonly property var glyphs: ["screen", "camera", "mic"].filter(k => entries.some(e => e.kind === k)).map(k => kinds[k].glyph)

    IpcHandler {
        target: "privacy"

        function fake(spec: string): void {
            root.fakeSpec = spec;
        }
        function state(): string {
            return JSON.stringify({
                "active": root.active,
                "entries": root.entries,
                "casts": root.casts,
                "captures": root.captures.length,
                "groups": root.groups.map(g => ({
                            "source": g.source.name,
                            "target": g.target.name,
                            "state": PwLinkState.toString(g.state)
                        }))
            });
        }
        function dump(): string {
            return JSON.stringify(root.nodes.map(n => ({
                        "id": n.id,
                        "name": n.name,
                        "type": PwNodeType.toString(n.type),
                        "isStream": n.isStream,
                        "isSink": n.isSink,
                        "class": root.prop(n, "media.class"),
                        "app": root.prop(n, "application.name")
                    })));
        }
    }
}
