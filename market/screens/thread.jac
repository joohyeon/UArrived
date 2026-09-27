"""A message's thread (plan 003 C6). Poster: assistant notes, every reply with Answer / Accept,
Still available and Close. Others: counts, their own exchange, and React / Ask / Make an offer.
Replies are private to the poster and their author."""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Card, Badge, Field }
import from market.screens.common { MarketTabs, query_param, go, ReportBox }
import from market.screens.stream { FactChips }
import from market.messages {
    message_thread,
    react_to_message,
    ask_about_message,
    offer_on_message,
    answer_reply,
    accept_reply,
    confirm_available,
    apply_assistant_choice,
    close_message,
    ThreadView,
    ActionResult,
    ReplyView,
    NoteView
}
import from market.moderation { report_post }
import from market.feed { heartbeat }

glob THREAD_POLL_MS: int = 6000;

def reply_label(r: ReplyView) -> str {
    who = "You" if r.mine else "Student";
    if r.kind == "interested" {
        return f"{who}: interested";
    }
    if r.kind == "available" {
        return f"{who}: is it still available?";
    }
    if r.kind == "offer" {
        amount = f"${r.offer_price:,.0f}" if r.offer_price is not None else "";
        return f"{who} offered {amount}" + (f": {r.text}" if r.text else "");
    }
    return f"{who}: {r.text}";
}

def:pub AssistantBubble(note: NoteView, onChoose: Callable[[str], None]) -> JsxElement {
    <div
        style={{
            "background": color("ai-bg"),
            "borderRadius": "16px",
            "padding": space("3"),
            "display": "flex",
            "flexDirection": "column",
            "gap": space("2")
        }}
    >
        <Badge
            kind="ai"
            label={"Assistant · automated"
                + (" · follow-up" if note.kind == "nudge" else "")}
        />
        <span>{note.text}</span>
        {[
            <a
                key={it.post.id}
                href={"/market/m?id=" + it.post.id}
                style={{
                    "color": color("text"),
                    "textDecoration": "none",
                    "background": color("card"),
                    "borderRadius": "12px",
                    "padding": space("2"),
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": "4px"
                }}
            >
                <strong>{it.post.title}</strong>
                <FactChips p={it.post}/>
                {<span style={{"color": color("warning"), "fontSize": "13px"}}>
                    {"Good to know: " + "; ".join(it.post.limitations)}
                </span>
                    if len(it.post.limitations) > 0
                    else None}
            </a> for it in note.items
        ]}
        <div style={{"display": "flex", "gap": space("2"), "flexWrap": "wrap"}}>
            {[
                <Button
                    key={c.value}
                    label={c.label}
                    variant="secondary"
                    onClick={lambda (e: MouseEvent) { onChoose(c.value); }}
                /> for c in note.choices
            ]}
        </div>
    </div>
}

