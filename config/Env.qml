pragma Singleton
import QtQuick
import Quickshell

// Process environment, read once. Everything that can be steered from outside
// (tests, sandbox, keybind wrappers) is collected here so no other file calls
// Quickshell.env() directly.
//
//   LUXSHELL_PREVIEW      collapsed | hover | <panel id>   forced state at start
//   LUXSHELL_NOTIFS=1     run the NotificationServer (off by default: Ambxst owns the bus name)
//   LUXSHELL_FAKE_NOTIFS  fake unread count while the server is off
//   LUXSHELL_CONFIG_DIR   settings directory (default $XDG_CONFIG_HOME/luxshell)
//   LUXSHELL_FAKE_CLOCK   ISO date/time shown instead of the real clock (screenshots)
//   LUXSHELL_SLOWMO       factor for every animation duration (10 = ten times slower, frame captures)
//   LUXSHELL_DRYRUN=1     system actions (Wi-Fi, Bluetooth, volume, brightness, lock) only log (services/Exec)
//   LUXSHELL_CC_PAGE      control center sheet shown on open: network | bluetooth | sound | display
//   LUXSHELL_FAKE_BT      1 = demo Bluetooth devices, scanning = demo that never finds a nearby device
//   LUXSHELL_FAKE_WIFI=1  demo Wi-Fi adapter + networks (services/Networks)
//   LUXSHELL_FAKE_MIXER=1 demo app playback streams (services/Mixer)
//   LUXSHELL_FAKE_MEDIA   1 = two demo players (Spotify playing, Firefox paused), single = one,
//                         paused = Spotify paused; no MPRIS at all (services/Media)
//   LUXSHELL_LOCK_TEST_PASSWORD  lock screen TEST MODE: the typed password is compared with
//                         this value instead of PAM. Honoured ONLY together with
//                         LUXSHELL_DRYRUN=1 (sandbox), ignored with a warning otherwise
//                         (services/Lock.qml)
//   LUXSHELL_SETTINGS_DEMO=1  settings app shows the "Option types" page (every option kind,
//                         apps/settings/pages/Demo.qml); hidden otherwise
//   LUXSHELL_INTEGRATION_ROOT  home directory the kitty / GTK integrations edit instead of $HOME
//                         (<root>/.config/kitty/kitty.conf, <root>/.config/gtk-{3,4}.0/gtk.css;
//                         services/AppThemes). With LUXSHELL_DRYRUN=1 they edit nothing unless it is set.
//   LUXSHELL_KEYS_FILE    where services/Keybinds writes the generated Hyprland binds (default
//                         $XDG_CONFIG_HOME/hypr/luxos/luxshell-keys.lua); with LUXSHELL_DRYRUN=1 the
//                         default path is never written, only a file named here
//   LUXSHELL_SOUND_TARGET PipeWire sink for the notification sound (pw-play --target); plays even
//                         with LUXSHELL_DRYRUN=1 (tests on a null sink), services/Notifs
//   LUXSHELL_FAKE_UPGRADES  power menu restart line (services/Power): a number = packages upgraded
//                         since boot, "kernel" = running kernel replaced on disk (screenshots)
//   LUXSHELL_FAKE_WEATHER  wttr.in answer "%x|%t|%C" (e.g. "m|+12°C|Partly cloudy") for the island's
//                         weather widget instead of asking the network (services/Weather)
//   LUXSHELL_SYSTEM_FILE  where services/HyprSystem writes the generated Hyprland system settings
//                         (default $XDG_CONFIG_HOME/hypr/luxos/luxshell-system.lua); with LUXSHELL_DRYRUN=1
//                         the default path is never written, only a file named here. Sandbox: ALWAYS
//                         set it to a file in the scratchpad
//   LUXSHELL_HYPR_LIVE=1  with LUXSHELL_DRYRUN=1: Exec.hyprEval still runs `hyprctl eval` (the compositor
//                         qs runs in, i.e. the nested Hyprland of the sandbox) instead of only logging.
//                         Sandbox tests of live Hyprland changes only, never on the real desktop
//   LUXSHELL_FAKE_DEVICES=1  demo mice / touchpad / keyboards for Settings > Input (services/HyprSystem)
//   LUXSHELL_FAKE_UPDATES  "12" or "12+3" (repo + AUR) pending updates for the island's updates widget
//                         instead of running checkupdates / paru (services/Updates)
//   LUXSHELL_FAKE_PRIVACY  "mic:Discord:discord,screen:OBS Studio:com.obsproject.Studio" (kind:app:icon)
//                         replaces the live privacy list (services/Privacy; also ipc call privacy fake)
//   LUXSHELL_FAKE_SWITCHES=1  bar switches with demo state (screenshots, with LUXSHELL_DRYRUN): night
//                         light available, all three power profiles, and clicks change only that
//                         state, caffeine included (services/NightLight, PowerProfile, Caffeine)
//   LUXSHELL_FAKE_MONITORS  file with a `hyprctl monitors all -j` dump: Settings > Displays shows these
//                         displays instead of the live ones (sandbox shots of a real monitor); changes
//                         still go to the compositor qs runs in (apps/settings/pages/SysDisplays.qml)
//   LUXSHELL_IDLE_SCALE   factor for every idle timeout of services/Idle (Settings.idle*After); 0.02 turns
//                         150 / 300 / 330 / 1800 s into 3 / 6 / 6.6 / 36 s (sandbox tests). Dim, lock, screen
//                         off and suspend still go through Exec: with LUXSHELL_DRYRUN=1 they only log
//   LUXSHELL_IDLE_LOGIND_BUS=session  services/Idle listens for logind (PrepareForSleep, Session.Lock) on the
//                         session bus instead of the system bus: sandbox with LUXSB_DBUS=1 and a fake
//                         org.freedesktop.login1 there (the real signals cannot be sent without sleeping / locking)
//   LUXSHELL_POLKIT=1     register luxshell as the polkit authentication agent (services/Polkit, prompt
//                         panels/PolkitPrompt). Off by default: one agent per session; a sandbox sets it
//                         only for a registration test (it takes the requests of the real session)
//   LUXSHELL_FAKE_POLKIT  1 = `ipc call polkit fake <kind>` shows demo requests (single | multi | service |
//                         long, password "test"; no polkit, no PAM); a kind as the value also starts one at start
Singleton {
    id: root

    function get(name: string): string {
        const v = Quickshell.env(name);
        return v === undefined || v === null ? "" : String(v);
    }

    readonly property string preview: get("LUXSHELL_PREVIEW")
    readonly property bool notifs: get("LUXSHELL_NOTIFS") === "1"
    readonly property int fakeNotifs: parseInt(get("LUXSHELL_FAKE_NOTIFS")) || 0
    readonly property string fakeClock: get("LUXSHELL_FAKE_CLOCK")
    readonly property string fakeMedia: get("LUXSHELL_FAKE_MEDIA")
    readonly property real slowmo: Math.max(0.1, parseFloat(get("LUXSHELL_SLOWMO")) || 1)
    readonly property string lockTestPassword: get("LUXSHELL_LOCK_TEST_PASSWORD")
    readonly property bool settingsDemo: get("LUXSHELL_SETTINGS_DEMO") === "1"
    readonly property string integrationRoot: get("LUXSHELL_INTEGRATION_ROOT")
    readonly property string fakeWeather: get("LUXSHELL_FAKE_WEATHER")
    readonly property bool polkit: get("LUXSHELL_POLKIT") === "1"
    readonly property string fakePolkit: get("LUXSHELL_FAKE_POLKIT")
    readonly property string configDir: {
        const own = get("LUXSHELL_CONFIG_DIR");
        if (own !== "")
            return own;
        const xdg = get("XDG_CONFIG_HOME");
        return (xdg !== "" ? xdg : get("HOME") + "/.config") + "/luxshell";
    }
}
