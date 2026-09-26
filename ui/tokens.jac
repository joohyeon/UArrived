"""UArrived design tokens: the ONLY place colors, type, spacing, radii and breakpoints live.

Mirrors the UArrived Design System artifact
(https://claude.ai/artifact/JkrWSa8iv9NXiRKsj9s2Wh). Change both together.
Three themes share every color name: harbor (primary), arboretum, nightfall.
"""

glob DEFAULT_THEME: str = "harbor",
     THEMES: dict[str, dict[str, str]] = {
         "harbor": {
             "ground": "#F6F3EC",
             "panel": "#EDE8DD",
             "card": "#FFFFFF",
             "text": "#1B2430",
             "text-2": "#3D4755",
             "sub": "#5A6472",
             "action": "#1F4E79",
             "on-action": "#FFFFFF",
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
             "border": "rgba(27,36,48,.12)",
             "border-strong": "rgba(27,36,48,.32)",
             "focus-ring": "#1F4E79"
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
             "border": "rgba(30,42,34,.12)",
             "border-strong": "rgba(30,42,34,.32)",
             "focus-ring": "#2F5D46"
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
             "border": "rgba(238,241,245,.10)",
             "border-strong": "rgba(238,241,245,.28)",
             "focus-ring": "#8FB4E3"
         }
     },
     FONTS: dict[str, str] = {
         "display": "Fraunces, Georgia, 'Times New Roman', serif",
         "sans": "'Source Sans 3', system-ui, -apple-system, 'Segoe UI', sans-serif",
         "mono": "'JetBrains Mono', ui-monospace, 'SF Mono', monospace"
     },
     TYPE: dict[str, tuple[str, int, int, float]] = {
         "welcome": ("display", 34, 700, 1.1),
         "screen-title": ("display", 26, 600, 1.2),
         "stage-title": ("display", 20, 600, 1.25),
         "card-title": ("sans", 18, 600, 1.3),
         "body": ("sans", 16, 400, 1.5),
         "label": ("sans", 13, 700, 1.3),
         "meta": ("sans", 14, 400, 1.4),
         "button": ("sans", 16, 600, 1.25),
         "price": ("mono", 18, 500, 1.2),
         "countdown": ("mono", 14, 500, 1.3)
     },
     SPACE: dict[str, int] = {"1": 4, "2": 8, "3": 12, "4": 16, "6": 24, "8": 32},
     RADIUS: dict[str, int] = {"sm": 8, "card": 16, "button": 12, "pill": 999},
     SIZE: dict[str, int] = {
         "touch-min": 44,
         "bp-tablet": 768,
         "bp-desktop": 1120,
         "content-max": 1200
     };

# name -> (family, size px, weight, line height)
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

test "unknown theme falls back to harbor" {
    assert color("action", "no-such-theme") == THEMES["harbor"]["action"];
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
        ("accent-ink", "ground"),
        ("official", "official-bg"),
        ("progress", "progress-bg"),
        ("ai", "ai-bg"),
        ("on-urgent", "urgent"),
        ("warning", "card"),
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
