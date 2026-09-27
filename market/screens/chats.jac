"""Private match threads (plan 2026-09-27-003): the list of the student's threads with their state,
and one thread. A thread shows who can see it, the group message it came from, its status, and a
labelled assistant panel: what each side offers or wants (AI guesses marked), what fits, what's
still unknown, and suggested replies that only fill the composer. Reserving, marking sold, closing
a request and leaving a thread each ask for confirmation first. Threads poll through `heartbeat`,
paused while a send is in flight so the write can't conflict with it."""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Card, Badge, Field, ResponsiveGrid }
import from market.screens.common {
    MarketTabs,
    query_param,
    go,
    ReportBox,
    TranslatedNote
}
import from market.moderation { report_chat, block_in_chat }
import from market.connect { MessageView, SendResult }
import from market.threads {
    list_threads,
    get_thread,
    thread_send,
    thread_action,
    ThreadItem,
    ThreadView,
    SideSummary,
    ThreadResult
}
import from market.feed { heartbeat }

glob THREAD_POLL_MS: int = 4000;

def:pub state_badge(state: str) -> str {
    if state == "completed" {
        return "progress";
    }
    if state == "unavailable" or state == "reserved_other" {
        return "neutral";
    }
    if state == "reserved" {
        return "action";
    }
    return "warning" if state == "your_turn" else "neutral";
}

def:pub ChatList -> JsxElement {
    has threads: list[ThreadItem] = [],
        loaded: bool = False;

    async def load -> None;

    can with entry {
        load();
    }

    <AppShell title="Chats" active="market" wide={True}>
        <MarketTabs active="/market/chats"/>
        <p style={{"margin": "0", "color": color("sub")}}>
            Private threads about a single item. Each one is visible only to you and the other student.
        </p>
        {(
            <Card>
                <p style={{"margin": "0"}}>
                    No threads yet. Tap "I'm interested" on a Selling message or a match to start one.
                </p>
            </Card>
        )
            if loaded and len(threads) == 0
            else None}
        <ResponsiveGrid min="320px">
            {[
                <a
                    key={t.id}
                    href={"/market/chat?id=" + t.id}
                    style={{"textDecoration": "none", "color": color("text")}}
                >
                    <Card>
                        <div
                            style={{
                                "display": "flex",
                                "justifyContent": "space-between",
                                "gap": space("2")
                            }}
                        >
                            <strong>{t.title}</strong>
                            <span style={{"color": color("sub"), "fontSize": "14px"}}>
                                {"🔒 with " + t.other_name}
                            </span>
                        </div>
                        <Badge kind={state_badge(t.state)} label={t.state_label}/>
                        {<span style={{"color": color("text-2")}}>
                            {t.last_message}
                        </span>
                            if t.last_message
                            else None}
                    </Card>
                </a> for t in threads
            ]}
        </ResponsiveGrid>
    </AppShell>
}

impl ChatList.load -> None {
    fresh: list[ThreadItem] = [];
    await heartbeat();
    fresh = await list_threads();
    threads = fresh;
    loaded = True;
}

"""One chat bubble. A message shown in the reader's language by AI translation carries the
AI-translated label and a See original toggle (TranslatedNote)."""
def:pub MessageBubble(m: MessageView) -> JsxElement {
    <div
        style={{
            "alignSelf": "flex-end" if m.mine else "flex-start",
            "maxWidth": "80%",
            "display": "flex",
            "flexDirection": "column",
            "gap": space("1"),
            "padding": space("2") + " " + space("3"),
            "borderRadius": "16px",
            "background": color("action") if m.mine else color("card"),
            "color": color("on-action") if m.mine else color("text"),
            "border": "1px solid " + color("border")
        }}
    >
        <span lang={m.language or None}>{m.text}</span>
        {<TranslatedNote
            lang={m.language}
            source_language={m.original_language}
            text={m.original}
        />
            if m.ai_translated
            else None}
    </div>
}

