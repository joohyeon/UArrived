"""Base components (issue #3): the only building blocks feature screens use.

All color, spacing, radius and type come from ui/tokens.jac, so every screen follows the
UMadeIt Figma design and switches theme in one place. Mobile-first: touch targets are at
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

"""A card grid that reflows itself by available width, not by viewport breakpoints: one column on
a phone, as many `min`-wide columns as fit on tablet/desktop. Use for a screen whose content is a
list of same-shaped cards (posts, groups, chats) instead of stacking them in a single column on
wide screens."""
def:pub ResponsiveGrid(children: any = None, min: str = "280px") -> JsxElement {
    <div
        style={{
            "display": "grid",
            "gridTemplateColumns": f"repeat(auto-fit, minmax({min}, 1fr))",
            "gap": space("3"),
            "alignItems": "start"
        }}
    >
        {children}
    </div>
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

"""A field's label: 14px semibold, or (`caps`) the Figma form style, small uppercase in `sub`."""
def field_label_style(caps: bool) -> dict[str, str] {
    return {
        "display": "flex",
        "flexDirection": "column",
        "gap": space("2") if caps else space("1"),
        "fontFamily": FONTS["sans"],
        "fontSize": "12px" if caps else "14px",
        "fontWeight": "700" if caps else "600",
        "letterSpacing": "0.04em" if caps else "normal",
        "textTransform": "uppercase" if caps else "none",
        "color": color("sub") if caps else color("text")
    };
}

"""A labeled text input (or textarea when `multiline`). `hint` shows under the field; `caps`
uses the Figma form label style; `autocomplete` is passed to the input (e.g. "email"); `error`
shows under the field in `danger` and marks the input aria-invalid."""
def:pub Field(
    label: str,
    value: str,
    onChange: Callable[[str], None],
    input_type: str = "text",
    hint: str = "",
    multiline: bool = False,
    placeholder: str = "",
    caps: bool = False,
    autocomplete: str = "",
    error: str = ""
) -> JsxElement {
    box: dict[str, str] = {
        "minHeight": px(SIZE["button-h"]),
        "padding": space("3") + " " + space("4"),
        "border": "1px solid " + (color("danger") if error else color("border")),
        "borderRadius": px(RADIUS["field"]),
        "background": color("card"),
        "color": color("text"),
        "fontFamily": FONTS["sans"],
        "fontSize": "16px",
        "boxSizing": "border-box",
        "width": "100%"
    };
    <label style={field_label_style(caps)}>
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
                    autoComplete={autocomplete or None}
                    aria-invalid={True if error else None}
                    style={box}
                    onChange={lambda (e: ChangeEvent) { onChange(e.target.value); }}
                />
            )}{<span
            style={{
                "fontWeight": "400",
                "fontSize": "13px",
                "letterSpacing": "normal",
                "textTransform": "none",
                "color": color("sub")
            }}
        >
            {hint}
        </span>
            if hint and not error
            else None}{<span
            role="alert"
            style={{
                "fontWeight": "600",
                "fontSize": "14px",
                "letterSpacing": "normal",
                "textTransform": "none",
                "color": color("danger")
            }}
        >
            {error}
        </span>
            if error
            else None}
    </label>
}

