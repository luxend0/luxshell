import QtQuick
import qs.services

// Desktop entries, ranked by fuzzy quality + usage (Apps.rank: fuzzy.js + AppUsage).
Provider {
    label: "Apps"
    glyph: "search"

    function match(query: string, exclusive: bool): var {
        return Apps.rank(query).slice(0, limit).map(e => ({
                    "key": "app:" + e.id,
                    "title": e.name,
                    "subtitle": Apps.subtitle(e),
                    "icon": Apps.iconSource(e),
                    "glyph": "app-window",
                    "run": () => Apps.launch(e, query)
                }));
    }
}
