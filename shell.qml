//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
//@ pragma IconTheme Papirus-Dark
// luxshell - island core (candidate C: architecture first)
//
//   config/    Theme (roles, geometry), Motion (island morph timing), Themes (palette data), Settings, Env
//   core/      Ui (central state + priorities), Panels (registry), Ipc (target "luxshell")
//   services/  Hypr, Clock, Net, Audio, Notifs, Apps, Tray - singletons, read only except explicit actions
//   island/    IslandWindow (layer surface) > Island (morph container) > BarContent | PanelHost
//   panels/    PanelBase contract + one file per panel
//   background/ WallpaperLayer (background layer surface per screen, opt-in)
//   widgets/   Icon/Icons (Lucide), Txt, MorphText, IconButton, Anim
//   lock/      LockScreen (WlSessionLock) > LockSurface per screen; state + PAM in services/Lock
import QtQuick
import Quickshell
import qs.core
import qs.island
import qs.background
import qs.lock
import qs.apps.settings
import qs.services

ShellRoot {
    // opt-in integrations (Settings > Integrations: kitty/GTK include lines, Hyprland look + blur) start with the shell
    readonly property var integrations: [AppThemes, HyprLook]
    // singletons that act on their own from the start: keybind file (services/Keybinds), focus schedule (services/Focus)
    readonly property var behaviour: [Keybinds.enabled, Focus.enabled]
    // Hyprland values of Settings > System (services/HyprSystem): read at start, put back what Hyprland lacks, IPC "system"
    readonly property var system: [HyprSystem.ready]
    // idle daemon (services/Idle): dim, lock, screen off, sleep; lock before sleep; IPC "idle"
    readonly property var idle: [Idle.enabled]
    // polkit agent (only with LUXSHELL_POLKIT=1) + IPC "polkit", services/Polkit
    readonly property var polkit: [Polkit.enabled]

    Variants {
        model: Quickshell.screens

        IslandWindow {}
    }

    Ipc {}

    // wallpaper surface (only with LUXSHELL_WALLPAPER=1 / Settings.wallpaperLayer), theme export
    WallpaperLayer {}

    // session lock (ipc call luxshell lock), one surface per screen
    LockScreen {}
    // settings app window (apps/settings), created while open
    SettingsHost {}
}
