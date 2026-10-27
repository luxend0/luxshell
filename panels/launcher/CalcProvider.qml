import QtQuick
import Quickshell
import qs.services

// "12*7" -> first row "84", Enter copies the result (wl-copy). "=" forces the mode.
Provider {
    prefix: "="
    label: "Calculator"
    glyph: "calculator"
    limit: 1

    function match(query: string, exclusive: bool): var {
        const q = query.trim();
        if (!exclusive && !Calc.isMath(q))
            return [];
        const value = Calc.format(Calc.evaluate(q));
        if (value === "")
            return exclusive ? [q === "" ? hint("Type an expression", "12*7, sqrt(2), 2^10, 5!") : hint(q, "Not a complete expression")] : [];
        return [
            {
                "key": "calc",
                "title": value,
                "subtitle": q + "  ·  Enter to copy",
                "icon": "",
                "glyph": "calculator",
                "run": () => Quickshell.execDetached(["wl-copy", "--", value])
            }
        ];
    }
}
