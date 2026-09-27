"""Base components (issue #3): the only building blocks feature screens use.

All color, spacing, radius and type come from ui/tokens.jac, so every screen follows the
UArrived Figma design and switches theme in one place. Mobile-first: touch targets are at
least 44px (SIZE["touch-min"]).
"""

import from ui.tokens { color, space, text_style, RADIUS, SIZE, FONTS, FONT_URL }

def px(n: int) -> str {
    return f"{n}px";
}

"""Global styles components can't set inline: web fonts, page background, and the focus ring."""
def:pub BaseStyles -> JsxElement {
    css = (
        "@import url('"
        + FONT_URL
        + "');"
        + "body{margin:0;background:"
        + color("ground")
        + ";color:"
        + color("text")
        + ";"
        + "font-family:"
        + FONTS["sans"]
        + ";}"
        + "a{color:"
        + color("action")
        + ";}"
        + "button:focus-visible,a:focus-visible,input:focus-visible,textarea:focus-visible,select:focus-visible{"
        + "outline:2px solid "
        + color("focus-ring")
        + ";outline-offset:2px;}"
        + "@media (prefers-reduced-motion: reduce){*{transition:none!important;animation:none!important;}}"
    );
    <style>{css}</style>
}

"""The one filled action per screen (`primary`), a bordered `secondary`, or a `text` link-style button."""
def:pub Button(
    label: str,
    onClick: Callable[[MouseEvent], None] | None = None,
    variant: str = "primary",
    disabled: bool = False,
    button_type: str = "button",
    full: bool = False
) -> JsxElement {
    styles: dict[str, str] = {
        "minHeight": px(SIZE["button-h"] if full else SIZE["touch-min"]),
        "padding": "0 " + space("4"),
        "borderRadius": px(RADIUS["button"]),
        "fontFamily": FONTS["sans"],
        "fontSize": text_style("button")["fontSize"],
        "fontWeight": text_style("button")["fontWeight"],
        "cursor": "not-allowed" if disabled else "pointer",
        "opacity": "0.55" if disabled else "1",
        "width": "100%" if full else "auto"
    };
    def handle(e: MouseEvent) {
        if onClick is not None {
            onClick(e);
        }
    }
    if variant == "primary" {
        styles["background"] = color("action");
        styles["color"] = color("on-action");
        styles["border"] = "0";
    } elif variant == "secondary" {
        styles["background"] = color("card");
        styles["color"] = color("action");
        styles["border"] = "1px solid " + color("action-line");
    } else {
        styles["background"] = "none";
        styles["color"] = color("action");
        styles["border"] = "0";
        styles["textDecoration"] = "underline";
    }
    <button type={button_type} disabled={disabled} onClick={handle} style={styles}>
        {label}
    </button>
}

"""A content surface: card background, hairline border, card radius."""
def:pub Card(children: any = None) -> JsxElement {
    <section
        style={{
            "background": color("card"),
            "border": "1px solid " + color("border"),
            "borderRadius": px(RADIUS["card"]),
            "boxShadow": "0 2px 8px " + color("shadow"),
            "padding": space("4"),
            "display": "flex",
            "flexDirection": "column",
            "gap": space("2")
        }}
    >
        {children}
    </section>
}

"""A status chip. Kinds: official, ai, progress, warning, action (e.g. "20 min", "NEXT ESSENTIAL"),
neutral. Every chip carries a word; color only makes it findable (design rule)."""
def:pub Badge(kind: str, label: str) -> JsxElement {
    palette: dict[str, tuple[str, str]] = {
        "official": ("official", "official-bg"),
        "ai": ("ai", "ai-bg"),
        "progress": ("progress", "progress-bg"),
        "warning": ("warning", "warning-bg"),
        "action": ("action", "action-soft"),
        "neutral": ("sub", "panel")
    };
    (fg, bg) = palette.get(kind, ("sub", "panel"));
    <span
        style={{
            "display": "inline-flex",
            "alignSelf": "flex-start",
            "alignItems": "center",
            "gap": space("1"),
            "padding": "3px 8px",
            "borderRadius": px(RADIUS["sm"]),
            "background": color(bg),
            "color": color(fg),
            "fontFamily": FONTS["sans"],
            "fontSize": text_style("badge")["fontSize"],
            "fontWeight": text_style("badge")["fontWeight"],
            "letterSpacing": "0.02em",
            "whiteSpace": "nowrap"
        }}
    >
        {label}
    </span>
}