"""One side of the deal as the assistant reads it: confirmed facts, AI guesses, unknowns."""
def:pub SideBlock(s: SideSummary) -> JsxElement {
    <div style={{"display": "flex", "flexDirection": "column", "gap": space("1")}}>
        <span>
            <strong>{s.name + " · " + s.role + ": "}</strong>
            {s.title}
        </span>
        {<span style={{"fontSize": "14px"}}>{"Stated: " + s.confirmed}</span>
            if s.confirmed
            else None}
        {(
            <span style={{"fontSize": "14px", "color": color("sub")}}>
                {"AI guess, not confirmed: " + s.guesses}
            </span>
        )
            if s.guesses
            else None}
    </div>
}

"""The confirmation text for a thread action (M-R8): who gets told what."""
def:pub confirm_text(action: str, t: ThreadView) -> str {
    if action == "reserve" {
        return f"Reserve \"{t.title}\" for {t.other_name}? {t.other_name} will see it's held for them. Other interested students will only see \"Reserved for another student\".";
    }
    if action == "release" {
        return f"Release the reservation? \"{t.title}\" shows as available again.";
    }
    if action == "sell" {
        return f"Mark \"{t.title}\" sold to {t.other_name}? This completes the thread. Other interested students will see \"Sold to another student\".";
    }
    if action == "found" {
        return f"Close your request as found with {t.other_name}?";
    }
    return f"Close this thread? {t.other_name} won't be able to message you here any more.";
}

def:pub action_label(action: str, other: str) -> str {
    return {
        "reserve": "Reserve for " + other,
        "release": "Release reservation",
        "sell": "Mark sold to " + other,
        "found": "I found it here",
        "withdraw": "Close thread"
    }.get(
        action, action
    );
}

