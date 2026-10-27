.pragma library

// Launcher matching. Pure functions, no QML: index() turns a DesktopEntry into
// lower-cased fields with word-boundary masks once, quality() rates a query
// against such a record in [0, 1] (0 = no match).
//
// Tiers per field (higher wins):  exact 1.0 | prefix .92-.98 | word prefix .82-.88
//   | inner substring .62-.68 (3+ chars) | fuzzy subsequence .30-.58 (2+ chars, scored like fzf:
//   boundary and consecutive bonuses, gap penalty, scattered matches rejected)
// Field weights: name 1, exec/id .88, generic name .8, keywords .75, comment .5 (substring only).

const W_NAME = 1.0;
const W_EXEC = 0.88;
const W_GENERIC = 0.8;
const W_KEYWORDS = 0.75;
const W_COMMENT = 0.5;

function norm(s) {
    let out = String(s ?? "").toLowerCase();
    try {
        out = out.normalize("NFD").replace(/[̀-ͯ]/g, "");
    } catch (e) {}
    return out;
}

function isAlnum(c) {
    return c.toUpperCase() !== c.toLowerCase() || (c >= "0" && c <= "9");
}

function isLower(c) {
    return c >= "a" && c <= "z";
}

// field = { s: lower-cased text, b: boundary flag per char }
function field(text) {
    const raw = String(text ?? "");
    const s = norm(raw);
    const b = new Array(s.length);
    for (let i = 0; i < s.length; i++) {
        if (i === 0) {
            b[i] = true;
            continue;
        }
        const prev = s[i - 1], cur = s[i];
        // separator before, camelCase hump (only if lengths still line up), letter->digit
        b[i] = (!isAlnum(prev) && isAlnum(cur)) || (raw.length === s.length && raw[i] !== cur && raw[i - 1] === prev && isLower(prev)) || (isLower(prev) && cur >= "0" && cur <= "9");
    }
    return {
        s: s,
        b: b
    };
}

function base(path) {
    const p = String(path ?? "");
    return p.slice(p.lastIndexOf("/") + 1);
}

// executable name, unwrapping env / flatpak, plus the last part of a reverse-DNS id
function execWords(entry) {
    const cmd = [];
    const list = entry.command ?? [];
    for (let i = 0; i < list.length; i++)
        cmd.push(String(list[i]));
    let i = 0;
    while (i < cmd.length && (base(cmd[i]) === "env" || /^[A-Za-z_][A-Za-z0-9_]*=/.test(cmd[i]) || cmd[i].startsWith("-")))
        i++;
    let exe = base(cmd[i] ?? "");
    if (exe === "flatpak") {
        const c = cmd.find(a => a.startsWith("--command="));
        exe = c ? base(c.slice(10)) : String(cmd[cmd.length - 1] ?? "").split(".").pop();
    }
    const id = String(entry.id ?? "").replace(/\.desktop$/, "");
    const tail = id.split(".").pop();
    const words = [exe];
    if (tail && norm(tail) !== norm(exe))
        words.push(tail);
    return words.join(" ");
}

function index(entry) {
    const name = String(entry.name ?? "");
    const generic = String(entry.genericName ?? "");
    const comment = String(entry.comment ?? "");
    const kw = [];
    const list = entry.keywords ?? [];
    for (let i = 0; i < list.length; i++)
        kw.push(String(list[i]));
    return {
        entry: entry,
        id: String(entry.id ?? ""),
        name: name,
        fName: field(name),
        fExec: field(execWords(entry)),
        fGeneric: field(generic),
        fKeywords: field(kw.join(" ")),
        fComment: field(comment)
    };
}

