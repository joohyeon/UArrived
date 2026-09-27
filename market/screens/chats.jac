"""Chats (R9, R11, R16): the list of connected pairs and one thread. Threads poll every few
seconds through `heartbeat` (a write) so the client's 60-second read cache never hides a new
message. Closed chats are read-only."""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Card, Badge, Field }
import from market.screens.common { MarketTabs, query_param, go, ReportBox }
import from market.moderation { report_chat, block_in_chat }
import from market.connect {
    list_my_chats,
    read_chat,
    send_message,
    ChatView,
    ChatThread,
    MessageView,
    SendResult
}
import from market.feed { heartbeat }

glob THREAD_POLL_MS: int = 4000;

def:pub ChatList -> JsxElement {
    has chats: list[ChatView] = [],
        loaded: bool = False;

    async def load -> None;

    can with entry {
        load();
    }

    <AppShell title="Chats" active="market">
        <MarketTabs active="/market/chats"/>
        {(
            <Card>
                <p style={{"margin": "0"}}>
                    No chats yet. A chat opens when you and another student both tap Connect on a match.
                </p>
            </Card>
        )
            if loaded and len(chats) == 0
            else None}
        {[
            <a
                key={c.id}
                href={"/market/chat?id=" + c.id}
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
                        <strong>{c.other_post_title}</strong>
                        {<Badge kind="warning" label="Closed"/> if not c.open else None}
                    </div>
                    <span style={{"color": color("sub")}}>
                        {("For your post: " + c.my_post_title)
                            if c.my_post_title
                            else "About their post"}
                    </span>
                    {<span style={{"color": color("text-2")}}>{c.last_message}</span>
                        if c.last_message
                        else None}
                </Card>
            </a> for c in chats
        ]}
    </AppShell>
}

impl ChatList.load -> None {
    fresh: list[ChatView] = [];
    await heartbeat();
    fresh = await list_my_chats();
    chats = fresh;
    loaded = True;
}

def:pub ChatScreen -> JsxElement {
    has chat_id: str = "",
        thread: ChatThread | None = None,
        draft: str = "",
        error: str = "";

    async def load -> None;
    async def sendIt(e: MouseEvent) -> None;
    async def blockThem -> None;

    can with entry {
        chat_id = query_param("id");
        load();
        timer = setInterval(lambda { load(); }, THREAD_POLL_MS);  # jac:ignore[W2001]
        return lambda { clearInterval(timer); };  # jac:ignore[W2001]
    }

    <AppShell
        title={thread.chat.other_post_title if thread and thread.chat else "Chat"}
        active="market"
    >
        <MarketTabs active="/market/chats"/>
        {<Card>
            <p style={{"margin": "0"}}>{thread.error}</p>
        </Card>
            if thread and not thread.ok
            else None}
        {(
            <Card>
                <p style={{"margin": "0", "color": color("sub"), "fontSize": "14px"}}>
                    Meet somewhere public, bring a friend if you can, and never pay a deposit before you've seen a room or item. For rides, share your trip with someone you trust.
                </p>
            </Card>
        )
            if thread and thread.ok
            else None}
        {[
            <div
                key={str(i)}
                style={{
                    "alignSelf": "flex-end" if m.mine else "flex-start",
                    "maxWidth": "80%",
                    "padding": space("2") + " " + space("3"),
                    "borderRadius": "16px",
                    "background": color("action") if m.mine else color("card"),
                    "color": color("on-action") if m.mine else color("text"),
                    "border": "1px solid " + color("border")
                }}
            >
                {m.text}
            </div> for (i, m) in enumerate(thread.messages if thread else [])
        ]}
        {(
            <Card>
                <Field
                    label="Message"
                    value={draft}
                    onChange={lambda (v: str) { draft = v; }}
                />
                <Button label="Send" disabled={not draft.strip()} onClick={sendIt}/>
                {<p role="alert" style={{"color": color("danger"), "margin": "0"}}>
                    {error}
                </p>
                    if error
                    else None}
            </Card>
        )
            if thread and thread.ok and thread.chat and thread.chat.open
            else None}
        {(
            <Card>
                <p style={{"margin": "0"}}>
                    This post is closed, so the chat is read-only.
                </p>
            </Card>
        )
            if thread and thread.ok and thread.chat and not thread.chat.open
            else None}
        {(
            <Card>
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
            if thread and thread.ok
            else None}
    </AppShell>
}

impl ChatScreen.load -> None {
    fresh: ChatThread | None = None;
    await heartbeat();
    fresh = await read_chat(chat_id);
    thread = fresh;
}

impl ChatScreen.sendIt(e: MouseEvent) -> None {
    result: SendResult | None = None;
    result = await send_message(chat_id, draft);
    if not result.ok {
        error = result.error;
        return;
    }
    draft = "";
    error = "";
    await load();
}

impl ChatScreen.blockThem -> None {
    await block_in_chat(chat_id);
    go("/market/chats");
}
