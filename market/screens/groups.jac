"""Themed group chats (plan 2026-09-27-002).

The list shows the student's groups first, then every other theme with a Join button; a few are
marked "Suggested for you". A group screen is a group chat anyone signed in can read: members get a
composer, others a Join bar. Buy and sell messages carry Buying/Selling tags with their facts and
status, the assistant's notes are labelled, and a tagged message from someone else offers "Message
privately". Screens poll through `heartbeat` so the client's 60-second read cache never hides a
new message.
"""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Card, Badge, Field, ResponsiveGrid }
import from market.screens.common { MarketTabs, query_param, go }
import from market.feed { heartbeat }
import from market.threads { start_thread, ThreadResult }
import from market.notify { unread_suggestions }
import from market.messages { FollowUp, Choice }
import from market.themes {
    list_groups_for_me,
    group_view,
    post_in_group,
    answer_group_followup,
    join_group,
    leave_group,
    untag_group_message,
    close_group_post,
    answer_detail,
    GroupSummary,
    GroupView,
    GroupMessageView,
    TagView,
    GroupPostResult,
    ActionOutcome
}

glob GROUP_POLL_MS: int = 4000;

def:pub members_text(n: int) -> str {
    return str(n) + (" member" if n == 1 else " members");
}

"""One theme card in the list: icon, name, description or latest message, and Join for others."""
def:pub GroupCard(g: GroupSummary, onJoin: Callable[[str], None]) -> JsxElement {
    <Card>
        <a
            href={"/market/g?id=" + g.id}
            style={{
                "textDecoration": "none",
                "color": color("text"),
                "display": "flex",
                "flexDirection": "column",
                "gap": space("1")
            }}
        >
            <div
                style={{
                    "display": "flex",
                    "justifyContent": "space-between",
                    "gap": space("2"),
                    "alignItems": "baseline"
                }}
            >
                <strong>{g.icon + " " + g.name}</strong>
                <span style={{"color": color("sub"), "fontSize": "14px"}}>
                    {members_text(g.members)}
                </span>
            </div>
            {<Badge kind="action" label="Suggested for you"/> if g.suggested else None}
            <span style={{"color": color("sub")}}>
                {g.last_message if g.member and g.last_message else g.description}
            </span>
        </a>
        {<Button
            label="Join"
            variant="secondary"
            onClick={lambda (e: MouseEvent) { onJoin(g.id); }}
        />
            if not g.member
            else None}
    </Card>
}

def:pub GroupList -> JsxElement {
    has groups: list[GroupSummary] = [],
        unread: int = 0,
        loaded: bool = False;

    async def load -> None;
    async def joinIt(group_id: str) -> None;

    can with entry {
        load();
        timer = setInterval(lambda { load(); }, GROUP_POLL_MS * 3);  # jac:ignore[W2001]
        return lambda { clearInterval(timer); };  # jac:ignore[W2001]
    }

    mine = [
        g
        for g in groups
        if g.member
    ];
    others = [
        g
        for g in groups
        if not g.member
    ];

    <AppShell title="Groups" active="market" wide={True}>
        <MarketTabs active="/market" unread={unread}/>
        <p style={{"margin": "0", "color": color("sub")}}>
            Chat with students who trade the same things. Drop a message like "Selling my bike for $80" or "Looking for a used desk" and the assistant finds the people who want it.
        </p>
        {<h2 style={{"margin": "0", "fontSize": "18px"}}>Your groups</h2>
            if len(mine) > 0
            else None}
        {<ResponsiveGrid min="300px">
            {[<GroupCard key={g.id} g={g} onJoin={joinIt}/> for g in mine]}
        </ResponsiveGrid>
            if len(mine) > 0
            else None}
        {<h2 style={{"margin": "0", "fontSize": "18px"}}>
            {"More groups" if len(mine) > 0 else "Pick a few groups to join"}
        </h2>
            if len(others) > 0
            else None}
        <ResponsiveGrid min="300px">
            {[<GroupCard key={g.id} g={g} onJoin={joinIt}/> for g in others]}
        </ResponsiveGrid>
        {<Card>
            <p style={{"margin": "0"}}>Sign in with your UMich email to see groups.</p>
        </Card>
            if loaded and len(groups) == 0
            else None}
    </AppShell>
}

impl GroupList.load -> None {
    fresh: list[GroupSummary] = [];
    count: int = 0;
    await heartbeat();
    fresh = await list_groups_for_me();
    count = await unread_suggestions();
    groups = fresh;
    unread = count;
    loaded = True;
}

