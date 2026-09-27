"""UMadeIt design tokens: the ONLY place colors, type, spacing, radii and breakpoints live.

The default theme, `campus`, comes from the UMadeIt Figma file
(https://www.figma.com/design/jw2I3dqHMAnZGqKBvDlmyl/UArrived): stone neutrals, indigo action,
Outfit headings over Manrope text. `harbor`, `arboretum` and `nightfall` are the earlier UMadeIt
Design System artifact themes (https://claude.ai/artifact/JkrWSa8iv9NXiRKsj9s2Wh), kept as
alternates. Every theme defines the same color names.
"""

glob DEFAULT_THEME: str = "campus",
     THEMES: dict[str, dict[str, str]] = {
         "campus": {
             "ground": "#F5F5F3",
             "panel": "#F5F5F4",
             "card": "#FFFFFF",
             "text": "#1C1917",
             "text-2": "#44403C",
             "sub": "#716A64",
             "action": "#3730A3",
             "on-action": "#FFFFFF",
             "action-soft": "#EEF2FF",
             "action-line": "#C7D2FE",
             "accent": "#F59E0B",
             "accent-ink": "#8A4F00",
             "official": "#1E4C8F",
             "official-bg": "#E4ECF7",
             "progress": "#15803D",
             "progress-bg": "#DCFCE7",
             "ai": "#6B4A9E",
             "ai-bg": "#EFE9F7",
             "urgent": "#B3261E",
             "on-urgent": "#FFFFFF",
             "danger": "#B3261E",
             "warning": "#B45309",
             "warning-bg": "#FEF3C7",
             "border": "#E7E5E4",
             "border-strong": "#D6D3D1",
             "focus-ring": "#3730A3",
             "shadow": "rgba(0,0,0,.04)",
             "scrim": "rgba(28,25,23,.48)"
         },
         "harbor": {
             "ground": "#F6F3EC",
             "panel": "#EDE8DD",
             "card": "#FFFFFF",
             "text": "#1B2430",
             "text-2": "#3D4755",
             "sub": "#5A6472",
             "action": "#1F4E79",
             "on-action": "#FFFFFF",
             "action-soft": "#E3ECF5",
             "action-line": "#A9C1DA",
             "accent": "#E0A526",
             "accent-ink": "#7A4B00",
             "official": "#1F4E79",
             "official-bg": "#E3ECF5",
             "progress": "#2D6A4F",
             "progress-bg": "#E2F0E8",
             "ai": "#6B4A9E",
             "ai-bg": "#EFE9F7",
             "urgent": "#B3261E",
             "on-urgent": "#FFFFFF",
             "danger": "#B3261E",
             "warning": "#8A5A00",
             "warning-bg": "#FBEFD9",
             "border": "rgba(27,36,48,.12)",
             "border-strong": "rgba(27,36,48,.32)",
             "focus-ring": "#1F4E79",
             "shadow": "rgba(27,36,48,.06)",
             "scrim": "rgba(27,36,48,.48)"
         },
         "arboretum": {
             "ground": "#F3F1E7",
             "panel": "#E8E5D6",
             "card": "#FFFDF7",
             "text": "#1E2A22",
             "text-2": "#35443A",
             "sub": "#566257",
             "action": "#2F5D46",
             "on-action": "#FFFFFF",
             "action-soft": "#DFEBDF",
             "action-line": "#A8C4B2",
             "accent": "#D9824B",
             "accent-ink": "#8A4414",
             "official": "#27507A",
             "official-bg": "#E2EAF2",
             "progress": "#2F5D46",
             "progress-bg": "#DFEBDF",
             "ai": "#6A4A8C",
             "ai-bg": "#EEE8F4",
             "urgent": "#A8261C",
             "on-urgent": "#FFFFFF",
             "danger": "#A8261C",
             "warning": "#80570A",
             "warning-bg": "#F8EBD5",
             "border": "rgba(30,42,34,.12)",
             "border-strong": "rgba(30,42,34,.32)",
             "focus-ring": "#2F5D46",
             "shadow": "rgba(30,42,34,.06)",
             "scrim": "rgba(30,42,34,.48)"
         },
         "nightfall": {
             "ground": "#10141C",
             "panel": "#141A24",
             "card": "#19202B",
             "text": "#EEF1F5",
             "text-2": "#C9D1DC",
             "sub": "#98A3B3",
             "action": "#8FB4E3",
             "on-action": "#0E1A2B",
             "action-soft": "#1C2B40",
             "action-line": "#3B5575",
             "accent": "#F2B84B",
             "accent-ink": "#F2B84B",
             "official": "#8FB4E3",
             "official-bg": "#1C2B40",
             "progress": "#7CCBA2",
             "progress-bg": "#173026",
             "ai": "#C3A6EE",
             "ai-bg": "#2A2140",
             "urgent": "#FF8A7A",
             "on-urgent": "#2A0A06",
             "danger": "#FF8A7A",
             "warning": "#F2B84B",
             "warning-bg": "#33270F",
             "border": "rgba(238,241,245,.10)",
             "border-strong": "rgba(238,241,245,.28)",
             "focus-ring": "#8FB4E3",
             "shadow": "rgba(0,0,0,.4)",
             "scrim": "rgba(0,0,0,.6)"
         }
     },
     FONTS: dict[str, str] = {
         "display": "Outfit, system-ui, -apple-system, 'Segoe UI', sans-serif",
         "sans": "Manrope, system-ui, -apple-system, 'Segoe UI', sans-serif",
         "mono": "'JetBrains Mono', ui-monospace, 'SF Mono', monospace"
     },
     FONT_URL: str = "https://fonts.googleapis.com/css2?family=Outfit:wght@500;600;700&family=Manrope:wght@400;500;600;700&family=JetBrains+Mono:wght@500&display=swap",
     # name -> (family, size px, weight, line height)
     TYPE: dict[str, tuple[str, int, int, float]] = {
         "welcome": ("display", 32, 700, 1.15),
         "screen-title": ("display", 28, 600, 1.2),
         "stage-title": ("display", 22, 600, 1.25),
         "card-title": ("sans", 16, 600, 1.35),
         "body": ("sans", 16, 400, 1.5),
         "small": ("sans", 13, 400, 1.5),
         "label": ("sans", 13, 700, 1.3),
         "eyebrow": ("sans", 14, 600, 1.3),
         "meta": ("sans", 13, 600, 1.4),
         "caption": ("sans", 12, 400, 1.4),
         "badge": ("sans", 11, 600, 1.3),
         "button": ("sans", 16, 600, 1.25),
         "price": ("mono", 18, 500, 1.2),
         "countdown": ("mono", 14, 500, 1.3)
     },
     SPACE: dict[str, int] = {"1": 4, "2": 8, "3": 12, "4": 16, "6": 24, "8": 32},
     RADIUS: dict[str, int] = {
         "check": 6,
         "sm": 8,
         "field": 12,
         "card": 16,
         "button": 16,
         "pill": 999
     },
     SIZE: dict[str, int] = {
         "touch-min": 44,
         "button-h": 52,
         "bp-tablet": 768,
         "bp-desktop": 1120,
         "content-max": 1200
     };