"""A password input with a Show / Hide toggle (a 44px text button, so it works without an icon)."""
def:pub PasswordField(
    label: str,
    value: str,
    onChange: Callable[[str], None],
    placeholder: str = "",
    caps: bool = False,
    autocomplete: str = "current-password",
    error: str = ""
) -> JsxElement {
    has shown: bool = False;
    <label style={field_label_style(caps)}>
        {label}
        <span style={{"position": "relative", "display": "block"}}>
            <input
                type={"text" if shown else "password"}
                value={value}
                placeholder={placeholder}
                autoComplete={autocomplete}
                aria-invalid={True if error else None}
                onChange={lambda (e: ChangeEvent) { onChange(e.target.value); }}
                style={{
                    "minHeight": px(SIZE["button-h"]),
                    "padding": space("3") + " 72px " + space("3") + " " + space("4"),
                    "border": "1px solid "
                        + (color("danger") if error else color("border")),
                    "borderRadius": px(RADIUS["field"]),
                    "background": color("card"),
                    "color": color("text"),
                    "fontFamily": FONTS["sans"],
                    "fontSize": "16px",
                    "letterSpacing": "normal",
                    "textTransform": "none",
                    "boxSizing": "border-box",
                    "width": "100%"
                }}
            />
            <button
                type="button"
                aria-pressed={shown}
                aria-label={"Hide password" if shown else "Show password"}
                onClick={lambda (e: MouseEvent) { shown = not shown; }}
                style={{
                    "position": "absolute",
                    "right": space("1"),
                    "top": "50%",
                    "transform": "translateY(-50%)",
                    "minHeight": px(SIZE["touch-min"]),
                    "minWidth": px(SIZE["touch-min"]),
                    "padding": "0 " + space("2"),
                    "border": "0",
                    "background": "none",
                    "color": color("action"),
                    "fontFamily": FONTS["sans"],
                    "fontSize": "13px",
                    "fontWeight": "600",
                    "letterSpacing": "normal",
                    "textTransform": "none",
                    "cursor": "pointer"
                }}
            >
                {"Hide" if shown else "Show"}
            </button>
        </span>
        {<span
            role="alert"
            style={{
                "fontWeight": "600",
                "fontSize": "14px",
                "letterSpacing": "normal",
                "textTransform": "none",
                "color": color("danger")
            }}
        >
            {error}
        </span>
            if error
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
         ("market", "Market"),
         ("profile", "Profile")
     ],
     # Stroke icon (24px viewBox path) per nav item; the label always sits beside it.
     NAV_ICONS: dict[str, str] = {
         "today": "M12 3v2M12 19v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M3 12h2M19 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8z",
         "journey": "M9 4 3 6v14l6-2 6 2 6-2V4l-6 2-6-2zM9 4v14M15 6v14",
         "market": "M6 7h12l-1 13H7L6 7zM9 7a3 3 0 0 1 6 0",
         "profile": "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0"
     };

"""Shell rules inline styles can't express: header links on wide screens, a bottom tab bar with
icons on phones (kept clear of the home indicator)."""
def:pub ShellStyles -> JsxElement {
    css = (
        ".as-topnav{display:none}"
        + ".as-tabbar{display:grid}"
        + ".as-main{padding-bottom:88px}"
        + "@media (min-width: 900px){"
        + ".as-topnav{display:flex}"
        + ".as-tabbar{display:none}"
        + ".as-main{padding-bottom:48px}"
        + "}"
    );
    <style>{css}</style>
}

def:pub NavIcon(item: str) -> JsxElement {
    <svg
        width="22"
        height="22"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
    >
        <path d={NAV_ICONS.get(item, "")}/>
    </svg>
}

"""The app frame: a header with the wordmark, section links (wide screens) and Urgent help; the
screen title and content; and a bottom tab bar with icons on phones. `active` is the NAV_ITEMS key
of the current section. `wide` raises the content column from 760px (a reading/form column) to
SIZE["content-max"] (1200px) for card grids or list+detail screens; the header aligns to it."""
def:pub AppShell(
    title: str, active: str, children: any = None, wide: bool = False
) -> JsxElement {
    column = px(SIZE["content-max"]) if wide else "760px";
    <div
        style={{
            "minHeight": "100vh",
            "display": "flex",
            "flexDirection": "column",
            "background": color("canvas")
        }}
    >
        <BaseStyles/>
        <ShellStyles/>
        <header
            style={{
                "position": "sticky",
                "top": "0",
                "zIndex": "20",
                "background": color("canvas"),
                "borderBottom": "1px solid " + color("border")
            }}
        >
            <div
                style={{
                    "maxWidth": column,
                    "margin": "0 auto",
                    "padding": space("2") + " " + space("4"),
                    "boxSizing": "border-box",
                    "display": "flex",
                    "alignItems": "center",
                    "gap": space("6")
                }}
            >
                <a
                    href="/today"
                    style={{
                        "fontFamily": FONTS["display"],
                        "fontSize": "22px",
                        "fontWeight": "700",
                        "color": color("action"),
                        "textDecoration": "none",
                        "marginRight": "auto"
                    }}
                >
                    UMade
                    <span style={{"color": color("coral-ink")}}>It</span>
                </a>
                <nav
                    aria-label="Main"
                    className="as-topnav"
                    style={{"gap": space("1")}}
                >
                    {[
                        <a
                            key={key}
                            href={"/" + key}
                            aria-current={"page" if key == active else None}
                            style={{
                                "minHeight": px(SIZE["touch-min"]),
                                "display": "inline-flex",
                                "alignItems": "center",
                                "padding": "0 " + space("3"),
                                "borderRadius": px(RADIUS["pill"]),
                                "textDecoration": "none",
                                "fontSize": "15px",
                                "fontWeight": "700" if key == active else "500",
                                "background": color("card")
                                    if key == active
                                    else "transparent",
                                "boxShadow": ("inset 0 0 0 1px " + color("border"))
                                    if key == active
                                    else "none",
                                "color": color("action")
                                    if key == active
                                    else color("text-2")
                            }}
                        >
                            {label}
                        </a> for (key, label) in NAV_ITEMS
                    ]}
                </nav>
                <HelpButton/>
            </div>
        </header>
        <main
            className="as-main"
            style={{
                "flexGrow": "1",
                "width": "100%",
                "maxWidth": column,
                "margin": "0 auto",
                "boxSizing": "border-box",
                "padding": space("6") + " " + space("4"),
                "display": "flex",
                "flexDirection": "column",
                "gap": space("4")
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
            className="as-tabbar"
            style={{
                "position": "fixed",
                "left": "0",
                "right": "0",
                "bottom": "0",
                "zIndex": "20",
                "gridTemplateColumns": "repeat(4, minmax(0, 1fr))",
                "padding": "0 0 env(safe-area-inset-bottom)",
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
                        "minHeight": "60px",
                        "display": "flex",
                        "flexDirection": "column",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "gap": "2px",
                        "textDecoration": "none",
                        "fontSize": "12px",
                        "fontWeight": "700" if key == active else "500",
                        "color": color("action") if key == active else color("sub"),
                        "borderTop": "3px solid "
                            + (color("coral") if key == active else "transparent")
                    }}
                >
                    <NavIcon item={key}/>
                    {label}
                </a> for (key, label) in NAV_ITEMS
            ]}
        </nav>
    </div>
}