impl GroupList.joinIt(group_id: str) -> None {
    result: ActionOutcome | None = None;
    result = await join_group(group_id);
    if result.ok {
        go("/market/g?id=" + group_id);
        return;
    }
    await load();
}

def:pub is_live(t: TagView) -> bool {
    return t.status == "available" or t.status == "reserved";
}

"""One Buying/Selling tag: label, public status, the item, what the poster stated, and what the AI
only guessed (marked, never presented as fact)."""
def:pub TagLine(t: TagView) -> JsxElement {
    live = is_live(t);
    <div style={{"display": "flex", "flexDirection": "column", "gap": space("1")}}>
        <div
            style={{
                "display": "flex",
                "flexWrap": "wrap",
                "gap": space("1"),
                "alignItems": "center"
            }}
        >
            <Badge
                kind={"action" if t.kind == "selling" else "progress"}
                label={t.label}
            />
            <Badge
                kind={"neutral"
                    if not live
                    else ("warning" if t.status == "reserved" else "official")}
                label={t.status_label}
            />
            <strong
                style={{
                    "fontSize": "14px",
                    "textDecoration": "none" if live else "line-through"
                }}
            >
                {t.title}
            </strong>
        </div>
        {<span style={{"fontSize": "13px"}}>{"Stated: " + t.confirmed}</span>
            if t.confirmed
            else None}
        {(
            <span style={{"fontSize": "13px", "color": color("sub")}}>
                {"AI guess, not confirmed: " + t.guesses}
            </span>
        )
            if t.guesses
            else None}
    </div>
}

"""The owner's private assistant panel for one tag (M-R2, M-R3, M-R9): progress, focused
questions, matches with reasons and unknowns, and the private threads about it."""
def:pub OwnerPanel(
    t: TagView,
    onAnswer: Callable[[str, str, str], None],
    onInterest: Callable[[str, str, str, str], None]
) -> JsxElement {
    has price: str = "";

    <div
        style={{
            "display": "flex",
            "flexDirection": "column",
            "gap": space("2"),
            "padding": space("2"),
            "borderRadius": "12px",
            "background": color("ai-bg")
        }}
    >
        <Badge kind="ai" label="Assistant · only you see this"/>
        <span style={{"fontSize": "14px", "fontWeight": "700"}}>{t.owner_state}</span>
        {[
            <div
                key={q.field}
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("1")
                }}
            >
                <span style={{"fontSize": "14px"}}>{q.question}</span>
                <div style={{"display": "flex", "gap": space("1"), "flexWrap": "wrap"}}>
                    {[
                        <Button
                            key={c.value}
                            label={c.label}
                            variant="secondary"
                            onClick={lambda (e: MouseEvent) { onAnswer(
                                t.post_id, q.field, c.value
                            ); }}
                        /> for c in q.choices
                    ]}
                    <Button
                        label="Skip"
                        variant="text"
                        onClick={lambda (e: MouseEvent) { onAnswer(
                            t.post_id, q.field, "skip"
                        ); }}
                    />
                </div>
                {(
                    <div
                        style={{
                            "display": "flex",
                            "gap": space("1"),
                            "alignItems": "flex-end"
                        }}
                    >
                        <Field
                            label="Amount in $"
                            value={price}
                            onChange={lambda (v: str) { price = v; }}
                        />
                        <Button
                            label="Save"
                            disabled={not price.strip()}
                            onClick={lambda (e: MouseEvent) { onAnswer(
                                t.post_id, q.field, price
                            ); }}
                        />
                    </div>
                )
                    if q.input == "price"
                    else None}
            </div> for q in t.questions
        ]}
        {(<strong style={{"fontSize": "14px"}}>Your matches</strong>)
            if len(t.matches) > 0
            else None}
        {[
            <div
                key={mc.post_id}
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("1"),
                    "padding": space("2"),
                    "borderRadius": "12px",
                    "background": color("card"),
                    "border": "1px solid " + color("border")
                }}
            >
                <div
                    style={{
                        "display": "flex",
                        "gap": space("1"),
                        "alignItems": "center"
                    }}
                >
                    <Badge
                        kind={"action" if mc.label == "Selling" else "progress"}
                        label={mc.label}
                    />
                    <strong style={{"fontSize": "14px"}}>{mc.title}</strong>
                    <span style={{"fontSize": "13px", "color": color("sub")}}>
                        {"· " + mc.poster}
                    </span>
                </div>
                {<span style={{"fontSize": "13px"}}>{"Stated: " + mc.confirmed}</span>
                    if mc.confirmed
                    else None}
                {(
                    <span style={{"fontSize": "13px", "color": color("sub")}}>
                        {"AI guess, not confirmed: " + mc.guesses}
                    </span>
                )
                    if mc.guesses
                    else None}
                {(
                    <span style={{"fontSize": "13px", "color": color("progress")}}>
                        {"Why it fits: " + "; ".join(mc.reasons)}
                    </span>
                )
                    if len(mc.reasons) > 0
                    else None}
                {(
                    <span style={{"fontSize": "13px", "color": color("sub")}}>
                        {"Still unknown: " + ", ".join(mc.unknown)}
                    </span>
                )
                    if len(mc.unknown) > 0
                    else None}
                {<a
                    href={"/market/chat?id=" + mc.chat_id}
                    style={{"color": color("text")}}
                >
                    {"Open your thread · " + mc.thread_label}
                </a>
                    if mc.chat_id
                    else <Button
                        label={"I'm interested"
                            if mc.label == "Selling"
                            else "I have one"}
                        variant="secondary"
                        onClick={lambda (e: MouseEvent) { onInterest(
                            mc.post_id, t.post_id, mc.title, mc.poster
                        ); }}
                    />}
            </div> for mc in t.matches
        ]}
        {(<strong style={{"fontSize": "14px"}}>Private threads</strong>)
            if len(t.threads) > 0
            else None}
        {[
            <a
                key={l.chat_id}
                href={"/market/chat?id=" + l.chat_id}
                style={{"color": color("text"), "fontSize": "14px"}}
            >
                {"🔒 " + l.other_name + " · " + l.state_label}
            </a> for l in t.threads
        ]}
    </div>
}

