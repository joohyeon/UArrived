"""Compose (R1-R5, R19): drop one message, review the AI draft, publish.

Two different signals on the draft, per the design review: each guessed field gets its own
"Guessed, please check" note, and the whole draft carries the AI-generated label. Nothing is
published until the student taps Publish. `?text=` pre-fills the message (journey prompts, U9).
"""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Card, Badge, Field }
import from core.constants { ANN_ARBOR_AREAS }
import from market.screens.common { MarketTabs, query_param, go }
import from market.drafting { draft_from_message, ride_prefill, DraftResult, DraftCard }
import from market.constants { ARRANGEMENTS, SAFETY_TIPS }
import from market.lifecycle { publish_post, PostResult }

def num_text(x: float | None) -> str {
    return "" if x is None else (f"{x:.0f}" if x == int(x) else f"{x}");
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

def:pub Compose -> JsxElement {
    has message: str = "",
        busy: bool = False,
        error: str = "",
        notice: str = "",
        draft: DraftCard | None = None,
        fields: dict[str, any] = {};

    can with entry {
        message = query_param("text");
        if query_param("prefill") == "ride" {
            loadRide();
        }
    }

    async def makeDraft(e: MouseEvent) -> None;
    async def loadRide -> None;
    def useDraft(result: DraftResult) -> None;
    async def publish(e: MouseEvent) -> None;

    def setField(name: str, value: any) {
        updated = dict(fields);
        updated[name] = value;
        fields = updated;
    }

    def guessNote(name: str) -> str {
        return "Guessed, please check." if draft and name in draft.guessed else "";
    }

    def missingNote(name: str) -> str {
        return "Missing: please add." if draft and name in draft.missing else "";
    }

    <AppShell title="New post" active="market">
        <MarketTabs active="/market/new"/>
        <Card>
            <Field
                label="What are you offering or looking for?"
                value={message}
                multiline={True}
                placeholder="selling a desk $25, pickup by Aug 25 · arriving DTW Aug 20 3pm, anyone sharing a ride?"
                onChange={lambda (v: str) { message = v; }}
            />
            <Button
                label={"Drafting..."
                    if busy
                    else ("Draft again" if draft else "Draft my post")}
                variant={"secondary" if draft else "primary"}
                disabled={busy or not message.strip()}
                onClick={makeDraft}
            />
            {<p role="status" aria-live="polite">Reading your message...</p>
                if busy
                else None}
            {<p role="alert" style={{"color": color("danger"), "margin": "0"}}>
                {error}
            </p>
                if error
                else None}
            {<p role="status" style={{"color": color("warning"), "margin": "0"}}>
                {notice}
            </p>
                if notice
                else None}
        </Card>
        {(
            <Card>
                <div
                    style={{
                        "display": "flex",
                        "justifyContent": "space-between",
                        "alignItems": "center"
                    }}
                >
                    <strong>Check your post</strong>
                    {<Badge kind="ai" label="AI-generated draft"/>
                        if draft.ai_generated
                        else None}
                </div>
                <Choice
                    label="Type"
                    value={fields.get("kind", "offer")}
                    options={[
                        ("offer", "I'm offering"),
                        ("request", "I'm looking for")
                    ]}
                    onChange={lambda (v: str) { setField("kind", v); }}
                />
                <Choice
                    label="Category"
                    value={fields.get("category", "furniture")}
                    options={[
                        ("furniture", "Furniture"),
                        ("essentials", "Essentials"),
                        ("housing", "Housing"),
                        ("vehicle", "Vehicle"),
                        ("service", "Ride or help")
                    ]}
                    onChange={lambda (v: str) { setField("category", v); }}
                />
                <Field
                    label="Title"
                    value={fields.get("title", "")}
                    onChange={lambda (v: str) { setField("title", v); }}
                />
                <Field
                    label={"Budget ($)"
                        if fields.get("kind") == "request"
                        else "Price ($)"}
                    value={fields.get("price_text", "")}
                    input_type="number"
                    hint={guessNote("price")
                        or missingNote("price")
                        or (
                            (
                                "Suggested: $"
                                + num_text(draft.suggested_price)
                                + ". "
                                + draft.price_reason
                            )
                                if draft.suggested_price is not None
                                else ""
                        )}
                    onChange={lambda (v: str) { setField("price_text", v); }}
                />
                <label
                    style={{
                        "display": "flex",
                        "gap": space("2"),
                        "alignItems": "center",
                        "minHeight": "44px"
                    }}
                >
                    <input
                        type="checkbox"
                        checked={fields.get("free", False)}
                        onChange={lambda (e: ChangeEvent) { setField(
                            "free", e.target.checked
                        ); }}
                    />
                    Free / giveaway
                </label>
                <Field
                    label="From"
                    value={fields.get("available_from", "")}
                    input_type="date"
                    hint={guessNote("available_from") or missingNote("available_from")}
                    onChange={lambda (v: str) { setField("available_from", v); }}
                />
                <Field
                    label="Until"
                    value={fields.get("available_until", "")}
                    input_type="date"
                    hint={guessNote("available_until")}
                    onChange={lambda (v: str) { setField("available_until", v); }}
                />
                {(
                    <div style={{"display": "flex", "gap": space("2")}}>
                        <Field
                            label="Time from"
                            value={fields.get("time_from", "")}
                            input_type="time"
                            hint={guessNote("time_from")}
                            onChange={lambda (v: str) { setField("time_from", v); }}
                        />
                        <Field
                            label="Time to"
                            value={fields.get("time_to", "")}
                            input_type="time"
                            onChange={lambda (v: str) { setField("time_to", v); }}
                        />
                    </div>
                )
                    if fields.get("category") == "service"
                    else None}
                {(
                    <div style={{"display": "flex", "gap": space("2")}}>
                        <Field
                            label="From (place)"
                            value={fields.get("route_from", "")}
                            onChange={lambda (v: str) { setField("route_from", v); }}
                        />
                        <Field
                            label="To (place)"
                            value={fields.get("route_to", "")}
                            onChange={lambda (v: str) { setField("route_to", v); }}
                        />
                    </div>
                )
                    if fields.get("category") == "service"
                    else None}
                <Choice
                    label="Area (approximate, never your address)"
                    value={fields.get("area", "")}
                    options={[("", "Not set")] + [(a, a) for a in ANN_ARBOR_AREAS]}
                    note={guessNote("area")}
                    onChange={lambda (v: str) { setField("area", v); }}
                />
                {(
                    <Choice
                        label="Arrangement"
                        value={fields.get("arrangement", "")}
                        options={[("", "Choose one")]
                            + [(a, a.capitalize()) for a in ARRANGEMENTS]}
                        note={missingNote("arrangement")}
                        onChange={lambda (v: str) { setField("arrangement", v); }}
                    />
                )
                    if fields.get("category") == "housing"
                    else None}
                <Field
                    label="Description (your words)"
                    value={fields.get("description", "")}
                    multiline={True}
                    onChange={lambda (v: str) { setField("description", v); }}
                />
                <p style={{"margin": "0", "color": color("sub"), "fontSize": "14px"}}>
                    {SAFETY_TIPS.get(
                        fields.get("category", ""), SAFETY_TIPS["furniture"]
                    )
                        + " UArrived never takes payments or signs leases."}
                </p>
                <Button label="Publish" full={True} disabled={busy} onClick={publish}/>
            </Card>
        )
            if draft
            else None}
    </AppShell>
}

impl Compose.makeDraft(e: MouseEvent) -> None {
    result: DraftResult | None = None;
    busy = True;
    error = "";
    result = await draft_from_message(message);
    busy = False;
    useDraft(result);
}

"""Open the pre-filled ride request from the journey's DTW prompt (U9). Nothing is posted yet."""
impl Compose.loadRide -> None {
    result: DraftResult | None = None;
    result = await ride_prefill(query_param("date"), query_param("time"));
    message = "Ride from DTW to Ann Arbor";
    useDraft(result);
}

impl Compose.useDraft(result: DraftResult) -> None {
    if not result.ok or result.draft is None {
        error = result.error;
        return;
    }
    d = result.draft;
    draft = d;
    notice = result.notice;
    fields = {
        "kind": d.kind,
        "category": d.category,
        "title": d.title,
        "description": d.description,
        "price_text": num_text(d.price),
        "free": d.free,
        "available_from": d.available_from,
        "available_until": d.available_until,
        "time_from": d.time_from,
        "time_to": d.time_to,
        "area": d.area,
        "route_from": d.route_from,
        "route_to": d.route_to,
        "arrangement": d.arrangement,
        "item": d.item,
        "ai_generated": d.ai_generated
    };
}

impl Compose.publish(e: MouseEvent) -> None {
    result: PostResult | None = None;
    out = dict(fields);
    text = str(out.pop("price_text", "")).strip();
    out["price"] = float(text) if text else None;
    busy = True;
    result = await publish_post(out);
    busy = False;
    if not result.ok {
        error = result.error;
        return;
    }
    go("/market/mine");
}