"""A labeled text input (or textarea when `multiline`). `hint` shows under the field."""
def:pub Field(
    label: str,
    value: str,
    onChange: Callable[[str], None],
    input_type: str = "text",
    hint: str = "",
    multiline: bool = False,
    placeholder: str = ""
) -> JsxElement {
    box: dict[str, str] = {
        "minHeight": px(SIZE["button-h"]),
        "padding": space("3") + " " + space("4"),
        "border": "1px solid " + color("border"),
        "borderRadius": px(RADIUS["field"]),
        "background": color("card"),
        "color": color("text"),
        "fontFamily": FONTS["sans"],
        "fontSize": "16px",
        "boxSizing": "border-box",
        "width": "100%"
    };
    <label
        style={{
            "display": "flex",
            "flexDirection": "column",
            "gap": space("1"),
            "fontFamily": FONTS["sans"],
            "fontSize": "14px",
            "fontWeight": "600",
            "color": color("text")
        }}
    >
        {label}{(
            <textarea
                value={value}
                placeholder={placeholder}
                rows={4}
                style={box}
                onChange={lambda (e: ChangeEvent) { onChange(e.target.value); }}
            />
        )
            if multiline
            else (
                <input
                    type={input_type}
                    value={value}
                    placeholder={placeholder}
                    style={box}
                    onChange={lambda (e: ChangeEvent) { onChange(e.target.value); }}
                />
            )}{<span style={{"fontWeight": "400", "color": color("sub")}}>{hint}</span>
            if hint
            else None}
    </label>
}

"""Always-visible urgent help (design rule 5). `urgent` means nothing else."""
def:pub HelpButton -> JsxElement {
    <a
        href="/help"
        style={{
            "display": "inline-flex",
            "alignItems": "center",
            "minHeight": px(SIZE["touch-min"]),
            "padding": "0 " + space("4"),
            "borderRadius": px(RADIUS["pill"]),
            "background": color("urgent"),
            "color": color("on-urgent"),
            "fontWeight": "700",
            "textDecoration": "none"
        }}
    >
        Urgent help
    </a>
}

glob NAV_ITEMS: list[tuple[str, str]] = [
         ("today", "Today"),
         ("journey", "Journey"),
         ("housing", "Housing"),
         ("market", "Market"),
         ("profile", "Profile")
     ];

"""The app frame: top bar with the wordmark and urgent help, the screen, and bottom navigation.
`active` is the NAV_ITEMS key of the current section."""
def:pub AppShell(title: str, active: str, children: any = None) -> JsxElement {
    <div
        style={{
            "minHeight": "100vh",
            "display": "flex",
            "flexDirection": "column",
            "background": color("ground")
        }}
    >
        <BaseStyles/>
        <header
            style={{
                "display": "flex",
                "alignItems": "center",
                "justifyContent": "space-between",
                "padding": space("2") + " " + space("4"),
                "background": color("ground"),
                "borderBottom": "1px solid " + color("border")
            }}
        >
            <span
                style={{
                    "fontFamily": FONTS["display"],
                    "fontSize": "22px",
                    "fontWeight": "700",
                    "color": color("action")
                }}
            >
                UArrived
            </span>
            <HelpButton/>
        </header>
        <main
            style={{
                "flexGrow": "1",
                "width": "100%",
                "maxWidth": "720px",
                "margin": "0 auto",
                "boxSizing": "border-box",
                "padding": space("4"),
                "display": "flex",
                "flexDirection": "column",
                "gap": space("3")
            }}
        >
            <h1
                style={{
                    "margin": "0",
                    "fontFamily": FONTS["display"],
                    "fontSize": text_style("screen-title")["fontSize"],
                    "fontWeight": text_style("screen-title")["fontWeight"],
                    "lineHeight": text_style("screen-title")["lineHeight"],
                    "color": color("text")
                }}
            >
                {title}
            </h1>
            {children}
        </main>
        <nav
            aria-label="Main"
            style={{
                "position": "sticky",
                "bottom": "0",
                "display": "grid",
                "gridTemplateColumns": "repeat(5, minmax(0, 1fr))",
                "background": color("card"),
                "borderTop": "1px solid " + color("border")
            }}
        >
            {[
                <a
                    key={key}
                    href={"/" + key}
                    aria-current={"page" if key == active else None}
                    style={{
                        "minHeight": px(SIZE["touch-min"] + 4),
                        "display": "flex",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "textDecoration": "none",
                        "fontSize": "12px",
                        "fontWeight": "700" if key == active else "500",
                        "color": color("action") if key == active else color("sub")
                    }}
                >
                    {label}
                </a> for (key, label) in NAV_ITEMS
            ]}
        </nav>
    </div>
}
