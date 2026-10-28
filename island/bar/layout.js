.pragma library

// Island layout engine: pure functions over Settings.islandLayout, no QML. BarRegistry.qml
// supplies the environment (widths, gaps, presence, measures); BarContent.qml and the
// settings editor (apps/settings/island) consume the plans.
//
// layout = {
//   collapsed: { left: [ids], center: [ids], right: [ids] },
//   hover: { top: { left, center, right }, bottom: { left, center, right } }
// }
// A slot is laid out as a chain: left slots start at padLeft, right slots end at
// width - padRight, centre slots are centred on the island. Hover with only one row in
// use collapses to that row; with two rows a column whose other row is empty is centred
// between them (the clock + date of ref/02).

var COLS = ["left", "center", "right"];

function rowsOf(layout, state) {
    if (state === "collapsed")
        return [{
            "row": "",
            "lists": layout.collapsed
        }];
    return [{
        "row": "top",
        "lists": layout.hover.top
    }, {
        "row": "bottom",
        "lists": layout.hover.bottom
    }];
}

function listAt(layout, state, row, col) {
    if (state === "collapsed")
        return layout.collapsed[col] || [];
    return (layout.hover[row] || {})[col] || [];
}

// every slot of a state: [{ row, col }]
function slots(state) {
    var out = [];
    var rows = state === "collapsed" ? [""] : ["top", "bottom"];
    for (var r = 0; r < rows.length; r++)
        for (var c = 0; c < COLS.length; c++)
            out.push({
                "row": rows[r],
                "col": COLS[c]
            });
    return out;
}

function align(col) {
    return col === "left" ? "l" : col === "right" ? "r" : "c";
}

// rows of the hover island that hold anything that can show (battery-less desktop: the
// battery never shows and does not keep a row open)
function rowsUsed(layout, state, env) {
    var rows = rowsOf(layout, state);
    var used = [];
    for (var i = 0; i < rows.length; i++) {
        var any = false;
        for (var c = 0; c < COLS.length; c++) {
            var ids = rows[i].lists[COLS[c]] || [];
            for (var k = 0; k < ids.length; k++)
                if (env.available(ids[k]))
                    any = true;
        }
        if (any)
            used.push(rows[i].row);
    }
    return used;
}

function hasAny(ids, env) {
    for (var k = 0; k < (ids || []).length; k++)
        if (env.available(ids[k]))
            return true;
    return false;
}

// vertical centre line of every row (and of spanning columns)
function rowY(layout, state, env, row, col) {
    var m = env.m(state);
    if (state === "collapsed")
        return m.centerY;
    var used = rowsUsed(layout, state, env);
    if (used.length < 2)
        return m.oneRowY;
    var other = row === "top" ? "bottom" : "top";
    if (hasAny(listAt(layout, state, row, col), env) && !hasAny(listAt(layout, state, other, col), env))
        return m.spanY;
    return row === "top" ? m.row1Y : m.row2Y;
}

// width a slot reserves for the island width (stable measures, not live text). The window
// title yields to the media chip in the same slot (video): the pair reserves the wider one.
function slotReserve(ids, state, env) {
    ids = ids || [];
    var pair = env.yieldOn && ids.indexOf("media") >= 0 && ids.indexOf("window") >= 0;
    var total = 0, prev = null;
    for (var k = 0; k < ids.length; k++) {
        var id = ids[k];
        if (!env.available(id))
            continue;
        var r;
        if (pair && id === "media")
            continue;
        if (pair && id === "window")
            r = Math.max(env.reserve("window", state), env.reserve("media", state));
        else if (id === "media" && !env.mediaPresent)
            continue;
        else
            r = env.reserve(id, state);
        if (r <= 0)
            continue;
        if (prev !== null)
            total += env.gap(prev, id, state);
        total += r;
        prev = id;
    }
    return total;
}

