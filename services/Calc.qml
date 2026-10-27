pragma Singleton
import QtQuick
import Quickshell

// Safe arithmetic for the launcher, no eval():
//   + - * / % (modulo) ^ or ** (power, right assoc) ! (factorial) ( ) , × ÷ · −
//   implicit multiplication before a name or "(":  2pi  3(4+1)  (1+2)(3+4)
//   constants  pi π e tau phi
//   functions  sqrt cbrt abs sin cos tan asin acos atan (radians) ln log log2 exp
//              round floor ceil min max pow
//   decimal comma when no function is used: 1,5*2 = 3
// evaluate() gives NaN for anything that is not one complete expression.
Singleton {
    id: root

    readonly property var constants: ({
            "pi": Math.PI,
            "π": Math.PI,
            "e": Math.E,
            "tau": 2 * Math.PI,
            "phi": (1 + Math.sqrt(5)) / 2
        })
    readonly property var functions: ({
            "sqrt": Math.sqrt,
            "cbrt": Math.cbrt,
            "abs": Math.abs,
            "sin": Math.sin,
            "cos": Math.cos,
            "tan": Math.tan,
            "asin": Math.asin,
            "acos": Math.acos,
            "atan": Math.atan,
            "ln": Math.log,
            "log": Math.log10,
            "log2": Math.log2,
            "exp": Math.exp,
            "round": Math.round,
            "floor": Math.floor,
            "ceil": Math.ceil,
            "min": Math.min,
            "max": Math.max,
            "pow": Math.pow
        })

    // null if the text contains anything we do not understand
    function tokenize(src: string): var {
        let s = src.replace(/\*\*/g, "^").replace(/[×·]/g, "*").replace(/÷/g, "/").replace(/−/g, "-");
        if (!/[a-zπ]/i.test(s))
            s = s.replace(/,/g, ".");
        const out = [];
        let i = 0;
        while (i < s.length) {
            const rest = s.slice(i);
            const ws = /^\s+/.exec(rest);
            if (ws) {
                i += ws[0].length;
                continue;
            }
            const num = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(rest);
            if (num) {
                out.push({
                    "t": "num",
                    "v": parseFloat(num[0])
                });
                i += num[0].length;
                continue;
            }
            const id = /^(π|[a-z][a-z0-9]*)/i.exec(rest);
            if (id) {
                out.push({
                    "t": "id",
                    "v": id[0].toLowerCase()
                });
                i += id[0].length;
                continue;
            }
            if ("+-*/%^!(),".includes(s[i])) {
                out.push({
                    "t": "op",
                    "v": s[i]
                });
                i++;
                continue;
            }
            return null;
        }
        return out;
    }

    function factorial(n: real): real {
        if (n < 0 || n > 170 || !Number.isInteger(n))
            return NaN;
        let r = 1;
        for (let k = 2; k <= n; k++)
            r *= k;
        return r;
    }

    function evaluate(src: string): real {
        const toks = tokenize(src);
        if (!toks || toks.length === 0)
            return NaN;
        let p = 0;
        const peek = () => toks[p];
        const next = () => toks[p++];
        const isOp = (t, v) => !!t && t.t === "op" && t.v === v;
        const fail = () => {
            throw new Error("calc");
        };

        function expr() {
            let v = term();
            while (isOp(peek(), "+") || isOp(peek(), "-")) {
                const o = next().v;
                const r = term();
                v = o === "+" ? v + r : v - r;
            }
            return v;
        }
        function term() {
            let v = unary();
            for (; ; ) {
                const t = peek();
                if (isOp(t, "*") || isOp(t, "/") || isOp(t, "%")) {
                    next();
                    const r = unary();
                    v = t.v === "*" ? v * r : t.v === "/" ? v / r : v % r;
                } else if (t && (t.t === "id" || isOp(t, "("))) {
                    v *= power(); // implicit multiplication
                } else {
                    return v;
                }
            }
        }
        function unary() {
            if (isOp(peek(), "-")) {
                next();
                return -unary();
            }
            if (isOp(peek(), "+")) {
                next();
                return unary();
            }
            return power();
        }
        function power() {
            const b = postfix();
            if (isOp(peek(), "^")) {
                next();
                return Math.pow(b, unary());
            }
            return b;
        }
        function postfix() {
            let v = primary();
            while (isOp(peek(), "!")) {
                next();
                v = root.factorial(v);
            }
            return v;
        }
        function primary() {
            const t = next();
            if (!t)
                fail();
            if (t.t === "num")
                return t.v;
            if (isOp(t, "(")) {
                const v = expr();
                if (!isOp(next(), ")"))
                    fail();
                return v;
            }
            if (t.t === "id") {
                const fn = root.functions[t.v];
                if (fn !== undefined && isOp(peek(), "(")) {
                    next();
                    const args = [expr()];
                    while (isOp(peek(), ",")) {
                        next();
                        args.push(expr());
                    }
                    if (!isOp(next(), ")"))
                        fail();
                    return fn(...args);
                }
                if (root.constants[t.v] !== undefined)
                    return root.constants[t.v];
                if (fn !== undefined) // "sqrt 16"
                    return fn(power());
            }
            fail();
        }

        try {
            const v = expr();
            return p === toks.length ? v : NaN;
        } catch (e) {
            return NaN;
        }
    }

    // Worth showing as a calculator row: a finite result and real arithmetic, so
    // "2048", "e", "-5" or "7zip" stay plain searches.
    function isMath(src: string): bool {
        const toks = tokenize(src);
        if (!toks || toks.length < 2)
            return false;
        const op = toks.some((t, i) => t.t === "op" && "+-*/%^!".includes(t.v) && i > 0);
        const fn = toks.some(t => t.t === "id" && functions[t.v] !== undefined);
        const num = toks.some(t => t.t === "num");
        const cst = toks.some(t => t.t === "id" && constants[t.v] !== undefined);
        return (op || fn || (num && cst)) && isFinite(evaluate(src));
    }

    function format(v: real): string {
        if (!isFinite(v))
            return "";
        if (Number.isInteger(v) && Math.abs(v) < 1e21)
            return String(v);
        const a = Math.abs(v);
        if (a < 1e-6 || a >= 1e15)
            return v.toExponential(8).replace(/\.?0+e/, "e");
        return String(parseFloat(v.toPrecision(12)));
    }
}
