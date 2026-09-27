"""Chats (R9, R11, R16): the list of connected pairs and one thread. Threads poll every few
seconds through `heartbeat` (a write) so the client's 60-second read cache never hides a new
message. Closed chats are read-only."""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Card, Badge, Field }
import from market.screens.common { MarketTabs, query_param, go, ReportBox, ui_labels }
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
import from core.profile { get_my_profile, ProfileView }

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
            if loaded and not chats
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
                        {"For your post: " + c.my_post_title}
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

"""One chat bubble. A message shown in the reader's language by AI translation carries the
AI-translated label and a See original toggle (local state only); `lang` is set to the language
actually shown."""
def:pub MessageBubble(m: MessageView) -> JsxElement {
    has show_original: bool = False;

    L = ui_labels(m.language);
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
        {(
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
                    label={L["hide_original"] if show_original else L["see_original"]}
                    variant="text"
                    onClick={lambda (e: MouseEvent) { show_original = not show_original; }}
                />
            </div>
        )
            if m.ai_translated
            else None}
        {(
            <span
                style={{
                    "paddingLeft": space("2"),
                    "borderLeft": "3px solid " + color("border-strong")
                }}
            >
                {m.original}
            </span>
        )
            if m.ai_translated and show_original
            else None}
    </div>
}

def:pub ChatScreen -> JsxElement {
    has chat_id: str = "",
        thread: ChatThread | None = None,
        draft: str = "",
        error: str = "",
        sending: bool = False,
        lang: str = "en";

    async def load -> None;
    async def sendIt(e: MouseEvent) -> None;
    async def blockThem -> None;

    async def loadLanguage -> None;

    can with entry {
        chat_id = query_param("id");
        loadLanguage();
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
            <MessageBubble key={str(i)} m={m}/>
            for (i, m) in enumerate(thread.messages if thread else [])
        ]}
        {(
            <Card>
                <Field
                    label="Message"
                    value={draft}
                    onChange={lambda (v: str) { draft = v; }}
                />
                <Button
                    label={ui_labels(lang)["translating"] if sending else "Send"}
                    disabled={sending or not draft.strip()}
                    onClick={sendIt}
                />
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

"""The reader's language, for the Send button's "Translating…" label."""
impl ChatScreen.loadLanguage -> None {
    me: ProfileView | None = None;
    me = await get_my_profile();
    lang = me.preferred_language or "en";
}

"""Send the draft. The button shows "Translating…" and stays disabled until the server answers,
so a slow translation cannot send the same message twice."""
impl ChatScreen.sendIt(e: MouseEvent) -> None {
    result: SendResult | None = None;
    if sending {
        return;
    }
    sending = True;
    result = await send_message(chat_id, draft);
    sending = False;
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