// content width of a state: pads + both sides as wide as the wider one (the centre column
// stays centred) + centre column
function core(layout, state, env) {
    var rows = rowsOf(layout, state);
    var L = 0, R = 0, C = 0;
    for (var i = 0; i < rows.length; i++) {
        L = Math.max(L, slotReserve(rows[i].lists.left, state, env));
        R = Math.max(R, slotReserve(rows[i].lists.right, state, env));
        C = Math.max(C, slotReserve(rows[i].lists.center, state, env));
    }
    var m = env.m(state);
    return m.padLeft + m.padRight + 2 * Math.max(L, R) + C;
}

// One state laid out with live widths. Returns
//   items: { key: { id, key, x, w, y, row, col, idx, align, before, after, lead, trail, rel,
//          prev, next } }  (present items only; key = id, spacers "spacer@row.col.idx";
//          before/after: slot content left/right of it; lead/trail: gap to prev/next non-spacer;
//          rel: anchor (left edge / centre / right edge by column) relative to the island centre)
//   slots: [{ row, col, y, x0, x1, keys }]
function plan(layout, state, env, W) {
    var m = env.m(state);
    var res = {
        "state": state,
        "width": W,
        "items": {},
        "slots": []
    };
    var rows = rowsOf(layout, state);
    for (var i = 0; i < rows.length; i++) {
        for (var c = 0; c < COLS.length; c++) {
            var col = COLS[c];
            var row = rows[i].row;
            var ids = rows[i].lists[col] || [];
            var y = rowY(layout, state, env, row, col);
            // chain of present entries
            var chain = [], x = 0, prev = null;
            for (var k = 0; k < ids.length; k++) {
                var id = ids[k];
                if (!env.present(id, ids, state))
                    continue;
                var key = id === "spacer" ? "spacer@" + row + "." + col + "." + k : id;
                var w = env.width(id, state);
                if (prev !== null)
                    x += env.gap(prev, id, state);
                chain.push({
                    "id": id,
                    "key": key,
                    "x": x,
                    "w": w,
                    "idx": k
                });
                x += w;
                prev = id;
            }
            var total = x;
            var x0 = col === "left" ? m.padLeft : col === "right" ? W - m.padRight - total : W / 2 - total / 2;
            // exact sums around every entry (summed outward from the entry, like the video's
            // hand-placed formulas, so the default layout lands on the same floats)
            for (var e = 0; e < chain.length; e++) {
                var after = 0;
                for (var a2 = e + 1; a2 < chain.length; a2++)
                    after += env.gap(chain[a2 - 1].id, chain[a2].id, state) + chain[a2].w;
                chain[e].after = after;
                // gap (+ spacers) to the nearest non-spacer neighbour on each side
                var lead = 0, trail = 0;
                for (var p2 = e - 1; p2 >= 0; p2--) {
                    lead += env.gap(chain[p2].id, chain[p2 + 1].id, state);
                    if (chain[p2].id !== "spacer")
                        break;
                    lead += chain[p2].w;
                }
                for (var n2 = e + 1; n2 < chain.length; n2++) {
                    trail += env.gap(chain[n2 - 1].id, chain[n2].id, state);
                    if (chain[n2].id !== "spacer")
                        break;
                    trail += chain[n2].w;
                }
                chain[e].lead = lead;
                chain[e].trail = trail;
            }
            var keys = [];
            for (var e2 = 0; e2 < chain.length; e2++) {
                var it = chain[e2];
                var pk = null, nk = null;
                for (var p = e2 - 1; p >= 0 && pk === null; p--)
                    if (chain[p].id !== "spacer")
                        pk = chain[p].key;
                for (var n = e2 + 1; n < chain.length && nk === null; n++)
                    if (chain[n].id !== "spacer")
                        nk = chain[n].key;
                // anchor relative to the island centre: left edge / centre / right edge
                var rel = col === "left" ? m.padLeft + it.x - W / 2 : col === "right" ? W / 2 - m.padRight - it.after : (it.x - it.after) / 2;
                res.items[it.key] = {
                    "id": it.id,
                    "key": it.key,
                    "x": x0 + it.x,
                    "w": it.w,
                    "y": y + env.dy(it.id, state),
                    "row": row,
                    "col": col,
                    "idx": it.idx,
                    "pos": e2,
                    "count": chain.length,
                    "align": align(col),
                    "before": it.x,
                    "after": it.after,
                    "lead": it.lead,
                    "trail": it.trail,
                    "rel": rel,
                    "prev": pk,
                    "next": nk
                };
                keys.push(it.key);
            }
            res.slots.push({
                "row": row,
                "col": col,
                "y": y,
                "x0": x0,
                "x1": x0 + total,
                "keys": keys
            });
        }
    }
    return res;
}

