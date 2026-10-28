pragma Singleton
import QtQuick
import Quickshell
import qs.config

// Web search engines for the launcher's last row; the settings app picks one
// (Settings.searchEngine). url: %s = the URL-encoded query.
Singleton {
    id: root

    readonly property var list: [
        {
            "id": "duckduckgo",
            "name": "DuckDuckGo",
            "url": "https://duckduckgo.com/?q=%s"
        },
        {
            "id": "google",
            "name": "Google",
            "url": "https://www.google.com/search?q=%s"
        },
        {
            "id": "brave",
            "name": "Brave Search",
            "url": "https://search.brave.com/search?q=%s"
        },
        {
            "id": "startpage",
            "name": "Startpage",
            "url": "https://www.startpage.com/do/search?q=%s"
        },
        {
            "id": "kagi",
            "name": "Kagi",
            "url": "https://kagi.com/search?q=%s"
        },
        {
            "id": "ecosia",
            "name": "Ecosia",
            "url": "https://www.ecosia.org/search?q=%s"
        },
        {
            "id": "bing",
            "name": "Bing",
            "url": "https://www.bing.com/search?q=%s"
        }
    ]

    function byId(id: string): var {
        return list.find(e => e.id === id) ?? list[0];
    }

    readonly property var current: byId(Settings.searchEngine)
}
