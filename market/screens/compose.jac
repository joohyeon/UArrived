"""Compose (R1-R5, R19, R23, R25): drop one message, review the AI drafts, post.

The AI may return up to three drafts from one message (one per distinct thing). Each is its own
card, labeled in the language the student wrote in, with the English post preview others will
see, and is posted or discarded on its own. Two different signals on each card, per the design
review: each guessed field gets its own note, and the whole card carries the AI-generated label.
Nothing is published until the student taps Post; the button then shows "Translating…" and stays
disabled so a slow translation cannot produce a duplicate post. `?text=` pre-fills the message
(journey prompts, U9).
"""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Card, Badge, Field }
import from core.constants { ANN_ARBOR_AREAS }
import from market.screens.common { MarketTabs, query_param, go, Choice }
import from market.drafting { draft_from_message, ride_prefill, DraftResult, DraftCard }
import from market.constants {
    ARRANGEMENTS,
    SAFETY_TIPS,
    CATEGORY_NAMES,
    ARRANGEMENT_NAMES,
    labels_for,
    localized
}
import from market.lifecycle { publish_post, PostResult }

def num_text(x: float | None) -> str {
    return "" if x is None else (f"{x:.0f}" if x == int(x) else f"{x}");
}

"""The editable fields for one draft card."""
def:pub fields_of(d: DraftCard) -> dict[str, any] {
    return {
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
        "ai_generated": d.ai_generated,
        "language": d.language
    };
}

"""One draft card: field labels in the card's language, the English preview, guessed-field
notes, the AI-generated label, and its own Post and Discard buttons."""
def:pub DraftForm(
    card: DraftCard,
    fields: dict[str, any],
    onField: Callable[[str, any], None],
    onPost: Callable[[MouseEvent], None],
    onDiscard: Callable[[MouseEvent], None],
    posting: bool = False,
    locked: bool = False,
    error: str = "",
    number: int = 1,
    count: int = 1
) -> JsxElement {
    lang = card.language or "en";
    L = labels_for(lang);

    def guessNote(name: str) -> str {
        return L["guessed"] if name in card.guessed else "";
    }

    def missingNote(name: str) -> str {
        return "Missing: please add." if name in card.missing else "";
    }

    <Card>
        <div
            style={{
                "display": "flex",
                "justifyContent": "space-between",
                "alignItems": "center",
                "gap": space("2")
            }}
        >
            <strong>
                {"Check your post" + (f" ({number} of {count})" if count > 1 else "")}
            </strong>
            {<Badge kind="ai" label="AI-generated draft"/>
                if card.ai_generated
                else None}
        </div>
        <div
            lang={lang}
            style={{"display": "flex", "flexDirection": "column", "gap": space("3")}}
        >
            <Choice
                label={L["offer"] + " / " + L["request"]}
                value={fields.get("kind", "offer")}
                options={[("offer", L["offer"]), ("request", L["request"])]}
                onChange={lambda (v: str) { onField("kind", v); }}
            />
            <Choice
                label={L["category"]}
                value={fields.get("category", "furniture")}
                options={[
                    (c, localized(CATEGORY_NAMES, c, lang))
                    for c in CATEGORY_NAMES.keys()
                ]}
                onChange={lambda (v: str) { onField("category", v); }}
            />
            <Field
                label="Title"
                value={fields.get("title", "")}
                onChange={lambda (v: str) { onField("title", v); }}
            />
            <Field
                label={(L["budget"] if fields.get("kind") == "request" else L["price"])
                    + " ($)"}
                value={fields.get("price_text", "")}
                input_type="number"
                hint={guessNote("price")
                    or missingNote("price")
                    or (
                        (
                            "Suggested: $"
                            + num_text(card.suggested_price)
                            + ". "
                            + card.price_reason
                        )
                            if card.suggested_price is not None
                            else ""
                    )}
                onChange={lambda (v: str) { onField("price_text", v); }}
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
                    onChange={lambda (e: ChangeEvent) { onField(
                        "free", e.target.checked
                    ); }}
                />
                Free / giveaway
            </label>
            <div style={{"display": "flex", "gap": space("2")}}>
                <Field
                    label={L["dates"]}
                    value={fields.get("available_from", "")}
                    input_type="date"
                    hint={guessNote("available_from") or missingNote("available_from")}
                    onChange={lambda (v: str) { onField("available_from", v); }}
                />
                <Field
                    label={"→ " + L["dates"]}
                    value={fields.get("available_until", "")}
                    input_type="date"
                    hint={guessNote("available_until")}
                    onChange={lambda (v: str) { onField("available_until", v); }}
                />
            </div>
            {(
                <div style={{"display": "flex", "gap": space("2")}}>
                    <Field
                        label={L["time"]}
                        value={fields.get("time_from", "")}
                        input_type="time"
                        hint={guessNote("time_from")}
                        onChange={lambda (v: str) { onField("time_from", v); }}
                    />
                    <Field
                        label={"→ " + L["time"]}
                        value={fields.get("time_to", "")}
                        input_type="time"
                        onChange={lambda (v: str) { onField("time_to", v); }}
                    />
                </div>
            )
                if fields.get("category") == "service"
                else None}
            {(
                <div style={{"display": "flex", "gap": space("2")}}>
                    <Field
                        label={L["route"]}
                        value={fields.get("route_from", "")}
                        onChange={lambda (v: str) { onField("route_from", v); }}
                    />
                    <Field
                        label={"→ " + L["route"]}
                        value={fields.get("route_to", "")}
                        onChange={lambda (v: str) { onField("route_to", v); }}
                    />
                </div>
            )
                if fields.get("category") == "service"
                else None}
            <Choice
                label={L["area"]}
                value={fields.get("area", "")}
                options={[("", "—")] + [(a, a) for a in ANN_ARBOR_AREAS]}
                note={guessNote("area")}
                onChange={lambda (v: str) { onField("area", v); }}
            />
            {(
                <Choice
                    label={L["arrangement"]}
                    value={fields.get("arrangement", "")}
                    options={[("", "—")]
                        + [
                            (a, localized(ARRANGEMENT_NAMES, a, lang))
                            for a in ARRANGEMENTS
                        ]}
                    note={missingNote("arrangement")}
                    onChange={lambda (v: str) { onField("arrangement", v); }}
                />
            )
                if fields.get("category") == "housing"
                else None}
            <Field
                label="Description (your words)"
                value={fields.get("description", "")}
                multiline={True}
                onChange={lambda (v: str) { onField("description", v); }}
            />
        </div>
        {(
            <div
                lang="en"
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("1"),
                    "padding": space("3"),
                    "borderRadius": "8px",
                    "background": color("panel"),
                    "color": color("text")
                }}
            >
                <div
                    style={{
                        "display": "flex",
                        "justifyContent": "space-between",
                        "alignItems": "center",
                        "gap": space("2")
                    }}
                >
                    <span style={{"color": color("sub"), "fontSize": "14px"}}>
                        Others see (English)
                    </span>
                    <Badge kind="ai" label="AI-translated"/>
                </div>
                <strong>{card.title_en}</strong>
                {<span style={{"color": color("text-2")}}>{card.description_en}</span>
                    if card.description_en
                    else None}
                <span style={{"color": color("sub"), "fontSize": "13px"}}>
                    Your edits are translated again when you post.
                </span>
            </div>
        )
            if lang != "en" and card.title_en
            else None}
        <p style={{"margin": "0", "color": color("sub"), "fontSize": "14px"}}>
            {SAFETY_TIPS.get(fields.get("category", ""), SAFETY_TIPS["furniture"])
                + " UArrived never takes payments or signs leases."}
        </p>
        {<p role="alert" style={{"color": color("danger"), "margin": "0"}}>{error}</p>
            if error
            else None}
        <Button
            label={L["translating"] if posting else "Post"}
            full={True}
            disabled={posting or locked}
            onClick={onPost}
        />
        <Button
            label="Discard"
            variant="text"
            disabled={posting or locked}
            onClick={onDiscard}
        />
    </Card>
}