// ---- edits (all return a new layout, the input stays untouched) ------------------------------
function clone(layout) {
    return JSON.parse(JSON.stringify(layout));
}

function setList(layout, state, row, col, ids) {
    var out = clone(layout);
    if (state === "collapsed")
        out.collapsed[col] = ids.slice();
    else
        out.hover[row][col] = ids.slice();
    return out;
}

// where id sits in a state: { row, col, idx } or null
function find(layout, state, id) {
    var ss = slots(state);
    for (var i = 0; i < ss.length; i++) {
        var ids = listAt(layout, state, ss[i].row, ss[i].col);
        var k = ids.indexOf(id);
        if (k >= 0)
            return {
                "row": ss[i].row,
                "col": ss[i].col,
                "idx": k
            };
    }
    return null;
}

function contains(layout, state, id) {
    return find(layout, state, id) !== null;
}

// remove the entry at { row, col, idx }
function removeAt(layout, state, at) {
    var ids = listAt(layout, state, at.row, at.col).slice();
    ids.splice(at.idx, 1);
    return setList(layout, state, at.row, at.col, ids);
}

// remove every occurrence of id in a state (spacers: use removeAt)
function removeId(layout, state, id) {
    var out = clone(layout);
    var ss = slots(state);
    for (var i = 0; i < ss.length; i++) {
        var ids = listAt(out, state, ss[i].row, ss[i].col).filter(function (x) {
            return x !== id;
        });
        out = setList(out, state, ss[i].row, ss[i].col, ids);
    }
    return out;
}

function insertAt(layout, state, row, col, idx, id) {
    var ids = listAt(layout, state, row, col).slice();
    ids.splice(Math.max(0, Math.min(ids.length, idx)), 0, id);
    return setList(layout, state, row, col, ids);
}

// valid layout from anything (file edits, imports): known slots, known ids, every id at
// most once per state (spacer may repeat), only in states it allows
function normalize(obj, known, allowed, fallback) {
    var out = {
        "collapsed": {
            "left": [],
            "center": [],
            "right": []
        },
        "hover": {
            "top": {
                "left": [],
                "center": [],
                "right": []
            },
            "bottom": {
                "left": [],
                "center": [],
                "right": []
            }
        }
    };
    if (!obj || typeof obj !== "object" || !obj.collapsed || !obj.hover)
        return clone(fallback);
    var states = ["collapsed", "hover"];
    for (var s = 0; s < states.length; s++) {
        var state = states[s];
        var seen = {};
        var ss = slots(state);
        for (var i = 0; i < ss.length; i++) {
            var src = state === "collapsed" ? obj.collapsed[ss[i].col] : (obj.hover[ss[i].row] || {})[ss[i].col];
            var list = [];
            if (src && typeof src.length === "number")
                for (var k = 0; k < src.length; k++) {
                    var id = String(src[k]);
                    if (known.indexOf(id) < 0 || !allowed(id, state))
                        continue;
                    if (id !== "spacer" && seen[id])
                        continue;
                    seen[id] = true;
                    list.push(id);
                }
            if (state === "collapsed")
                out.collapsed[ss[i].col] = list;
            else
                out.hover[ss[i].row][ss[i].col] = list;
        }
    }
    return out;
}
