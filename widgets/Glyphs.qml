pragma Singleton
import QtQuick
import Quickshell

// Glyphs on top of Icons.qml (same 24x24 stroke grid, same url() output):
// more Lucide icons (ISC, https://lucide.dev) plus a few drawn to match ref/08
// where Lucide differs (fan-shaped Wi-Fi with signal levels, game-mode capsule).
Singleton {
    id: root

    readonly property var bodies: ({
            "chevron-left": '<path d="m15 18-6-6 6-6"/>',
            "sun-dim": '<circle cx="12" cy="12" r="4"/><path d="M12 4h.01"/><path d="M20 12h.01"/><path d="M12 20h.01"/><path d="M4 12h.01"/><path d="M17.657 6.343h.01"/><path d="M17.657 17.657h.01"/><path d="M6.343 17.657h.01"/><path d="M6.343 6.343h.01"/>',
            "gamemode": '<rect x="2.5" y="7" width="19" height="10" rx="5"/><path d="M7.5 10.6v2.8"/><path d="M12 12h4.5"/>',
            "bluetooth-off": '<path d="m17 17-5 5V12l-5 5"/><path d="m2 2 20 20"/><path d="M14.5 9.5 17 7l-5-5v4.5"/>',
            "headphones": '<path d="M3 14h3a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a9 9 0 0 1 18 0v7a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3"/>',
            "speaker": '<rect width="16" height="20" x="4" y="2" rx="2"/><path d="M12 6h.01"/><circle cx="12" cy="14" r="4"/><path d="M12 14h.01"/>',
            "mouse": '<rect x="5" y="2" width="14" height="20" rx="7"/><path d="M12 6v4"/>',
            "keyboard": '<path d="M10 8h.01"/><path d="M12 12h.01"/><path d="M14 8h.01"/><path d="M16 12h.01"/><path d="M18 8h.01"/><path d="M6 8h.01"/><path d="M7 16h10"/><path d="M8 12h.01"/><rect width="20" height="16" x="2" y="4" rx="2"/>',
            "gamepad": '<line x1="6" x2="10" y1="11" y2="11"/><line x1="8" x2="8" y1="9" y2="13"/><line x1="15" x2="15.01" y1="12" y2="12"/><line x1="18" x2="18.01" y1="10" y2="10"/><path d="M17.32 5H6.68a4 4 0 0 0-3.978 3.59c-.006.052-.01.101-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258-.007-.05-.011-.1-.017-.151A4 4 0 0 0 17.32 5z"/>',
            "smartphone": '<rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><path d="M12 18h.01"/>',
            "laptop": '<path d="M18 5a2 2 0 0 1 2 2v8.526a2 2 0 0 0 .212.897l1.068 2.127a1 1 0 0 1-.9 1.45H3.62a1 1 0 0 1-.9-1.45l1.068-2.127A2 2 0 0 0 4 15.526V7a2 2 0 0 1 2-2z"/><path d="M20.054 15.987H3.946"/>',
            "monitor": '<rect width="20" height="14" x="2" y="3" rx="2"/><line x1="8" x2="16" y1="21" y2="21"/><line x1="12" x2="12" y1="17" y2="21"/>',
            "check": '<path d="M20 6 9 17l-5-5"/>',
            "music": '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>',
            "loader": '<path d="M21 12a9 9 0 1 1-6.219-8.56"/>',
            "refresh": '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>',
            "x": '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
            // media (Lucide 0.468; drawn filled)
            "play": '<path d="M6 4.8v14.4a1 1 0 0 0 1.52.85l11.5-7.2a1 1 0 0 0 0-1.7L7.52 3.95A1 1 0 0 0 6 4.8z"/>',
            "pause": '<rect x="14" y="4" width="4" height="16" rx="1"/><rect x="6" y="4" width="4" height="16" rx="1"/>',
            "skip-back": '<path d="M18.5 19.2V4.8a1 1 0 0 0-1.55-.83L7.6 11.17a1 1 0 0 0 0 1.66l9.35 7.2a1 1 0 0 0 1.55-.83z"/><path d="M4.5 5v14"/>',
            "skip-forward": '<path d="M5.5 4.8v14.4a1 1 0 0 0 1.55.83l9.35-7.2a1 1 0 0 0 0-1.66L7.05 3.97A1 1 0 0 0 5.5 4.8z"/><path d="M19.5 5v14"/>',
            "arrow-up-right": '<path d="M7 7h10v10"/><path d="M7 17 17 7"/>',
            "wifi-off": '<path d="M12 20h.01"/><path d="M8.5 16.429a5 5 0 0 1 7 0"/><path d="M5 12.859a10 10 0 0 1 5.17-2.69"/><path d="M19 12.859a10 10 0 0 0-2.007-1.523"/><path d="M2 8.82a15 15 0 0 1 4.177-2.643"/><path d="M22 8.82a15 15 0 0 0-11.288-3.764"/><path d="m2 2 20 20"/>'
        })

    function has(name: string): bool {
        return bodies.hasOwnProperty(name) || /^wifi-[0-4]$/.test(name);
    }

    // Fan-shaped Wi-Fi as in ref/08: filled wedge + three 84 degree arcs around
    // (12, 20.5); arcs above the signal level are drawn at 30 % (ref: outer arc grey).
    function wifi(level: int): string {
        const arc = (r, i) => {
            const dx = (r * 0.669).toFixed(2), dy = (20.5 - r * 0.743).toFixed(2);
            return `<path opacity="${i <= level ? 1 : 0.3}" d="M${(12 - dx).toFixed(2)} ${dy}A${r} ${r} 0 0 1 ${(12 + +dx).toFixed(2)} ${dy}"/>`;
        };
        return '<path fill="currentColor" d="M12 20.5 10.4 18.72A2.4 2.4 0 0 1 13.6 18.72Z"/>' + arc(6.2, 1) + arc(10.6, 2) + arc(15, 3);
    }

    function body(name: string): string {
        const m = /^wifi-([0-4])$/.exec(name);
        return m ? wifi(parseInt(m[1])) : bodies[name];
    }

    function url(name: string, c: color, stroke: real, filled: bool): string {
        const col = Icons.hex(c);
        const b = body(name).replace(/currentColor/g, col);
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="${filled ? col : "none"}" fill-opacity="${c.a}" stroke="${col}" stroke-opacity="${c.a}" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round">${b}</svg>`;
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
    }
}
