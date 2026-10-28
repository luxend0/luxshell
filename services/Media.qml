pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.config

// Media players (MPRIS) for the hover chip (island/bar/MediaLabel) and the media panel
// (panels/MediaPanel). Reading is passive; every control goes through Exec (dry run
// logs), except the sandbox test player (tools/mpris-test-player.py, bus name
// org.mpris.MediaPlayer2.luxshelltest*), which only exists on a sandbox's private bus.
//
// active: the player the island shows. A player the user picked (select / cycle) stays
// until another one starts playing; otherwise the playing one (the one that started last),
// else the last one that played, else the first with a track.
// playerctld (a proxy that mirrors another player) is skipped.
//
// position is not reactive in Quickshell (it is extrapolated on read): while someone
// shows it (watch(true)), a timer re-emits positionChanged twice a second.
//
// LUXSHELL_FAKE_MEDIA: demo players that react locally, no D-Bus at all (Env.fakeMedia).
Singleton {
    id: root

    readonly property string fakeMode: Env.fakeMedia
    readonly property bool fake: fakeMode !== "" && fakeMode !== "0"

    // MPRIS is first touched once the event loop runs: its D-Bus setup during shell start let
    // queued work (theme load) reach panel probes the registry had already destroyed
    property bool started: false
    Component.onCompleted: Qt.callLater(() => root.started = true)

    readonly property var players: fake ? fakePlayers.filter(p => p.present) : !started ? [] : Mpris.players.values.filter(p => p.dbusName !== "org.mpris.MediaPlayer2.playerctld")

    property var pinned: null
    property var recent: null

    readonly property var active: {
        const ps = players;
        if (pinned && ps.includes(pinned))
            return pinned;
        const playing = ps.filter(p => p.isPlaying);
        if (playing.length > 0)
            return recent && playing.includes(recent) ? recent : playing[0];
        if (recent && ps.includes(recent))
            return recent;
        return ps.find(p => (p.trackTitle ?? "") !== "") ?? ps[0] ?? null;
    }

    // a player that starts playing becomes `recent` and ends a pick of another player
    Instantiator {
        model: root.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() {
                if (!modelData.isPlaying)
                    return;
                root.recent = modelData;
                if (root.pinned && root.pinned !== modelData)
                    root.pinned = null;
            }
            Component.onCompleted: if (modelData.isPlaying && !root.recent)
                root.recent = modelData
        }
    }

    // the island shows media only for a player with a track
    readonly property bool hasTrack: !!active && (active.trackTitle ?? "") !== ""
    readonly property bool playing: active?.isPlaying ?? false

    // ---- display helpers ----------------------------------------------------
    function title(p: var): string {
        return p?.trackTitle || "Unknown title";
    }
    function artist(p: var): string {
        return p?.trackArtist || "";
    }
    function album(p: var): string {
        return p?.trackAlbum || "";
    }
    function name(p: var): string {
        if (!p)
            return "";
        const entry = p.desktopEntry ? DesktopEntries.byId(p.desktopEntry) ?? DesktopEntries.heuristicLookup(p.desktopEntry) : null;
        return entry?.name || p.identity || "Player";
    }
    function icon(p: var): string {
        if (!p)
            return "";
        for (const id of [p.desktopEntry, p.identity]) {
            if (!id)
                continue;
            const entry = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
            const path = Quickshell.iconPath(entry?.icon || String(id).toLowerCase(), true);
            if (path !== "")
                return path;
        }
        return "";
    }
    // old Spotify builds hand out open.spotify.com/image/<id>, which redirects
    function art(p: var): string {
        const u = String(p?.trackArtUrl ?? "");
        return u.replace("https://open.spotify.com/image/", "https://i.scdn.co/image/");
    }
    function time(s: real): string {
        if (!(s >= 0) || !isFinite(s))
            return "0:00";
        const t = Math.floor(s);
        const h = Math.floor(t / 3600);
        const m = Math.floor(t / 60) % 60;
        const ss = String(t % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${ss}` : `${m}:${ss}`;
    }

    // ---- controls -----------------------------------------------------------
    function allowed(p: var, what: string): bool {
        if (!p)
            return false;
        if (p.fakePlayer || String(p.dbusName ?? "").startsWith("org.mpris.MediaPlayer2.luxshelltest"))
            return true;
        return Exec.allow(`media ${p.identity}: ${what}`);
    }
    function toggle(p: var): void {
        p = p ?? active;
        if (p?.canTogglePlaying && allowed(p, p.isPlaying ? "pause" : "play"))
            p.togglePlaying();
    }
    function next(p: var): void {
        p = p ?? active;
        if (p?.canGoNext && allowed(p, "next"))
            p.next();
    }
    function previous(p: var): void {
        p = p ?? active;
        if (p?.canGoPrevious && allowed(p, "previous"))
            p.previous();
    }
    function canSeek(p: var): bool {
        return !!p && p.canSeek && p.positionSupported && p.length > 0;
    }
    function seekTo(p: var, s: real): void {
        p = p ?? active;
        if (!canSeek(p))
            return;
        const to = Math.max(0, Math.min(p.length - 0.5, s));
        if (allowed(p, `seek ${time(to)}`))
            p.position = to;
    }
    function seekBy(p: var, d: real): void {
        p = p ?? active;
        if (p)
            seekTo(p, p.position + d);
    }
    function canVolume(p: var): bool {
        return !!p && p.volumeSupported && p.canControl;
    }
    function setVolume(p: var, v: real): void {
        p = p ?? active;
        if (!canVolume(p))
            return;
        const to = Math.max(0, Math.min(1, v));
        if (allowed(p, `volume ${Math.round(to * 100)} %`))
            p.volume = to;
    }
    // bring the player's window to the front
    function raise(p: var): void {
        p = p ?? active;
        if (p?.canRaise && allowed(p, "raise"))
            p.raise();
    }
    // luxshell-local choice, not a player action
    function select(p: var): void {
        if (p && players.includes(p))
            pinned = p;
    }
    function cycle(d: int): void {
        const ps = players;
        if (ps.length < 2)
            return;
        const i = Math.max(0, ps.indexOf(active));
        pinned = ps[(i + d + ps.length) % ps.length];
    }

    // ---- position ticker ----------------------------------------------------
    property int watchers: 0
    function watch(on: bool): void {
        watchers = Math.max(0, watchers + (on ? 1 : -1));
    }
    Timer {
        running: root.watchers > 0 && root.playing
        repeat: true
        interval: 500
        onTriggered: {
            if (root.fake)
                return;
            for (const p of root.players)
                if (p.isPlaying)
                    p.positionChanged();
        }
    }

    // ---- demo players (LUXSHELL_FAKE_MEDIA) -----------------------------------
    // covers as SVG data URLs, so the demo needs no files
    function cover(a: string, b: string, c: string, shape: string): string {
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient></defs><rect width="600" height="600" fill="url(#g)"/>${shape.replace(/C/g, c)}</svg>`;
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
    }

    component FakePlayer: QtObject {
        id: fp
        readonly property bool fakePlayer: true
        property bool present: true
        property string identity
        property string desktopEntry
        property string dbusName
        property var tracks: []
        property int index: 0
        readonly property var track: tracks[index] ?? ({})
        readonly property string trackTitle: track.title ?? ""
        readonly property string trackArtist: track.artist ?? ""
        readonly property string trackAlbum: track.album ?? ""
        readonly property string trackArtUrl: track.art ?? ""
        readonly property real length: track.length ?? 0
        property real position: 0
        property bool isPlaying: false
        property real volume: 0.7
        property bool volumeSupported: true
        readonly property bool canControl: true
        readonly property bool canTogglePlaying: true
        readonly property bool canGoNext: true
        readonly property bool canGoPrevious: true
        readonly property bool canSeek: true
        readonly property bool positionSupported: true
        readonly property bool canRaise: true
        function raise() {
            console.info(`luxshell[fake media]: raise ${identity}`);
        }
        function togglePlaying() {
            isPlaying = !isPlaying;
        }
        function next() {
            index = (index + 1) % tracks.length;
            position = 0;
        }
        function previous() {
            if (position > 3)
                position = 0;
            else {
                index = (index + tracks.length - 1) % tracks.length;
                position = 0;
            }
        }
    }

    readonly property list<QtObject> fakePlayers: [
        FakePlayer {
            identity: "Spotify"
            desktopEntry: "spotify"
            dbusName: "org.mpris.MediaPlayer2.spotify"
            isPlaying: root.fakeMode !== "paused"
            position: 83
            volume: 0.72
            tracks: [
                {
                    "title": "Glass Horizon",
                    "artist": "Nightcall Avenue",
                    "album": "Polar Lights",
                    "length": 224,
                    "art": root.cover("#f08a4b", "#5a1d63", "#ffd59a", '<circle cx="390" cy="220" r="130" fill="C" opacity=".9"/><rect y="400" width="600" height="200" fill="#1b0b24" opacity=".55"/>')
                },
                {
                    "title": "Static Bloom",
                    "artist": "Mara Velde",
                    "album": "Low Orbit",
                    "length": 198,
                    "art": root.cover("#2f6f8f", "#0b1a2a", "#9fe3f0", '<circle cx="300" cy="300" r="190" fill="none" stroke="C" stroke-width="22" opacity=".8"/><circle cx="300" cy="300" r="70" fill="C" opacity=".85"/>')
                },
                {
                    "title": "Paper Satellites (Extended Night Drive Version)",
                    "artist": "The Quiet Engines",
                    "album": "Signals",
                    "length": 412,
                    "art": root.cover("#d8d8d8", "#3a3a3a", "#111111", '<rect x="120" y="120" width="360" height="360" fill="none" stroke="C" stroke-width="16"/><path d="M120 480 L480 120" stroke="C" stroke-width="16"/>')
                }
            ]
        },
        FakePlayer {
            present: root.fakeMode !== "single" && root.fakeMode !== "paused"
            identity: "Mozilla Firefox"
            desktopEntry: "firefox"
            dbusName: "org.mpris.MediaPlayer2.firefox.instance_1_42"
            isPlaying: false
            position: 1312
            volumeSupported: false
            tracks: [
                {
                    "title": "Live at the Lighthouse - Full Set",
                    "artist": "Kiko Lane",
                    "album": "",
                    "length": 3725,
                    "art": root.cover("#3d4a3a", "#0e120d", "#c9d6a3", '<path d="M0 420 Q150 330 300 420 T600 420 V600 H0Z" fill="C" opacity=".5"/><circle cx="450" cy="160" r="60" fill="C" opacity=".8"/>')
                }
            ]
        }
    ]

    Timer {
        running: root.fake
        repeat: true
        interval: 1000
        onTriggered: {
            for (const p of root.fakePlayers) {
                if (!p.isPlaying)
                    continue;
                if (p.position + 1 >= p.length)
                    p.next();
                else
                    p.position += 1;
            }
        }
    }
}
