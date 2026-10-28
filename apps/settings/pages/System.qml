import QtQuick
import qs.config
import qs.services
import qs.apps.settings

// System: how luxshell shares the desktop, settings file, backup (export / import / reset all).
SettingsPage {
    id: page

    pageId: "system"
    title: "System"
    subtitle: "How luxshell shares the desktop, and your settings file."
    icon: 0xF0493
    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "wallpaperLayer",
                    "kind": "switch",
                    "key": "wallpaperLayer",
                    "label": "Paint the wallpaper (off: another shell draws it)",
                    "keywords": "background layer ambxst"
                }
            ]
        },
        {
            "title": "Files",
            "options": [
                {
                    "id": "settingsFile",
                    "kind": "button",
                    "label": "Settings",
                    "keywords": "config json file folder path",
                    "value": () => Settings.path.replace(Env.get("HOME"), "~"),
                    "action": "Open folder",
                    "run": () => Exec.run(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "sh", Env.configDir], "open settings folder")
                }
            ]
        },
        {
            "title": "Backup",
            "options": [
                {
                    "id": "backupFile",
                    "kind": "path",
                    "mode": "save",
                    "label": "Backup file",
                    "keywords": "export import json backup restore file",
                    "value": () => Backup.file,
                    "set": v => Backup.file = v,
                    "placeholder": "~/luxshell-settings.json"
                },
                {
                    "id": "backupExport",
                    "kind": "button",
                    "label": "Export settings",
                    "keywords": "backup save json file copy",
                    "value": () => Backup.exportStatus,
                    "action": "Export",
                    "enabled": () => !Backup.busy && Backup.file.trim() !== "",
                    "run": () => Backup.exportTo(Backup.file)
                },
                {
                    "id": "backupImport",
                    "kind": "button",
                    "label": "Import settings (replaces the current ones)",
                    "keywords": "backup restore load json file",
                    "value": () => Backup.importStatus,
                    "action": "Import",
                    "enabled": () => !Backup.busy && Backup.file.trim() !== "",
                    "run": () => Backup.importFrom(Backup.file)
                },
                {
                    "id": "resetAll",
                    "kind": "button",
                    "label": "Reset all settings",
                    "keywords": "defaults factory restore clear",
                    "value": () => {
                        const n = Catalog.changedCount();
                        return n === 0 ? "All default" : `${n} changed`;
                    },
                    "action": "Reset all",
                    "confirm": "Reset everything?",
                    "enabled": () => Catalog.changedCount() > 0,
                    "run": () => Catalog.resetAll()
                }
            ]
        }
    ]
}
