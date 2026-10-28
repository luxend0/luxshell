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
import QtQuick
import Quickshell
import qs.core
import qs.island
import qs.background
import qs.apps.settings

ShellRoot {
    Variants {
        model: Quickshell.screens

        IslandWindow {}
    }

    Ipc {}

    // wallpaper surface (only with LUXSHELL_WALLPAPER=1 / Settings.wallpaperLayer), theme export
    WallpaperLayer {}

    // settings app window (apps/settings), created while open
    SettingsHost {}
}
