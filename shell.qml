//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
// luxshell - island core (candidate C: architecture first)
//
//   config/    Theme (roles, geometry, motion), Themes (palette data), Settings (persisted), Env
//   core/      Ui (central state + priorities), Panels (registry), Ipc (target "luxshell")
//   services/  Hypr, Clock, Net, Audio, Notifs, Apps, Tray - singletons, read only except explicit actions
//   island/    IslandWindow (layer surface) > Island (morph container) > BarContent | PanelHost
//   panels/    PanelBase contract + one file per panel
//   widgets/   Icon/Icons (Lucide), Txt, MorphText, IconButton, Anim
import QtQuick
import Quickshell
import qs.core
import qs.island

ShellRoot {
    Variants {
        model: Quickshell.screens

        IslandWindow {}
    }

    Ipc {}
}
