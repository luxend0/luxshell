-- Nested Hyprland fuer luxshell-Previews: ein 2560x1440 Headless-Output, kein Eingabegeraet noetig
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.monitor({ output = "HEADLESS-2", mode = "2560x1440@60", position = "5000x0", scale = 1 })
hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true }, decoration = { rounding = 12 } })