def:pub MessageThread -> JsxElement {
    has post_id: str = "",
        view: ThreadView | None = None,
        question: str = "",
        offer_amount: str = "",
        offer_note: str = "",
        answers: dict[str, str] = {},
        status: str = "";

    async def load -> None;
    async def act(result_promise: any) -> None;
    async def accept(reply_id: str) -> None;

    can with entry {
        post_id = query_param("id");
        load();
        timer = setInterval(lambda { load(); }, THREAD_POLL_MS);  # jac:ignore[W2001]
        return lambda { clearInterval(timer); };  # jac:ignore[W2001]
    }

    def setAnswer(reply_id: str, value: str) {
        updated = dict(answers);
        updated[reply_id] = value;
        answers = updated;
    }

    post = view.post if view is not None and view.ok else None;
    is_mine = post is not None and post.mine;
    is_offer = post is not None and post.kind == "offer";
    is_live = post is not None and post.status == "live";
    <AppShell
        title={view.post.title if view and view.post else "Message"}
        active="market"
    >
        <MarketTabs active="/market"/>
        {<Card>
            <p style={{"margin": "0"}}>{view.error}</p>
        </Card>
            if view and not view.ok
            else None}
        {<p role="status" style={{"margin": "0", "color": color("sub")}}>{status}</p>
            if status
            else None}
        {(
            <Card>
                <span style={{"fontSize": "13px", "color": color("sub")}}>
                    {("Your message · " if view.post.mine else "")
                        + ("Selling or offering" if is_offer else "Looking for")}
                </span>
                <FactChips p={view.post}/>
                {<p style={{"margin": "0", "color": color("text-2")}}>
                    {view.post.description}
                </p>
                    if view.post.description
                    else None}
                {<Badge kind="ai" label="Details extracted by AI"/>
                    if view.post.ai_generated
                    else None}
                {<span style={{"color": color("warning"), "fontSize": "14px"}}>
                    {"Good to know: " + "; ".join(view.post.limitations)}
                </span>
                    if len(view.post.limitations) > 0 and not view.post.mine
                    else None}
                <span style={{"color": color("sub"), "fontSize": "13px"}}>
                    {" · ".join([f"{n} {k}" for (k, n) in view.counts.items()])
                        or "No replies yet"}
                </span>
            </Card>
        )
            if view and view.ok and view.post
            else None}
        {[
            <AssistantBubble
                key={n.created_at}
                note={n}
                onChoose={lambda (v: str) { act(apply_assistant_choice(post_id, v)); }}
            /> for n in (view.notes if view and view.ok else [])
        ]}
        {[
            <Card key={r.id}>
                <span>{reply_label(r)}</span>
                {<Badge kind="progress" label="Accepted: chat open"/>
                    if r.accepted
                    else None}
                {(
                    <div
                        style={{
                            "display": "flex",
                            "flexDirection": "column",
                            "gap": space("2")
                        }}
                    >
                        <Field
                            label="Answer"
                            value={answers.get(r.id, "")}
                            onChange={lambda (v: str) { setAnswer(r.id, v); }}
                        />
                        <div
                            style={{
                                "display": "flex",
                                "gap": space("2"),
                                "flexWrap": "wrap"
                            }}
                        >
                            <Button
                                label="Send answer"
                                variant="secondary"
                                disabled={not answers.get(r.id, "").strip()}
                                onClick={lambda (e: MouseEvent) { act(
                                    answer_reply(r.id, answers.get(r.id, ""))
                                ); }}
                            />
                            <Button
                                label="Accept and chat"
                                onClick={lambda (e: MouseEvent) { accept(r.id); }}
                            />
                        </div>
                    </div>
                )
                    if is_mine and not r.mine and r.kind != "answer" and not r.accepted
                    else None}
            </Card> for r in (view.replies if view and view.ok else [])
        ]}
        {(
            <Card>
                <div style={{"display": "flex", "gap": space("2"), "flexWrap": "wrap"}}>
                    <Button
                        label="Still available"
                        variant="secondary"
                        onClick={lambda (e: MouseEvent) { act(
                            confirm_available(post_id)
                        ); }}
                    />
                    <Button
                        label={"Mark sold" if is_offer else "Mark found"}
                        variant="secondary"
                        onClick={lambda (e: MouseEvent) { act(
                            close_message(post_id, "sold" if is_offer else "found")
                        ); }}
                    />
                    <Button
                        label="Withdraw"
                        variant="text"
                        onClick={lambda (e: MouseEvent) { act(
                            close_message(post_id, "withdrawn")
                        ); }}
                    />
                </div>
            </Card>
        )
            if view
                and view.ok
                and view.post
                and view.post.mine
                and view.post.status == "live"
            else None}
        {(
            <Card>
                <div style={{"display": "flex", "gap": space("2"), "flexWrap": "wrap"}}>
                    <Button
                        label="Interested"
                        variant="secondary"
                        onClick={lambda (e: MouseEvent) { act(
                            react_to_message(post_id, "interested")
                        ); }}
                    />
                    {<Button
                        label="Still available?"
                        variant="secondary"
                        onClick={lambda (e: MouseEvent) { act(
                            react_to_message(post_id, "available")
                        ); }}
                    />
                        if is_offer
                        else None}
                </div>
                <Field
                    label="Ask a question"
                    value={question}
                    onChange={lambda (v: str) { question = v; }}
                />
                <Button
                    label="Send question"
                    variant="secondary"
                    disabled={not question.strip()}
                    onClick={lambda (e: MouseEvent) {
                        act(ask_about_message(post_id, question));
                        question = "";
                    }}
                />
                <div style={{"display": "flex", "gap": space("2")}}>
                    <Field
                        label={"Offer ($)" if is_offer else "I can sell it for ($)"}
                        value={offer_amount}
                        input_type="number"
                        onChange={lambda (v: str) { offer_amount = v; }}
                    />
                    <Field
                        label="Note (optional)"
                        value={offer_note}
                        onChange={lambda (v: str) { offer_note = v; }}
                    />
                </div>
                <Button
                    label="Make an offer"
                    disabled={not offer_amount.strip()}
                    onClick={lambda (e: MouseEvent) {
                        act(offer_on_message(post_id, float(offer_amount), offer_note));
                        offer_amount = "";
                        offer_note = "";
                    }}
                />
                <p style={{"margin": "0", "color": color("sub"), "fontSize": "13px"}}>
                    Only the poster sees your replies. Meet in public and never pay before you've seen it.
                </p>
                <ReportBox
                    onSubmit={lambda (r: str) { return report_post(post_id, r); }}
                />
            </Card>
        )
            if view
                and view.ok
                and view.post
                and not view.post.mine
                and view.post.status == "live"
            else None}
    </AppShell>
}

impl MessageThread.load -> None {
    fresh: ThreadView | None = None;
    await heartbeat();
    fresh = await message_thread(post_id);
    view = fresh;
}

impl MessageThread.act(result_promise: any) -> None {
    result: ActionResult | None = None;
    result = await result_promise;
    status = "" if result.ok else result.error;
    await load();
}

impl MessageThread.accept(reply_id: str) -> None {
    result: ActionResult | None = None;
    result = await accept_reply(reply_id);
    if result.ok {
        go("/market/chat?id=" + result.chat_id);
        return;
    }
    status = result.error;
}