"""One message bubble with its tags. Everyone sees the tag and its public status; the owner also
gets their private assistant panel and controls; others get "I'm interested"."""
def:pub GroupBubble(
    m: GroupMessageView,
    onClose: Callable[[str, str], None],
    onUntag: Callable[[str], None],
    onInterest: Callable[[str, str, str, str], None],
    onAnswer: Callable[[str, str, str], None]
) -> JsxElement {
    <div
        style={{
            "alignSelf": "flex-end" if m.mine else "flex-start",
            "maxWidth": "90%",
            "display": "flex",
            "flexDirection": "column",
            "gap": space("1"),
            "padding": space("2") + " " + space("3"),
            "borderRadius": "16px",
            "background": color("ai-bg") if m.ai else color("card"),
            "color": color("text"),
            "border": "1px solid "
                + (color("action") if m.mine and len(m.tags) == 0 else color("border"))
        }}
    >
        {<Badge kind="ai" label="Assistant"/>
            if m.ai
            else <span style={{"fontSize": "13px", "fontWeight": "700"}}>
                {m.author}
            </span>}
        <span style={{"whiteSpace": "pre-line"}}>{m.text}</span>
        {[
            <div
                key={t.post_id}
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("1"),
                    "paddingTop": space("1"),
                    "borderTop": "1px solid " + color("border")
                }}
            >
                <TagLine t={t}/>
                {<OwnerPanel t={t} onAnswer={onAnswer} onInterest={onInterest}/>
                    if t.mine
                    else None}
                {(
                    <div
                        style={{
                            "display": "flex",
                            "gap": space("2"),
                            "flexWrap": "wrap"
                        }}
                    >
                        <Button
                            label={"Sold" if t.kind == "selling" else "Found one"}
                            variant="secondary"
                            onClick={lambda (e: MouseEvent) { onClose(
                                t.post_id, "sold" if t.kind == "selling" else "found"
                            ); }}
                        />
                        <Button
                            label="No longer available"
                            variant="text"
                            onClick={lambda (e: MouseEvent) { onClose(
                                t.post_id, "withdrawn"
                            ); }}
                        />
                    </div>
                )
                    if t.mine and is_live(t)
                    else None}
                {<a
                    href={"/market/chat?id=" + t.my_chat}
                    style={{"color": color("text")}}
                >
                    Open your private thread
                </a>
                    if not t.mine and t.my_chat
                    else None}
                {<Button
                    label={t.interest_label}
                    variant="secondary"
                    onClick={lambda (e: MouseEvent) { onInterest(
                        t.post_id, "", t.title, m.author
                    ); }}
                />
                    if not t.mine and not t.my_chat and is_live(t)
                    else None}
            </div> for t in m.tags
        ]}
        {<Button
            label="It's just chat"
            variant="text"
            onClick={lambda (e: MouseEvent) { onUntag(m.id); }}
        />
            if m.mine
                and len(
                    [
                        t
                        for t in m.tags
                        if is_live(t)
                    ]
                )
                    > 0
            else None}
    </div>
}

