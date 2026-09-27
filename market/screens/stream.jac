"""Market stream (plan 003 C6): a chat-style stream with the composer at the bottom.

Drop a message and it posts; if something important is unclear, the assistant asks one question
with tappable answers. Each bubble shows fact chips, availability and why it matches you.
"""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Badge }
import from market.screens.common { MarketTabs, go, price_text, when_text }
import from market.lifecycle { PostView }
import from market.messages {
    send_market_message,
    market_stream,
    MessageResult,
    StreamItem,
    FollowUp,
    Choice
}
import from market.feed { heartbeat }

glob STREAM_POLL_MS: int = 10000;

"""Small fact chips for a message: price, timing, area, availability and conditions."""
def:pub FactChips(p: PostView) -> JsxElement {
    chips = [
        x
        for x in [
            price_text(p),
            when_text(p),
            p.area,
            (p.route_from + " to " + p.route_to) if p.route_from else ""
        ]
        if x
    ];
    <div style={{"display": "flex", "gap": "6px", "flexWrap": "wrap"}}>
        {[<Badge key={c} kind="neutral" label={c}/> for c in chips]}{<Badge
            kind="progress"
            label="Available (confirmed)"
        />
            if p.availability == "confirmed"
            else None}{<Badge kind="warning" label="Availability not confirmed"/>
            if p.availability == "needs_checking"
            else None}{[
            <Badge key={c} kind="warning" label={c}/> for c in p.constraints
        ]}
    </div>
}

"""One message as a chat bubble: mine on the right, others on the left."""
def:pub Bubble(item: StreamItem) -> JsxElement {
    p = item.post;
    <a
        href={"/market/m?id=" + p.id}
        style={{
            "alignSelf": "flex-end" if p.mine else "flex-start",
            "maxWidth": "88%",
            "textDecoration": "none",
            "color": color("text"),
            "background": color("card"),
            "border": "1px solid " + (color("action") if p.mine else color("border")),
            "borderRadius": "16px",
            "padding": space("3"),
            "display": "flex",
            "flexDirection": "column",
            "gap": space("1")
        }}
    >
        <span style={{"fontSize": "13px", "color": color("sub")}}>
            {("You · " if p.mine else "")
                + ("Selling or offering" if p.kind == "offer" else "Looking for")}
        </span>
        <strong style={{"fontSize": "17px"}}>{p.title}</strong>
        <FactChips p={p}/>
        {<span style={{"color": color("progress"), "fontSize": "14px"}}>
            {"Fits your message: " + "; ".join(item.reasons)}
        </span>
            if len(item.reasons) > 0
            else None}
        <span style={{"color": color("sub"), "fontSize": "13px"}}>
            {(
                f"{item.replies} repl{'y' if item.replies == 1 else 'ies'}"
                    if item.replies
                    else "No replies yet"
            )
                + (f" · {item.unread} new for you" if item.unread else "")}
        </span>
    </a>
}

def:pub MarketStream -> JsxElement {
    has items: list[StreamItem] = [],
        loaded: bool = False,
        text: str = "",
        answers: list[str] = [],
        question: FollowUp | None = None,
        busy: bool = False,
        error: str = "";

    async def load -> None;
    async def sendIt -> None;
    async def choose(value: str) -> None;

    can with entry {
        load();
        timer = setInterval(lambda { load(); }, STREAM_POLL_MS);  # jac:ignore[W2001]
        return lambda { clearInterval(timer); };  # jac:ignore[W2001]
    }

    <AppShell title="Market" active="market">
        <MarketTabs active="/market"/>
        {(
            <p style={{"margin": "0", "color": color("text-2")}}>
                Say what you need or what you're selling, like you would in a group chat. We'll show it to students it fits.
            </p>
        )
            if loaded and len(items) == 0
            else None}
        <div style={{"display": "flex", "flexDirection": "column", "gap": space("2")}}>
            {[<Bubble key={i.post.id} item={i}/> for i in items]}
        </div>
        {(
            <div
                role="status"
                style={{
                    "alignSelf": "flex-start",
                    "maxWidth": "88%",
                    "background": color("ai-bg"),
                    "borderRadius": "16px",
                    "padding": space("3"),
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("2")
                }}
            >
                <Badge kind="ai" label="Assistant · automated"/>
                <span>{question.question}</span>
                <div style={{"display": "flex", "gap": space("2"), "flexWrap": "wrap"}}>
                    {[
                        <Button
                            key={c.value}
                            label={c.label}
                            variant="secondary"
                            disabled={busy}
                            onClick={lambda (e: MouseEvent) { choose(c.value); }}
                        /> for c in question.choices
                    ]}
                </div>
            </div>
        )
            if question
            else None}
        {<p role="alert" style={{"color": color("danger"), "margin": "0"}}>{error}</p>
            if error
            else None}
        <div
            style={{
                "position": "sticky",
                "bottom": "56px",
                "display": "flex",
                "gap": space("2"),
                "alignItems": "flex-end",
                "background": color("ground"),
                "paddingTop": space("2")
            }}
        >
            <label
                style={{
                    "flexGrow": "1",
                    "display": "flex",
                    "flexDirection": "column",
                    "fontSize": "13px",
                    "color": color("sub")
                }}
            >
                Message
                <textarea
                    rows={2}
                    value={text}
                    placeholder="I need a desk near campus this weekend · Selling my bike before I move next Friday"
                    onChange={lambda (e: ChangeEvent) { text = e.target.value; }}
                    style={{
                        "fontSize": "16px",
                        "padding": space("2"),
                        "borderRadius": "12px",
                        "border": "1px solid " + color("border-strong"),
                        "fontFamily": "inherit",
                        "resize": "none"
                    }}
                />
            </label>
            <Button
                label={"Sending..." if busy else "Send"}
                disabled={busy or not text.strip()}
                onClick={lambda (e: MouseEvent) { sendIt(); }}
            />
        </div>
    </AppShell>
}

impl MarketStream.load -> None {
    fresh: list[StreamItem] = [];
    await heartbeat();
    fresh = await market_stream();
    fresh.reverse();
    items = fresh;
    loaded = True;
}

impl MarketStream.sendIt -> None {
    result: MessageResult | None = None;
    busy = True;
    error = "";
    result = await send_market_message(text, "|".join(answers));
    busy = False;
    if not result.ok {
        error = result.error;
        return;
    }
    if result.follow_up is not None {
        question = result.follow_up;
        return;
    }
    go("/market/m?id=" + result.post_id);
}

impl MarketStream.choose(value: str) -> None {
    answers = answers + [value];
    question = None;
    await sendIt();
}
