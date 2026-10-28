import QtQuick
import qs.config
import qs.services

// Media: now playing in the island and the media panel. Keys: media* (mediaGlow from before).
SettingsPage {
    id: page

    pageId: "media"
    title: "Media"
    subtitle: "Now playing in the island and the media panel."
    icon: 0xF0387

    Component {
        id: hiddenList
        HiddenList {}
    }

    // players running now, plus the ones the settings name (they may be closed)
    function knownPlayers(): var {
        const out = [];
        const seen = {};
        for (const p of Media.allPlayers) {
            const k = Media.playerKey(p);
            if (k === "" || seen[k])
                continue;
            seen[k] = true;
            out.push({
                "value": k,
                "label": Media.name(p),
                "detail": "running",
                "icon": Media.icon(p)
            });
        }
        for (const k of [Settings.mediaPreferred, ...Array.from(Settings.mediaHidden ?? [])]) {
            if (k === "" || seen[k])
                continue;
            seen[k] = true;
            out.push(page.describe(k));
        }
        return out;
    }
    function describe(k: string): var {
        return {
            "value": k,
            "label": k.charAt(0).toUpperCase() + k.slice(1),
            "detail": "not running",
            "icon": ""
        };
    }

    sections: [
        {
            "title": "",
            "options": [
                {
                    "id": "mediaChip",
                    "kind": "switch",
                    "key": "mediaChip",
                    "label": "Media chip in the hover island",
                    "keywords": "now playing chip island hover title cover"
                },
                {
                    "id": "mediaGlow",
                    "kind": "choice",
                    "key": "mediaGlow",
                    "label": "Panel glow from the cover",
                    "keywords": "glow colour color cover blur halo media panel",
                    "options": () => [
                        {
                            "value": "soft",
                            "label": "Soft",
                            "detail": "muted colour"
                        },
                        {
                            "value": "color",
                            "label": "Colour",
                            "detail": "full colour"
                        },
                        {
                            "value": "mono",
                            "label": "Mono",
                            "detail": "grey"
                        },
                        {
                            "value": "off",
                            "label": "Off",
                            "detail": ""
                        }
                    ]
                }
            ]
        },
        {
            "title": "Players",
            "options": [
                {
                    "id": "mediaPreferred",
                    "kind": "choice",
                    "key": "mediaPreferred",
                    "label": "Preferred player",
                    "keywords": "spotify firefox mpris default first player",
                    "options": () => [
                        {
                            "value": "",
                            "label": "Automatic",
                            "detail": "the one that played last"
                        }
                    ].concat(page.knownPlayers().filter(p => !Array.from(Settings.mediaHidden ?? []).includes(p.value)).map(p => ({
                                "value": p.value,
                                "label": p.label,
                                "detail": p.detail
                            })))
                },
                {
                    "id": "mediaHidden",
                    "kind": "custom",
                    "key": "mediaHidden",
                    "label": "Hidden players (no chip, no panel)",
                    "keywords": "hide ignore exclude player mpris browser",
                    "component": hiddenList,
                    "candidates": () => page.knownPlayers(),
                    "describe": k => page.describe(k),
                    "addLabel": "Hide a player",
                    "emptyText": "Every player is shown"
                }
            ]
        }
    ]
}
