import QtQuick

// One launcher mode. The launcher asks every provider for entries and shows them
// in its single list, in provider order; a new mode = a new file with match().
//
//   prefix     non-empty: text starting with it switches the field to this
//              provider alone (prefix stripped before match())
//   inDefault  also answers the normal search (no prefix)
//
// match(query, exclusive) returns entries, plain JS objects:
//   { key, title, subtitle, icon, glyph, run, keepOpen }
//   key       stable id; keeps the selection when data changes under an
//             unchanged query (window title updates, entries still loading)
//   icon      image URL (Apps.entryIcon / Apps.iconFor) or ""; glyph is the
//             Lucide fallback shown in the tile (Glyph.qml)
//   run       function, or null for a hint row (shown, never selected)
//   keepOpen  true: the launcher stays open after run()
QtObject {
    property string prefix: ""
    property bool inDefault: true
    property string label: ""          // dim mode name at the right of the field
    property string glyph: "search"    // replaces the lens while the mode is active
    property int limit: 50

    function match(query: string, exclusive: bool): var {
        return [];
    }

    // launcher opened (refresh caches, ask the compositor ...)
    function opened(): void {
    }

    function hint(title: string, subtitle: string): var {
        return {
            "title": title,
            "subtitle": subtitle,
            "icon": "",
            "glyph": glyph,
            "run": null
        };
    }
}