// optimal subsequence alignment (linear gap penalty), raw score or 0. A gap may cross
// into another word only if the next match is a word start ("vsc" -> Visual Studio Code),
// otherwise it has to stay inside the current word ("chrm" -> Chromium, not "fiR" in
// "File manageR").
function subsequence(t, f) {
    const s = f.s, b = f.b, n = s.length, m = t.length;
    // cheap rejection first: most records fail here
    let k = 0;
    for (let j = 0; j < n && k < m; j++)
        if (s[j] === t[k])
            k++;
    if (k < m)
        return 0;

    const GAP = 0.15, CONSEC = 1.5, NEG = -1e9;
    let prev = new Array(n).fill(NEG);
    for (let j = 0; j < n; j++)
        if (s[j] === t[0])
            prev[j] = 1 + (b[j] ? 2 : 0) - Math.min(1, j * 0.05);
    for (let i = 1; i < m; i++) {
        const cur = new Array(n).fill(NEG);
        let runAny = NEG;  // max over k < j-1 of prev[k] + GAP*k
        let runWord = NEG; // same, but only k with no separator between k and j
        for (let j = 1; j < n; j++) {
            if (j >= 2 && prev[j - 2] > NEG) {
                const v = prev[j - 2] + GAP * (j - 2);
                runAny = Math.max(runAny, v);
                runWord = Math.max(runWord, v);
            }
            if (!isAlnum(s[j - 1]))
                runWord = NEG;
            if (s[j] !== t[i])
                continue;
            const charScore = 1 + (b[j] ? 2 : 0);
            const run = b[j] ? runAny : runWord;
            const consec = prev[j - 1] > NEG ? prev[j - 1] + CONSEC : NEG;
            const gapped = run > NEG ? run - GAP * (j - 1) : NEG;
            const best = Math.max(consec, gapped);
            if (best > NEG)
                cur[j] = best + charScore;
        }
        prev = cur;
    }
    let raw = NEG;
    for (let j = 0; j < n; j++)
        raw = Math.max(raw, prev[j]);
    // two letters only count as an acronym (both on word starts); longer queries
    // need some structure (boundaries, runs), scattered letters are rejected
    if (raw <= NEG || raw / m < (m === 2 ? 2.4 : 1.2))
        return 0;
    return raw;
}

function rate(t, f, fuzzy) {
    const s = f.s, n = s.length, m = t.length;
    if (m === 0 || n === 0 || m > n)
        return 0;
    if (s === t)
        return 1;
    const ratio = m / n;
    let idx = s.indexOf(t);
    if (idx === 0)
        return 0.92 + 0.06 * ratio;
    if (idx > 0) {
        for (let j = idx; j >= 0; j = s.indexOf(t, j + 1))
            if (f.b[j])
                return 0.82 + 0.06 * ratio;
        if (m < 3) // "fi" inside "conFIguration" is noise, "fig" is not
            return 0;
        return 0.62 + 0.06 * ratio - Math.min(0.06, idx * 0.005);
    }
    if (!fuzzy || m < 2)
        return 0;
    const raw = subsequence(t, f);
    return raw > 0 ? 0.3 + 0.28 * Math.min(1, raw / (3 * m)) : 0;
}

function best(rec, t) {
    let q = rate(t, rec.fName, true) * W_NAME;
    if (q >= W_NAME * 0.92)
        return q; // name prefix or better: nothing else can win
    q = Math.max(q, rate(t, rec.fExec, true) * W_EXEC);
    q = Math.max(q, rate(t, rec.fGeneric, true) * W_GENERIC);
    q = Math.max(q, rate(t, rec.fKeywords, true) * W_KEYWORDS);
    if (t.length >= 3)
        q = Math.max(q, rate(t, rec.fComment, false) * W_COMMENT);
    return q;
}

// q: normalized query, tokens: its whitespace-separated parts
function quality(rec, q, tokens) {
    let result = best(rec, q);
    if (tokens.length > 1) {
        let sum = 0;
        for (const t of tokens) {
            const s = best(rec, t);
            if (s === 0)
                return result;
            sum += s;
        }
        result = Math.max(result, 0.95 * sum / tokens.length);
    }
    return result;
}

function prepare(query) {
    const q = norm(query).trim().replace(/\s+/g, " ");
    return {
        q: q,
        tokens: q === "" ? [] : q.split(" ")
    };
}