def:pub Compose -> JsxElement {
    has message: str = "",
        busy: bool = False,
        error: str = "",
        notice: str = "",
        drafts: list[DraftCard] = [],
        forms: list[dict[str, any]] = [],
        states: list[str] = [],
        errors: list[str] = [],
        posting: int = -1;

    can with entry {
        message = query_param("text");
        if query_param("prefill") == "ride" {
            loadRide();
        }
    }

    async def makeDraft(e: MouseEvent) -> None;
    async def loadRide -> None;
    def useDraft(result: DraftResult) -> None;
    async def publish(i: int) -> None;

    def setField(i: int, name: str, value: any) {
        updated = [f for f in forms];
        changed = dict(updated[i]);
        changed[name] = value;
        updated[i] = changed;
        forms = updated;
    }

    def putCardState(i: int, value: str) {
        updated = [s for s in states];
        updated[i] = value;
        states = updated;
    }

    def putCardError(i: int, value: str) {
        updated = [s for s in errors];
        updated[i] = value;
        errors = updated;
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
                    else ("Draft again" if drafts else "Draft my post")}
                variant={"secondary" if drafts else "primary"}
                disabled={busy or posting >= 0 or not message.strip()}
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
        {[
            (
                <DraftForm
                    key={str(i)}
                    card={c}
                    fields={forms[i]}
                    onField={lambda (n: str, v: any) { setField(i, n, v); }}
                    onPost={lambda (e: MouseEvent) { publish(i); }}
                    onDiscard={lambda (e: MouseEvent) { putCardState(i, "discarded"); }}
                    posting={posting == i}
                    locked={busy or posting >= 0}
                    error={errors[i]}
                    number={i + 1}
                    count={len(drafts)}
                />
            )
                if states[i] == ""
                else (
                    <Card key={str(i)}>
                        <p role="status" style={{"margin": "0"}}>
                            <strong lang={c.language or None}>
                                {forms[i]["title"]}
                            </strong>
                            {" is posted."}
                        </p>
                        <Button
                            label="See My posts"
                            variant="text"
                            onClick={lambda (e: MouseEvent) { go("/market/mine"); }}
                        />
                    </Card>
                )
                    if states[i] == "posted"
                    else None for (i, c) in enumerate(drafts)
        ]}
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
    cards = result.drafts or [result.draft];
    notice = result.notice;
    drafts = cards;
    forms = [fields_of(d) for d in cards];
    states = ["" for d in cards];
    errors = ["" for d in cards];
}

"""Post card `i`. The button shows "Translating…" and every card is locked until the server
answers, so one tap makes exactly one post. When no card is left open, go to My posts."""
impl Compose.publish(i: int) -> None {
    result: PostResult | None = None;
    if posting >= 0 {
        return;
    }
    out = dict(forms[i]);
    text = str(out.pop("price_text", "")).strip();
    out["price"] = float(text) if text else None;
    posting = i;
    putCardError(i, "");
    try {
        result = await publish_post(out);
    } except Exception {
        putCardError(i, "Couldn't post that. Please try again.");
        return;
    } finally {
        posting = -1;
    }
    if result is None {
        return;
    }
    if not result.ok {
        putCardError(i, result.error);
        return;
    }
    putCardState(i, "posted");
    left = [
        s
        for (j, s) in enumerate(states)
        if j != i and s == ""
    ];
    if not left {
        go("/market/mine");
    }
}
