"""Shared pieces of the market screens: the market tab bar, a post summary, and small helpers."""

import from ui.tokens { color, space }
import from ui.components.base { Badge, Button, Field }
import from ui.components.blocks { TabStrip }
import from market.lifecycle { PostView }
import from market.constants { labels_for }

glob MARKET_TABS: list[tuple[str, str]] = [
         ("/market", "Groups"),
         ("/market/matches", "Matches"),
         ("/market/chats", "Chats"),
         ("/market/mine", "My posts")
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

"""A labeled <select> in the same style as Field."""
def:pub Choice(
    label: str,
    value: str,
    options: list[tuple[str, str]],
    onChange: Callable[[str], None],
    note: str = ""
) -> JsxElement {
    <label
        style={{
            "display": "flex",
            "flexDirection": "column",
            "gap": space("1"),
            "fontSize": "14px",
            "fontWeight": "600"
        }}
    >
        {label}
        <select
            value={value}
            onChange={lambda (e: ChangeEvent) { onChange(e.target.value); }}
            style={{
                "minHeight": "44px",
                "padding": "0 " + space("2"),
                "border": "1px solid " + color("border-strong"),
                "borderRadius": "8px",
                "background": color("card"),
                "color": color("text"),
                "fontSize": "16px"
            }}
        >
            {[<option key={v} value={v}>{t}</option> for (v, t) in options]}
        </select>
        {<span style={{"color": color("warning"), "fontWeight": "400"}}>{note}</span>
            if note
            else None}
    </label>
}

def:pub price_text(p: PostView) -> str {
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

def:pub when_text(p: PostView) -> str {
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

"""The market's own tab bar. Groups is the landing tab; the feed comes last."""
def:pub MarketTabs(active: str, unread: int = 0) -> JsxElement {
    items = [
        (path, label + (f" ({unread})" if path == "/market" and unread > 0 else ""))
        for (path, label) in MARKET_TABS
    ];
    <TabStrip items={items} active={active} label="Market"/>
}

"""The AI-translated label and a See original toggle (local state only) for text shown in `lang`
by AI translation; the toggle reveals the author's words (`title` in bold, then `text`) marked
with their `source_language`. Used by post summaries and chat bubbles."""
def:pub TranslatedNote(
    lang: str, source_language: str = "", title: str = "", text: str = ""
) -> JsxElement {
    has show: bool = False;

    L = labels_for(lang);
    <div style={{"display": "flex", "flexDirection": "column", "gap": space("1")}}>
        <div
            style={{
                "display": "flex",
                "gap": space("2"),
                "alignItems": "center",
                "flexWrap": "wrap"
            }}
        >
            <Badge kind="ai" label={L["ai_translated"]}/>
            <Button
                label={L["hide_original"] if show else L["see_original"]}
                variant="text"
                onClick={lambda (e: MouseEvent) { show = not show; }}
            />
        </div>
        {(
            <div
                lang={source_language or None}
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("1"),
                    "padding": space("2"),
                    "borderLeft": "3px solid " + color("border-strong"),
                    "color": color("text-2")
                }}
            >
                {<strong>{title}</strong> if title else None}{<span>{text}</span>
                    if text
                    else None}
            </div>
        )
            if show
            else None}
    </div>
}

"""Facts first (title, kind, price, dates, area, arrangement), then the poster's own words
under "Seller says" (design rule 6), with the AI-generated label when AI wrote them. A post
shown in the reader's language by AI translation carries the AI-translated label and a See
original toggle (TranslatedNote) revealing the poster's words. Text blocks set `lang` to the
language actually shown so screen readers pronounce it correctly."""
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
            <strong lang={p.language or None} style={{"fontSize": "18px"}}>
                {p.title}
            </strong>
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
            if len(facts) > 0
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
                <span lang={p.language or None}>{p.description}</span>{" "}
                {<Badge kind="ai" label="AI-generated"/> if p.ai_generated else None}
            </p>
        )
            if p.description
            else None}
        {<TranslatedNote
            lang={p.language}
            source_language={p.source_language}
            title={p.original_title}
            text={p.original_description}
        />
            if p.ai_translated
            else None}
    </div>
}

"""A small "Report" control built from ui components: opens a reason box, calls
`onSubmit(reason)` (which returns whether the report was filed) and only then confirms (R17)."""
def:pub ReportBox(onSubmit: Callable[[str], any], label: str = "Report") -> JsxElement {
    has open: bool = False,
        reason: str = "",
        sent: bool = False,
        failed: bool = False;

    async def submit(e: MouseEvent) -> None {
        ok: bool = False;
        if not reason.strip() {
            return;
        }
        ok = await onSubmit(reason);
        sent = ok;
        failed = not ok;
        open = not ok;
    }

    <div style={{"display": "flex", "flexDirection": "column", "gap": space("1")}}>
        {<span style={{"color": color("sub")}}>
            Thanks. A moderator will look at it.
        </span>
            if sent
            else None}{<span role="alert" style={{"color": color("danger")}}>
            We couldn't send that report. Try again.
        </span>
            if failed
            else None}{<Button
            label={label}
            variant="text"
            onClick={lambda (e: MouseEvent) { open = True; }}
        />
            if not open and not sent
            else None}{(
            <div
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("1")
                }}
            >
                <Field
                    label="What's wrong?"
                    value={reason}
                    multiline={True}
                    onChange={lambda (v: str) { reason = v; }}
                />
                <Button
                    label="Send report"
                    variant="secondary"
                    disabled={not reason.strip()}
                    onClick={submit}
                />
            </div>
        )
            if open
            else None}
    </div>
}
