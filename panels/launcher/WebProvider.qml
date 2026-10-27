import QtQuick
import Quickshell

// Last row of every non-empty search: open the query in the default browser.
// "?" forces the mode.
Provider {
    prefix: "?"
    label: "Web search"
    glyph: "globe"
    limit: 1

    property string engine: "DuckDuckGo"
    property string url: "https://duckduckgo.com/?q=%s"

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