def:pub ChatScreen -> JsxElement {
    has chat_id: str = "",
        thread: ThreadView | None = None,
        draft: str = "",
        error: str = "",
        sending: bool = False,
        confirming: str = "";

    async def load -> None;
    async def sendIt(e: MouseEvent) -> None;
    async def doAction(e: MouseEvent) -> None;
    async def blockThem -> None;

    can with entry {
        chat_id = query_param("id");
        load();
        timer = setInterval(lambda { load(); }, THREAD_POLL_MS);  # jac:ignore[W2001]
        return lambda { clearInterval(timer); };  # jac:ignore[W2001]
    }

    t = thread if thread is not None else ThreadView(ok=False);
    ok = t.ok;

    <AppShell title={t.title if ok else "Thread"} active="market">
        <MarketTabs active="/market/chats"/>
        {<Card>
            <p style={{"margin": "0"}}>{t.error}</p>
        </Card>
            if thread is not None and not t.ok
            else None}
        {(
            <Card>
                <strong>{"🔒 " + t.privacy}</strong>
                <span style={{"color": color("sub"), "fontSize": "14px"}}>
                    Other group members and other interested students can't see it.
                </span>
                {(
                    <a
                        href={"/market/g?id=" + t.group_id}
                        style={{"color": color("text"), "fontSize": "14px"}}
                    >
                        {"From " + t.group_name + ": \"" + t.origin_text + "\""}
                    </a>
                )
                    if t.group_id and t.origin_text
                    else None}
                <Badge kind={state_badge(t.state)} label={t.state_label}/>
            </Card>
        )
            if ok
            else None}
        {(
            <div
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("2"),
                    "padding": space("3"),
                    "borderRadius": "16px",
                    "background": color("ai-bg"),
                    "border": "1px solid " + color("border")
                }}
            >
                <Badge kind="ai" label="Assistant · for you only"/>
                {<SideBlock s={t.offer}/> if t.offer else None}
                {<SideBlock s={t.request}/> if t.request else None}
                {(
                    <div>
                        <strong style={{"fontSize": "14px"}}>Why it fits</strong>
                        <ul style={{"margin": "0", "paddingLeft": "20px"}}>
                            {[<li key={f}>{f}</li> for f in t.fits]}
                        </ul>
                    </div>
                )
                    if len(t.fits) > 0
                    else None}
                {(
                    <div>
                        <strong style={{"fontSize": "14px"}}>Still unknown</strong>
                        <ul style={{"margin": "0", "paddingLeft": "20px"}}>
                            {[<li key={q}>{q}</li> for q in t.open_questions]}
                        </ul>
                    </div>
                )
                    if len(t.open_questions) > 0
                    else None}
                {(
                    <div
                        style={{
                            "display": "flex",
                            "flexDirection": "column",
                            "gap": space("1")
                        }}
                    >
                        <span style={{"fontSize": "14px", "color": color("sub")}}>
                            Suggested replies: tap to edit, then send yourself.
                        </span>
                        <div
                            style={{
                                "display": "flex",
                                "gap": space("1"),
                                "flexWrap": "wrap"
                            }}
                        >
                            {[
                                <Button
                                    key={r}
                                    label={r}
                                    variant="secondary"
                                    onClick={lambda (e: MouseEvent) { draft = r; }}
                                /> for r in t.suggestions
                            ]}
                        </div>
                    </div>
                )
                    if len(t.suggestions) > 0 and t.can_send
                    else None}
            </div>
        )
            if ok
            else None}
        {[
            <MessageBubble key={str(i)} m={m}/>
            for (i, m) in enumerate(t.messages if ok else [])
        ]}
        {(
            <Card>
                <Field
                    label={"Message " + t.other_name}
                    value={draft}
                    onChange={lambda (v: str) { draft = v; }}
                />
                <Button
                    label={"Sending..." if sending else "Send"}
                    disabled={sending or not draft.strip()}
                    onClick={sendIt}
                />
            </Card>
        )
            if ok and t.can_send
            else None}
        {<p role="alert" style={{"color": color("danger"), "margin": "0"}}>{error}</p>
            if error
            else None}
        {(
            <Card>
                {(
                    <div
                        style={{
                            "display": "flex",
                            "flexDirection": "column",
                            "gap": space("2")
                        }}
                    >
                        <span>{confirm_text(confirming, t)}</span>
                        <div style={{"display": "flex", "gap": space("2")}}>
                            <Button label="Confirm" onClick={doAction}/>
                            <Button
                                label="Cancel"
                                variant="text"
                                onClick={lambda (e: MouseEvent) { confirming = ""; }}
                            />
                        </div>
                    </div>
                )
                    if confirming
                    else (
                        <div
                            style={{
                                "display": "flex",
                                "gap": space("2"),
                                "flexWrap": "wrap"
                            }}
                        >
                            {[
                                <Button
                                    key={a}
                                    label={action_label(a, t.other_name)}
                                    variant={"text" if a == "withdraw" else "secondary"}
                                    onClick={lambda (e: MouseEvent) { confirming = a; }}
                                /> for a in t.actions
                            ]}
                        </div>
                    )}
            </Card>
        )
            if ok and len(t.actions) > 0
            else None}
        {(
            <Card>
                <p style={{"margin": "0", "color": color("sub"), "fontSize": "14px"}}>
                    Meet somewhere public, bring a friend if you can, and never pay before you've seen the item. For rides, share your trip with someone you trust.
                </p>
                <ReportBox
                    onSubmit={lambda (r: str) { return report_chat(chat_id, r); }}
                    label="Report this conversation"
                />
                <Button
                    label="Block this student"
                    variant="text"
                    onClick={lambda (e: MouseEvent) { blockThem(); }}
                />
            </Card>
        )
            if ok
            else None}
    </AppShell>
}

impl ChatScreen.load -> None {
    fresh: ThreadView | None = None;
    if sending {
        return;
    }
    await heartbeat();
    fresh = await get_thread(chat_id);
    thread = fresh;
}

impl ChatScreen.sendIt(e: MouseEvent) -> None {
    result: SendResult | None = None;
    if sending {
        return;
    }
    sending = True;
    try {
        result = await thread_send(chat_id, draft);
    } except Exception {
        error = "Couldn't send that. Please try again.";
        return;
    } finally {
        sending = False;
    }
    if result is None {
        return;
    }
    if not result.ok {
        error = result.error;
        return;
    }
    draft = "";
    error = "";
    await load();
}

impl ChatScreen.doAction(e: MouseEvent) -> None {
    result: ThreadResult | None = None;
    action = confirming;
    confirming = "";
    result = await thread_action(chat_id, action);
    if result is None {
        return;
    }
    error = "" if result.ok else result.error;
    await load();
}

impl ChatScreen.blockThem -> None {
    await block_in_chat(chat_id);
    go("/market/chats");
}