def:pub GroupChat -> JsxElement {
    has group_id: str = "",
        group: GroupView | None = None,
        draft: str = "",
        error: str = "",
        sending: bool = False,
        asked: FollowUp | None = None,
        asked_message: str = "",
        notice: str = "",
        answers: str = "",
        pending: str = "",
        confirm_leave: bool = False,
        interest_post: str = "",
        interest_via: str = "",
        interest_title: str = "",
        interest_name: str = "";

    async def load -> None;
    async def sendIt(e: MouseEvent) -> None;
    async def choose(value: str) -> None;
    async def settle(result: GroupPostResult) -> None;
    async def joinIt(e: MouseEvent) -> None;
    async def closePost(post_id: str, reason: str) -> None;
    async def untagIt(message_id: str) -> None;
    async def startIt(e: MouseEvent) -> None;
    async def answerIt(post_id: str, field: str, value: str) -> None;
    async def leaveIt(e: MouseEvent) -> None;

    can with entry {
        group_id = query_param("id");
        load();
        timer = setInterval(lambda { load(); }, GROUP_POLL_MS);  # jac:ignore[W2001]
        return lambda { clearInterval(timer); };  # jac:ignore[W2001]
    }

    <AppShell
        title={(group.icon + " " + group.name) if group and group.ok else "Group"}
        active="market"
    >
        <MarketTabs active="/market"/>
        {<Card>
            <p style={{"margin": "0"}}>{group.error}</p>
        </Card>
            if group and not group.ok
            else None}
        {<span style={{"color": color("sub")}}>
            {members_text(group.members) + " · " + group.description}
        </span>
            if group and group.ok
            else None}
        {(
            <Card>
                <p style={{"margin": "0", "color": color("sub"), "fontSize": "14px"}}>
                    Meet somewhere public, bring a friend if you can, and never pay before you've seen the item or room.
                </p>
            </Card>
        )
            if group and group.ok
            else None}
        {<p style={{"margin": "0", "color": color("sub")}}>
            No messages yet. Say hi, or post what you're buying or selling.
        </p>
            if group and group.ok and len(group.messages) == 0
            else None}
        {[
            <GroupBubble
                key={m.id}
                m={m}
                onClose={closePost}
                onUntag={untagIt}
                onInterest={lambda (p: str, via: str, title: str, name: str) {
                    interest_post = p;
                    interest_via = via;
                    interest_title = title;
                    interest_name = name;
                }}
                onAnswer={answerIt}
            /> for m in (group.messages if group and group.ok else [])
        ]}
        {(
            <div
                style={{
                    "alignSelf": "flex-end",
                    "maxWidth": "85%",
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("1"),
                    "padding": space("2") + " " + space("3"),
                    "borderRadius": "16px",
                    "background": color("card"),
                    "border": "1px dashed " + color("border"),
                    "color": color("text")
                }}
            >
                <span style={{"fontSize": "13px", "fontWeight": "700"}}>You</span>
                <span>{pending}</span>
                <span style={{"fontSize": "13px", "color": color("sub")}}>
                    Sending · the assistant is reading it…
                </span>
            </div>
        )
            if pending
            else None}
        {(
            <Card>
                <strong>
                    {"Start a private thread with "
                        + interest_name
                        + " about \""
                        + interest_title
                        + "\"?"}
                </strong>
                <span>
                    {"🔒 Only you and "
                        + interest_name
                        + " can see it. Other group members and other interested students can't."}
                </span>
                <span style={{"color": color("sub"), "fontSize": "14px"}}>
                    The assistant will summarize the offer and request and suggest replies. Nothing is sent until you send it.
                </span>
                <div style={{"display": "flex", "gap": space("2")}}>
                    <Button label="Start private thread" onClick={startIt}/>
                    <Button
                        label="Cancel"
                        variant="text"
                        onClick={lambda (e: MouseEvent) { interest_post = ""; }}
                    />
                </div>
            </Card>
        )
            if interest_post
            else None}
        {(
            <Card>
                <Badge kind="ai" label="Assistant · only you see this"/>
                <span>{notice}</span>
            </Card>
        )
            if notice
            else None}
        {(
            <Card>
                <Badge kind="ai" label="Assistant · only you see this"/>
                <span>{asked.question}</span>
                <div style={{"display": "flex", "gap": space("2"), "flexWrap": "wrap"}}>
                    {[
                        <Button
                            key={c.value}
                            label={c.label}
                            variant="secondary"
                            onClick={lambda (e: MouseEvent) { choose(c.value); }}
                        /> for c in asked.choices
                    ]}
                    <Button
                        label="It's just chat"
                        variant="text"
                        onClick={lambda (e: MouseEvent) { asked = None; }}
                    />
                </div>
            </Card>
        )
            if asked
            else None}
        {<p role="alert" style={{"color": color("danger"), "margin": "0"}}>{error}</p>
            if error
            else None}
        {(
            <Card>
                <Field
                    label="Message"
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
            if group and group.ok and group.member
            else None}
        {(
            <Card>
                <span>You're reading this group. Join to post and get matched.</span>
                <Button label="Join group" onClick={joinIt}/>
            </Card>
        )
            if group and group.ok and not group.member
            else None}
        {(
            <Card>
                {(
                    <div
                        style={{
                            "display": "flex",
                            "gap": space("2"),
                            "alignItems": "center",
                            "flexWrap": "wrap"
                        }}
                    >
                        <span>Leave this group? You can join again any time.</span>
                        <Button label="Leave" variant="secondary" onClick={leaveIt}/>
                        <Button
                            label="Cancel"
                            variant="text"
                            onClick={lambda (e: MouseEvent) { confirm_leave = False; }}
                        />
                    </div>
                )
                    if confirm_leave
                    else <Button
                        label="Leave group"
                        variant="text"
                        onClick={lambda (e: MouseEvent) { confirm_leave = True; }}
                    />}
            </Card>
        )
            if group and group.ok and group.member
            else None}
    </AppShell>
}

impl GroupChat.load -> None {
    fresh: GroupView | None = None;
    # A send or an answer runs the assistant for several seconds in one transaction that reads
    # the student's profile; a heartbeat (a write to that profile) meanwhile makes it conflict
    # and retry. Skip polling until it returns.
    if sending {
        return;
    }
    await heartbeat();
    fresh = await group_view(group_id);
    group = fresh;
}

impl GroupChat.sendIt(e: MouseEvent) -> None {
    result: GroupPostResult | None = None;
    sending = True;
    pending = draft;
    draft = "";
    try {
        result = await post_in_group(group_id, pending);
    } except Exception {
        error = "Couldn't send that. Please try again.";
        draft = pending;
        return;
    } finally {
        sending = False;
        pending = "";
    }
    if result is None {
        return;
    }
    if not result.ok {
        error = result.error;
        return;
    }
    error = "";
    answers = "";
    asked_message = result.message_id;
    await settle(result);
}

impl GroupChat.choose(value: str) -> None {
    result: GroupPostResult | None = None;
    answers = (answers + "|" + value) if answers else value;
    sending = True;
    try {
        result = await answer_group_followup(asked_message, answers);
    } finally {
        sending = False;
    }
    if result is None {
        return;
    }
    if not result.ok {
        error = result.error;
        asked = None;
        return;
    }
    await settle(result);
}

"""After a send or an answer: keep asking if the assistant still needs something, else refresh."""
impl GroupChat.settle(result: GroupPostResult) -> None {
    notice = result.notice;
    asked = result.follow_up;
    await load();
}

impl GroupChat.joinIt(e: MouseEvent) -> None {
    await join_group(group_id);
    await load();
}

impl GroupChat.closePost(post_id: str, reason: str) -> None {
    await close_group_post(post_id, reason);
    await load();
}

impl GroupChat.untagIt(message_id: str) -> None {
    await untag_group_message(message_id);
    await load();
}

impl GroupChat.startIt(e: MouseEvent) -> None {
    result: ThreadResult | None = None;
    result = await start_thread(interest_post, interest_via, "", "");
    interest_post = "";
    if result is None {
        return;
    }
    if not result.ok {
        error = result.error;
        return;
    }
    go("/market/chat?id=" + result.chat_id);
}

impl GroupChat.answerIt(post_id: str, field: str, value: str) -> None {
    result: ActionOutcome | None = None;
    result = await answer_detail(post_id, field, value);
    if result is None {
        return;
    }
    error = "" if result.ok else result.error;
    await load();
}

impl GroupChat.leaveIt(e: MouseEvent) -> None {
    result: ActionOutcome | None = None;
    result = await leave_group(group_id);
    if not result.ok {
        error = result.error;
        confirm_leave = False;
        return;
    }
    go("/market");
}
