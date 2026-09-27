"""Groups (plan 004 G6): the cohort group, topic groups the assistant made, and invites.

The list shows invites first (group name, why you were invited, Join or Dismiss), then the
student's groups with the latest message. A group screen is a group chat: the assistant's messages
carry an "Assistant" label, a topic group shows the live offers and requests filed there, and a
market message in the cohort may get one follow-up question that only its sender sees. Screens
poll through `heartbeat` so the client's 60-second read cache never hides a new message.
"""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Card, Badge, Field }
import from market.screens.common { MarketTabs, PostSummary, query_param, go }
import from market.feed { heartbeat }
import from market.notify { unread_suggestions }
import from market.messages { FollowUp, Choice }
import from market.topics {
    my_groups,
    my_group_invites,
    group_view,
    post_in_group,
    answer_group_followup,
    join_topic_group,
    dismiss_topic_invite,
    close_group_post,
    leave_topic_group,
    GroupSummary,
    InviteView,
    GroupView,
    GroupMessageView,
    GroupPostResult,
    ActionOutcome
}

glob GROUP_POLL_MS: int = 4000;

def:pub InviteCard(
    inv: InviteView, onAnswer: Callable[[str, bool], None]
) -> JsxElement {
    <Card>
        <div
            style={{
                "display": "flex",
                "justifyContent": "space-between",
                "gap": space("2"),
                "alignItems": "baseline"
            }}
        >
            <strong>{inv.group_name}</strong>
            <Badge kind="ai" label="Assistant invite"/>
        </div>
        <span style={{"color": color("text-2")}}>{inv.reason}</span>
        <span style={{"color": color("sub"), "fontSize": "14px"}}>
            {str(inv.members) + (" member" if inv.members == 1 else " members")}
        </span>
        <div style={{"display": "flex", "gap": space("2")}}>
            <Button
                label="Join"
                onClick={lambda (e: MouseEvent) { onAnswer(inv.id, True); }}
            />
            <Button
                label="Dismiss"
                variant="text"
                onClick={lambda (e: MouseEvent) { onAnswer(inv.id, False); }}
            />
        </div>
    </Card>
}

def:pub GroupList -> JsxElement {
    has groups: list[GroupSummary] = [],
        invites: list[InviteView] = [],
        unread: int = 0,
        loaded: bool = False;

    async def load -> None;
    async def answer(invite_id: str, accept: bool) -> None;

    can with entry {
        load();
        timer = setInterval(lambda { load(); }, GROUP_POLL_MS * 3);  # jac:ignore[W2001]
        return lambda { clearInterval(timer); };  # jac:ignore[W2001]
    }

    <AppShell title="Groups" active="market">
        <MarketTabs active="/market" unread={unread}/>
        {[<InviteCard key={inv.id} inv={inv} onAnswer={answer}/> for inv in invites]}
        {(
            <Card>
                <p style={{"margin": "0"}}>
                    Verify your UMich email in Profile to join your arrival group.
                </p>
            </Card>
        )
            if loaded and len(groups) == 0
            else None}
        {[
            <a
                key={g.id}
                href={"/market/g?id=" + g.id}
                style={{"textDecoration": "none", "color": color("text")}}
            >
                <Card>
                    <div
                        style={{
                            "display": "flex",
                            "justifyContent": "space-between",
                            "gap": space("2"),
                            "alignItems": "baseline"
                        }}
                    >
                        <strong>{g.name}</strong>
                        <span style={{"color": color("sub"), "fontSize": "14px"}}>
                            {str(g.members)
                                + (" member" if g.members == 1 else " members")}
                        </span>
                    </div>
                    <span style={{"color": color("sub")}}>
                        {g.last_message
                            or (
                                "Say hi, or drop a message about something you're buying, selling or looking for."
                                    if g.kind == "cohort"
                                    else "No messages yet."
                            )}
                    </span>
                </Card>
            </a> for g in groups
        ]}
    </AppShell>
}

impl GroupList.load -> None {
    fresh_groups: list[GroupSummary] = [];
    fresh_invites: list[InviteView] = [];
    count: int = 0;
    await heartbeat();
    fresh_groups = await my_groups();
    fresh_invites = await my_group_invites();
    count = await unread_suggestions();
    groups = fresh_groups;
    invites = fresh_invites;
    unread = count;
    loaded = True;
}

impl GroupList.answer(invite_id: str, accept: bool) -> None {
    result: ActionOutcome | None = None;
    if accept {
        result = await join_topic_group(invite_id);
        if result.ok {
            go("/market/g?id=" + result.group_id);
            return;
        }
    } else {
        await dismiss_topic_invite(invite_id);
    }
    await load();
}

