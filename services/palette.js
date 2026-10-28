.pragma library

// Wallpaper -> luxshell palette (the "wallpaper" theme). Pure functions, no QML.
//
// Input: the colour histogram of a small copy of the wallpaper, as printed by
//   magick <img> -resize 160x160 -dither None -colors 12 -depth 8 -format %c histogram:info:-
// (services/ThemeSync runs it; videos go through one ffmpeg frame first).
//
// Monochrome first, accent sparingly:
//   - surfaces, text and workspace greys are neutral with a trace of the wallpaper's
//     dominant hue (more trace the more colourful the wallpaper is, never more than a tint)
//   - the accent is the most characteristic colour (chroma x share), saturation capped and
//     lifted to a readable lightness; a grey wallpaper gets a light grey accent (= noir)
//   - swatches (what the theme picker card shows) are the dominant distinct colours,
//     lightness clamped so they read on the dark card
//   - ansi (terminal export) keeps the six semantic hues (red stays red), each pulled
//     halfway toward a wallpaper colour of similar hue if there is one

function parseHistogram(text) {
    const out = [];
    for (const line of String(text).split("\n")) {
        const m = line.match(/^\s*(\d+):\s*\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/);
        if (!m)
            continue;
        const v = [m[2], m[3], m[4]].map(Number);
        // 16-bit quantum builds print 0..65535
        const k = v.some(x => x > 255) ? 257 : 1;
        out.push({
            "count": Number(m[1]),
            "r": v[0] / k,
            "g": v[1] / k,
            "b": v[2] / k
        });
    }
    return out.sort((a, b) => b.count - a.count);
}

function clamp(x, lo, hi) {
    return Math.max(lo, Math.min(hi, x));
}

function rgb2hsl(r, g, b) {
    r /= 255;
    g /= 255;
    b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b);
    const l = (max + min) / 2;
    const c = max - min;
    let h = 0, s = 0;
    if (c > 0) {
        s = c / (1 - Math.abs(2 * l - 1));
        if (max === r)
            h = ((g - b) / c) % 6;
        else if (max === g)
            h = (b - r) / c + 2;
        else
            h = (r - g) / c + 4;
        h = (h * 60 + 360) % 360;
    }
    return {
        "h": h,
        "s": s,
        "l": l,
        "c": c
    };
}

function hsl(h, s, l) {
    h = ((h % 360) + 360) % 360;
    s = clamp(s, 0, 1);
    l = clamp(l, 0, 1);
    const c = (1 - Math.abs(2 * l - 1)) * s;
    const x = c * (1 - Math.abs((h / 60) % 2 - 1));
    const m = l - c / 2;
    let rgb = [0, 0, 0];
    if (h < 60)
        rgb = [c, x, 0];
    else if (h < 120)
        rgb = [x, c, 0];
    else if (h < 180)
        rgb = [0, c, x];
    else if (h < 240)
        rgb = [0, x, c];
    else if (h < 300)
        rgb = [x, 0, c];
    else
        rgb = [c, 0, x];
    return "#" + rgb.map(v => Math.round((v + m) * 255).toString(16).padStart(2, "0")).join("");
}

function hueDist(a, b) {
    const d = Math.abs(a - b) % 360;
    return d > 180 ? 360 - d : d;
}

// circular blend a -> b by t
function hueMix(a, b, t) {
    let d = ((b - a) % 360 + 540) % 360 - 180;
    return (a + d * t + 360) % 360;
}

function derive(colors) {
    const list = (colors ?? []).filter(c => c.count > 0);
    const total = list.reduce((n, c) => n + c.count, 0);
    if (total === 0)
        return null;
    const cs = list.map(c => Object.assign({
            "w": c.count / total
        }, rgb2hsl(c.r, c.g, c.b), c));

    // dominant hue: circular mean weighted by share x chroma
    let x = 0, y = 0, cw = 0;
    for (const c of cs) {
        const k = c.w * c.c;
        x += Math.cos(c.h * Math.PI / 180) * k;
        y += Math.sin(c.h * Math.PI / 180) * k;
        cw += c.w * c.c;
    }
    const hue = (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
    // how colourful the wallpaper is overall: 0 grey .. 1 vivid
    const colourful = clamp(cw / 0.35, 0, 1);
    const tint = 0.18 * colourful;     // surfaces (a grey wallpaper gives pure greys)
    const tintText = 0.07 * colourful; // text and greys

    // accent: most characteristic readable colour
    let best = null, bestScore = 0;
    for (const c of cs) {
        if (c.c < 0.12 || c.l < 0.18 || c.l > 0.92)
            continue;
        const score = c.c * Math.pow(c.w, 0.4);
        if (score > bestScore) {
            best = c;
            bestScore = score;
        }
    }
    const mono = !best || best.c < 0.16;
    const accent = mono ? hsl(hue, 0.05 * colourful, 0.9) : hsl(best.h, clamp(best.s, 0.35, 0.62), clamp(best.l, 0.64, 0.76));

    // swatches: dominant distinct colours (RGB distance > 38), lightness clamped for the card
    const picked = [];
    for (const c of cs) {
        if (picked.length === 6)
            break;
        if (picked.some(p => Math.hypot(p.r - c.r, p.g - c.g, p.b - c.b) < 38))
            continue;
        picked.push(c);
    }
    const swatches = picked.map(c => hsl(c.h, Math.min(c.s, 0.7), clamp(c.l, 0.34, 0.86)));
    for (let i = 0; swatches.length < 6; i++)
        swatches.push(hsl(hue, tintText, 0.4 + 0.09 * i));

    // ansi: semantic hues, pulled toward wallpaper colours of similar hue
    const targets = [[355, 0.66], [125, 0.62], [42, 0.7], [215, 0.68], [300, 0.7], [185, 0.66]];
    const ansi = targets.map(([th, l]) => {
        let near = null;
        for (const c of cs)
            if (c.c > 0.15 && hueDist(c.h, th) < 35 && (!near || c.w > near.w))
                near = c;
        const h = near ? hueMix(th, near.h, 0.5) : th;
        return hsl(h, mono ? 0.3 : 0.5, l);
    });

    return {
        "island": "#000000",
        "base": hsl(hue, tint, 0.075),
        "surface": hsl(hue, tint, 0.045),
        "surfaceHigh": hsl(hue, tint * 0.9, 0.135),
        "text": hsl(hue, tintText, 0.92),
        "textSecondary": hsl(hue, tintText, 0.68),
        "textDim": hsl(hue, tintText, 0.55),
        "muted": hsl(hue, tintText, 0.3),
        "accent": accent,
        "onAccent": hsl(hue, tint, 0.06),
        "wsOccupied": hsl(hue, tintText, 0.39),
        "wsEmpty": hsl(hue, tintText, 0.16),
        "swatches": swatches,
        "ansi": ansi,
        "mono": mono
    };
}