"""Color token `name` in `theme`; an unknown theme falls back to the default."""
def color(name: str, theme: str = DEFAULT_THEME) -> str {
    palette = THEMES.get(theme, THEMES[DEFAULT_THEME]);
    if name not in palette {
        raise KeyError(f"unknown color token: {name}");
    }
    return palette[name];
}

"""Inline-style fragment for a text style, e.g. text_style("body")."""
def text_style(name: str) -> dict[str, str] {
    (family, size, weight, line_height) = TYPE[name];
    return {
        "fontFamily": FONTS[family],
        "fontSize": f"{size}px",
        "fontWeight": str(weight),
        "lineHeight": str(line_height)
    };
}

"""Pixels for a spacing step, e.g. space("4") -> "16px"."""
def space(step: str) -> str {
    return f"{SPACE[step]}px";
}

"""WCAG 2.1 contrast ratio between two #RRGGBB colors."""
def contrast(fg: str, bg: str) -> float {
    lf = _luminance(fg);
    lb = _luminance(bg);
    return (max(lf, lb) + 0.05) / (min(lf, lb) + 0.05);
}

def _luminance(hex: str) -> float {
    # Parse hex digits by hand: `int(s, 16)` raises "invalid literal" under `jac test` on 0.37.
    rgb = 0;
    for ch in hex.lstrip("#").lower() {
        rgb = rgb * 16 + "0123456789abcdef".index(ch);
    }
    channels: list[float] = [];
    for shift in [16, 8, 0] {
        c = ((rgb >> shift) & 255) / 255;
        channels.append(c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4);
    }
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}

test "every theme defines the same color names" {
    names = set(THEMES[DEFAULT_THEME].keys());
    for theme in THEMES {
        assert set(THEMES[theme].keys()) == names;
    }
}

test "unknown theme falls back to the default theme" {
    assert color("action", "no-such-theme") == THEMES[DEFAULT_THEME]["action"];
}

test "unknown color token is an error, not a silent default" {
    raised = False;
    try {
        color("brand-purple");
    } except KeyError {
        raised = True;
    }
    assert raised;
}

test "reading text meets WCAG AA 4.5 to 1 in every theme" {
    pairs = [
        ("text", "ground"),
        ("text-2", "card"),
        ("sub", "panel"),
        ("on-action", "action"),
        ("action", "action-soft"),
        ("sub", "card"),
        ("accent-ink", "ground"),
        ("official", "official-bg"),
        ("progress", "progress-bg"),
        ("ai", "ai-bg"),
        ("on-urgent", "urgent"),
        ("warning", "card"),
        ("warning", "warning-bg"),
        ("danger", "card")
    ];
    for theme in THEMES {
        for (fg, bg) in pairs {
            assert contrast(color(fg, theme), color(bg, theme)) >= 4.5 , f"{theme}: {fg} on {bg}";
        }
    }
}

test "text styles resolve to CSS values" {
    assert text_style("body")["fontSize"] == "16px";
    assert space("4") == "16px";
    assert RADIUS["card"] == 16;
}

test "the default theme matches the Figma file" {
    assert DEFAULT_THEME == "campus";
    assert color("action") == "#3730A3";
    assert color("text") == "#1C1917";
    assert color("border") == "#E7E5E4";
    assert FONTS["display"].startswith("Outfit");
    assert FONTS["sans"].startswith("Manrope");
    assert SIZE["button-h"] == 52;
}