"""One message bubble. The assistant's messages are labeled and link to the topic group."""
def:pub GroupBubble(m: GroupMessageView) -> JsxElement {
    <div
        style={{
            "alignSelf": "flex-end" if m.mine and not m.ai else "flex-start",
            "maxWidth": "85%",
            "display": "flex",
            "flexDirection": "column",
            "gap": space("1"),
            "padding": space("2") + " " + space("3"),
            "borderRadius": "16px",
            "background": color("action")
                if m.mine and not m.ai
                else (color("ai-bg") if m.ai else color("card")),
            "color": color("on-action") if m.mine and not m.ai else color("text"),
            "border": "1px solid " + color("border")
        }}
    >
        {<Badge kind="ai" label="Assistant"/>
            if m.ai
            else (
                <span style={{"fontSize": "13px", "fontWeight": "700"}}>
                    {m.author}
                </span>
                    if not m.mine
                    else None
            )}
        <span>{m.text}</span>
        {[
            <a
                key={l.group_id}
                href={"/market/g?id=" + l.group_id}
                style={{
                    "color": color("text"),
                    "display": "block",
                    "padding": space("1") + " 0"
                }}
            >
                {"Open " + l.name}
            </a> for l in m.links
        ]}
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
        confirm_leave: bool = False;

    async def load -> None;
    async def sendIt(e: MouseEvent) -> None;
    async def choose(value: str) -> None;
    async def settle(result: GroupPostResult) -> None;
    async def answerInvite(accept: bool) -> None;
    async def closePost(post_id: str, reason: str) -> None;
    async def leaveIt(e: MouseEvent) -> None;

    can with entry {
        group_id = query_param("id");
        load();
        timer = setInterval(lambda { load(); }, GROUP_POLL_MS);  # jac:ignore[W2001]
        return lambda { clearInterval(timer); };  # jac:ignore[W2001]
    }

    <AppShell title={group.name if group and group.ok else "Group"} active="market">
        <MarketTabs active="/market"/>
        {<Card>
            <p style={{"margin": "0"}}>{group.error}</p>
        </Card>
            if group and not group.ok
            else None}
        {<span style={{"color": color("sub")}}>
            {str(group.members) + (" member" if group.members == 1 else " members")}{" · Drop a message about something you're buying, selling or looking for, and the assistant will find people for it."
                if group.kind == "cohort"
                else ""}
        </span>
            if group and group.ok
            else None}
        {(
            <Card>
                <Badge kind="ai" label="Assistant invite"/>
                <span>{group.invite_reason}</span>
                <span style={{"color": color("sub"), "fontSize": "14px"}}>
                    Join to see the messages and the offers filed here.
                </span>
                <div style={{"display": "flex", "gap": space("2")}}>
                    <Button
                        label="Join"
                        onClick={lambda (e: MouseEvent) { answerInvite(True); }}
                    />
                    <Button
                        label="Dismiss"
                        variant="text"
                        onClick={lambda (e: MouseEvent) { answerInvite(False); }}
                    />
                </div>
            </Card>
        )
            if group and group.ok and not group.member
            else None}
        {(
            <Card>
                <div
                    style={{
                        "display": "flex",
                        "gap": space("2"),
                        "alignItems": "center"
                    }}
                >
                    <strong>Filed here</strong>
                    <Badge kind="ai" label="Kept by the assistant"/>
                </div>
                {<span style={{"color": color("sub")}}>Nothing open right now.</span>
                    if len(group.posts) == 0
                    else None}
                {[
                    <div
                        key={p.id}
                        style={{
                            "display": "flex",
                            "flexDirection": "column",
                            "gap": space("1"),
                            "paddingTop": space("2"),
                            "borderTop": "1px solid " + color("border")
                        }}
                    >
                        <PostSummary p={p}/>
                        {(
                            <div style={{"display": "flex", "gap": space("2")}}>
                                <Button
                                    label={"Sold" if p.kind == "offer" else "Found one"}
                                    variant="secondary"
                                    onClick={lambda (e: MouseEvent) { closePost(
                                        p.id, "sold" if p.kind == "offer" else "found"
                                    ); }}
                                />
                                <Button
                                    label="Withdraw"
                                    variant="text"
                                    onClick={lambda (e: MouseEvent) { closePost(
                                        p.id, "withdrawn"
                                    ); }}
                                />
                            </div>
                        )
                            if p.mine
                            else None}
                    </div> for p in group.posts
                ]}
            </Card>
        )
            if group and group.ok and group.member and group.kind == "topic"
            else None}
        {(
            <Card>
                <p style={{"margin": "0", "color": color("sub"), "fontSize": "14px"}}>
                    Meet somewhere public, bring a friend if you can, and never pay a deposit before you've seen a room or item.
                </p>
            </Card>
        )
            if group and group.ok and group.member and group.kind == "topic"
            else None}
        {[
            <GroupBubble key={m.id} m={m}/>
            for m in (group.messages if group and group.ok else [])
        ]}
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
                {<p role="alert" style={{"color": color("danger"), "margin": "0"}}>
                    {error}
                </p>
                    if error
                    else None}
            </Card>
        )
            if group and group.ok and group.member
            else None}
        {(
            <Card>
                {(
                    <div
                        style={{
                            "display": "flex",
                            "gap": space("2"),
                            "alignItems": "center"
                        }}
                    >
                        <span>Leave this group? You'll stop seeing its messages.</span>
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
            if group and group.ok and group.member and group.kind == "topic"
            else None}
    </AppShell>
}

impl GroupChat.load -> None {
    fresh: GroupView | None = None;
    await heartbeat();
    fresh = await group_view(group_id);
    group = fresh;
}

impl GroupChat.sendIt(e: MouseEvent) -> None {
    result: GroupPostResult | None = None;
    sending = True;
    result = await post_in_group(group_id, draft);
    sending = False;
    if not result.ok {
        error = result.error;
        return;
    }
    draft = "";
    error = "";
    answers = "";
    asked_message = result.message_id;
    await settle(result);
}

impl GroupChat.choose(value: str) -> None {
    result: GroupPostResult | None = None;
    answers = (answers + "|" + value) if answers else value;
    result = await answer_group_followup(asked_message, answers);
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

impl GroupChat.answerInvite(accept: bool) -> None {
    invite_id = group.invite_id if group else "";
    if accept {
        await join_topic_group(invite_id);
        await load();
        return;
    }
    await dismiss_topic_invite(invite_id);
    go("/market");
}

impl GroupChat.closePost(post_id: str, reason: str) -> None {
    await close_group_post(post_id, reason);
    await load();
}

impl GroupChat.leaveIt(e: MouseEvent) -> None {
    result: ActionOutcome | None = None;
    result = await leave_topic_group(group_id);
    if not result.ok {
        error = result.error;
        confirm_leave = False;
        return;
    }
    go("/market");
}
