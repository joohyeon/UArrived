"""Shared pieces of the market screens: the market tab bar, a post summary, and small helpers."""

import from ui.tokens { color, space }
import from ui.components.base { Badge }
import from market.lifecycle { PostView }

glob MARKET_TABS: list[tuple[str, str]] = [
         ("/market", "Matches"),
         ("/market/new", "New post"),
         ("/market/chats", "Chats"),
         ("/market/mine", "My posts"),
         ("/market/feed", "For you")
     ];

def:pub current_path -> str {
    return window.location.pathname;  # jac:ignore[E1032,E1002,W2001]
}

"""A query-string parameter from the current URL, or ""."""
def:pub query_param(name: str) -> str {
    params = new(URLSearchParams, window.location.search);  # jac:ignore[E1053]
    return params.get(name) or "";  # jac:ignore[E1032,E1002]
}

def:pub go(path: str) {
    window.location.assign(path);  # jac:ignore[E1032,W2001]
}

def price_text(p: PostView) -> str {
    if p.free {
        return "Free";
    }
    if p.price is None {
        return "";
    }
    amount = f"${p.price:,.0f}" if p.price == int(p.price) else f"${p.price:,.2f}";
    if p.category == "housing" {
        return amount + "/mo";
    }
    return ("Budget " + amount) if p.kind == "request" else amount;
}

def when_text(p: PostView) -> str {
    parts: list[str] = [];
    if p.available_from
        and p.available_until
        and p.available_from != p.available_until {
        parts.append(f"{p.available_from} to {p.available_until}");
    } elif p.available_from or p.available_until {
        parts.append(p.available_from or p.available_until);
    }
    if p.time_from {
        parts.append(p.time_from + (f"-{p.time_to}" if p.time_to else ""));
    }
    return " ".join(parts);
}

"""The market's own tab bar. The matches inbox is the landing tab; the feed comes last."""
def:pub MarketTabs(active: str, unread: int = 0) -> JsxElement {
    <nav
        aria-label="Market"
        style={{"display": "flex", "gap": space("2"), "flexWrap": "wrap"}}
    >
        {[
            <a
                key={path}
                href={path}
                aria-current={"page" if path == active else None}
                style={{
                    "padding": "6px 12px",
                    "borderRadius": "999px",
                    "textDecoration": "none",
                    "fontWeight": "700" if path == active else "400",
                    "background": color("card") if path == active else "none",
                    "border": "1px solid "
                        + (
                            color("border-strong")
                                if path == active
                                else color("border")
                        ),
                    "color": color("text")
                }}
            >
                {label + (f" ({unread})" if path == "/market" and unread > 0 else "")}
            </a> for (path, label) in MARKET_TABS
        ]}
    </nav>
}

"""Facts first (title, kind, price, dates, area, arrangement), then the poster's own words
under "Seller says" (design rule 6), with the AI-generated label when AI wrote them."""
def:pub PostSummary(p: PostView) -> JsxElement {
    facts = [
        x
        for x in [price_text(p), when_text(p), p.area]
        if x
    ];
    <div style={{"display": "flex", "flexDirection": "column", "gap": space("1")}}>
        <div
            style={{
                "display": "flex",
                "justifyContent": "space-between",
                "gap": space("2"),
                "alignItems": "baseline"
            }}
        >
            <strong style={{"fontSize": "18px"}}>{p.title}</strong>
            <span
                style={{
                    "color": color("sub"),
                    "fontSize": "13px",
                    "whiteSpace": "nowrap"
                }}
            >
                {"Offering" if p.kind == "offer" else "Looking for"}
            </span>
        </div>
        {<span style={{"color": color("sub")}}>{" · ".join(facts)}</span>
            if facts
            else None}
        {(
            <span style={{"color": color("sub")}}>
                {p.route_from + " to " + p.route_to}
            </span>
        )
            if p.route_from
            else None}
        {<Badge kind="official" label={p.arrangement.capitalize()}/>
            if p.arrangement
            else None}
        {(
            <p style={{"margin": "0", "color": color("warning")}}>
                <strong>
                    {"Seller says: " if p.kind == "offer" else "They say: "}
                </strong>
                {p.description}{" "}
                {<Badge kind="ai" label="AI-generated"/> if p.ai_generated else None}
            </p>
        )
            if p.description
            else None}
    </div>
}

"""A small "Report" control: opens a reason box and calls `onSubmit(reason)`. Used on posts
and in chats (R17)."""
def:pub ReportBox(
    onSubmit: Callable[[str], None], label: str = "Report"
) -> JsxElement {
    has open: bool = False,
        reason: str = "",
        sent: bool = False;

    def submit(e: MouseEvent) {
        if reason.strip() {
            onSubmit(reason);
            sent = True;
            open = False;
        }
    }

    <div style={{"display": "flex", "flexDirection": "column", "gap": space("1")}}>
        {<span style={{"color": color("sub")}}>
            Thanks. A moderator will look at it.
        </span>
            if sent
            else None}{(
            <button
                type="button"
                onClick={lambda (e: MouseEvent) { open = True; }}
                style={{
                    "background": "none",
                    "border": "0",
                    "color": color("sub"),
                    "textDecoration": "underline",
                    "minHeight": "44px",
                    "textAlign": "left",
                    "cursor": "pointer"
                }}
            >
                {label}
            </button>
        )
            if not open and not sent
            else None}{(
            <div
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("1")
                }}
            >
                <label
                    style={{
                        "display": "flex",
                        "flexDirection": "column",
                        "gap": space("1"),
                        "fontSize": "14px"
                    }}
                >
                    What's wrong?
                    <textarea
                        rows={3}
                        value={reason}
                        onChange={lambda (e: ChangeEvent) { reason = e.target.value; }}
                        style={{
                            "fontSize": "16px",
                            "padding": space("2"),
                            "borderRadius": "8px",
                            "border": "1px solid " + color("border-strong")
                        }}
                    />
                </label>
                <button
                    type="button"
                    onClick={submit}
                    disabled={not reason.strip()}
                    style={{
                        "minHeight": "44px",
                        "borderRadius": "12px",
                        "border": "1px solid " + color("border-strong"),
                        "background": color("card"),
                        "color": color("danger"),
                        "fontWeight": "600"
                    }}
                >
                    Send report
                </button>
            </div>
        )
            if open
            else None}
    </div>
}
