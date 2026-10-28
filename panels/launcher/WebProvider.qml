import QtQuick
import Quickshell
import qs.config
import qs.services

// Last row of every non-empty search: open the query in the default browser.
// "?" forces the mode.
Provider {
    prefix: Settings.launcherPrefixes?.web ?? "?" // settings app, Launcher page
    label: "Web search"
    glyph: "globe"
    limit: 1
    inDefault: Settings.webResults // settings app, Launcher page

    property string engine: SearchEngines.current.name
    property string url: SearchEngines.current.url

    function match(query: string, exclusive: bool): var {
        const q = query.trim();
        if (q === "")
            return exclusive ? [hint("Search the web", `Type to search ${engine}`)] : [];
        return [
            {
                "key": "web",
                "title": q,
                "subtitle": `Search ${engine}`,
                "icon": "",
                "glyph": "globe",
                "run": () => Quickshell.execDetached(["xdg-open", url.replace("%s", encodeURIComponent(q))])
            }
        ];
    }
}
