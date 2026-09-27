"""Themed group chats (plan 2026-09-27-002).

A fixed set of groups (market/constants.jac THEMES) that every signed-in student can read and
join. Members chat normally. When the assistant recognizes a buy or sell message, the message stays
where it was written: the posts it becomes (the rules from market/lifecycle.jac) are linked to it
and shown as Buying/Selling tags, derived from the posts on every read. Matches in the same group
get one labelled assistant note under the message; matches anywhere are notified privately
(market/notify.jac). "Message privately" opens a one-to-one chat with a post's owner. The assistant
never invents people, items or counts.
"""

import from uuid { UUID }
import from jaclang { JacRuntime as Jac }
import from jaclang.server.identity.app_tokens { token_create }
import from core.auth { verified_profile }
import from core.clock { today_iso }
import from core.profile { Profile, my_profile }
import from core.groups {
    ChatGroup,
    GroupMessage,
    group_by_id,
    is_member,
    join,
    leave,
    ensure_group,
    add_message,
    messages_in,
    member_count
}
import from market.constants { THEMES }
import from market.graph {
    Post,
    Suggestion,
    all_posts,
    all_suggestions,
    post_status,
    visible_to,
    pair_key,
    blocked_keys,
    suspended_roots
}
import from market.drafting { make_draft }
import from market.lifecycle { publish, own_post, finish }
import from market.messages { blocking_question, fields_from, parse_answers, FollowUp }
import from market.matching { money, CHAT_OPEN_PURPOSE, CHAT_OPEN_TTL_SECONDS }
import from market.connect { ensure_chat }
import from market.items { category_for }

glob MAX_GROUP_MESSAGE_CHARS: int = 1000,
     MAX_NOTE_MATCHES: int = 3,
     MAX_SUGGESTED: int = 3,
     MARKET_WORDS: list[str] = [
         "sell",
         "selling",
         "sale",
         "buy",
         "buying",
         "looking for",
         "need",
         "free",
         "giveaway",
         "give away",
         "rent",
         "sublet",
         "sublease",
         "roommate",
         "lease",
         "ride",
         "uber",
         "lyft",
         "carpool",
         "$"
     ],
     STATUS_LABELS: dict[str, str] = {
         "sold": "Sold",
         "found": "Found",
         "withdrawn": "No longer available",
         "expired": "Expired",
         "hidden": "Removed"
     };

obj GroupPostResult {
    has ok: bool,
        error: str = "",
        notice: str = "",
        message_id: str = "",
        filed: bool = False,
        filed_count: int = 0,
        follow_up: FollowUp | None = None;
}

"""One Buying/Selling tag on a message: one post filed from it."""
obj TagView {
    has post_id: str,
        kind: str,
        label: str,
        title: str,
        facts: str,
        status: str,
        status_label: str,
        mine: bool;
}

obj GroupMessageView {
    has id: str,
        mine: bool,
        author: str,
        text: str,
        created_at: str,
        ai: bool,
        tags: list[TagView] = [];
}

obj GroupView {
    has ok: bool,
        error: str = "",
        id: str = "",
        key: str = "",
        name: str = "",
        icon: str = "",
        description: str = "",
        member: bool = False,
        members: int = 0,
        messages: list[GroupMessageView] = [];
}

obj GroupSummary {
    has id: str,
        key: str,
        name: str,
        icon: str,
        description: str,
        members: int,
        member: bool,
        suggested: bool,
        last_message: str,
        last_at: str;
}

obj ActionOutcome {
    has ok: bool,
        error: str = "",
        group_id: str = "",
        chat_id: str = "";
}

"""The catalog entry for a theme group ({} for anything else)."""
def theme_info(g: ChatGroup) -> dict[str, str] {
    for t in THEMES {
        if g.key == "theme:" + t["key"] {
            return t;
        }
    }
    return {};
}

"""Every theme group, in catalog order, created on first use (idempotent: `ensure_group` reuses a
group with the same key)."""
def theme_groups -> list[ChatGroup] {
    return [ensure_group("theme", "theme:" + t["key"], t["name"]) for t in THEMES];
}

"""Up to MAX_SUGGESTED theme keys for this student (R3), never one they've joined."""
def suggested_keys(p: Profile, joined: list[str]) -> list[str] {
    wanted: list[str] = [];
    if p.housing_status == "looking" {
        wanted.append("housing");
    }
    if p.needs_airport_ride {
        wanted.append("rides");
    }
    wanted.extend(["moveout", "furniture"]);
    return [
        k
        for k in wanted
        if k not in joined
    ][:MAX_SUGGESTED];
}

"""All theme groups: joined ones first (latest activity first), then the rest in catalog order."""
def list_groups(p: Profile) -> list[GroupSummary] {
    groups = theme_groups();
    joined_keys = [
        theme_info(g).get("key", "")
        for g in groups
        if is_member(g)
    ];
    suggested = suggested_keys(p, joined_keys);
    out: list[GroupSummary] = [];
    for g in groups {
        t = theme_info(g);
        msgs = messages_in(jid(g));
        out.append(
            GroupSummary(
                id=jid(g),
                key=t["key"],
                name=t["name"],
                icon=t["icon"],
                description=t["description"],
                members=member_count(g),
                member=is_member(g),
                suggested=t["key"] in suggested,
                last_message=msgs[-1].text if msgs else "",
                last_at=msgs[-1].created_at if msgs else ""
            )
        );
    }
    joined = [
        s
        for s in out
        if s.member
    ];
    joined.sort(
        key=lambda (s: GroupSummary) -> str { return s.last_at; }, reverse=True
    );
    return joined
        + [
            s
            for s in out
            if not s.member
        ];
}

"""A one-line summary of a post's facts, shown with its tag."""
def facts_line(p: Post) -> str {
    parts: list[str] = [];
    if p.free {
        parts.append("free");
    } elif p.price is not None {
        parts.append(("budget " if p.kind == "request" else "") + money(p.price));
    }
    when = p.available_from
        + (
            f" to {p.available_until}"
                if p.available_until and p.available_until != p.available_from
                else ""
        )
        if p.available_from
        else (f"until {p.available_until}" if p.available_until else "");
    parts.extend(
        [
            x
            for x in [when, p.time_from, p.area]
            if x
        ]
    );
    parts.extend(p.constraints);
    return " · ".join(parts);
}

"""Without AI: does the text look like a market message?"""
def looks_like_market(text: str) -> bool {
    t = text.lower();
    return any([w in t for w in MARKET_WORDS]);
}

def message_by_id(message_id: str) -> GroupMessage | None {
    for m in [root.shared-->][?:GroupMessage] {
        if jid(m) == message_id {
            return m;
        }
    }
    return None;
}

"""The status of a post as its tag shows it: live, sold, found, withdrawn, expired or hidden."""
def tag_status(p: Post, today: str) -> str {
    status = post_status(p, today);
    if status == "done" {
        return p.closed_reason or "sold";
    }
    return status;
}

def tag_view(p: Post, today: str, me: str) -> TagView {
    status = tag_status(p, today);
    return TagView(
        post_id=jid(p),
        kind="selling" if p.kind == "offer" else "buying",
        label="Selling" if p.kind == "offer" else "Buying",
        title=p.title,
        facts=facts_line(p),
        status=status,
        status_label=STATUS_LABELS.get(status, ""),
        mine=p.owner_root == me
    );
}

"""The assistant's note for newly filed posts (R11): up to MAX_NOTE_MATCHES live posts in the same
group that the matcher paired with them, each with its reason. "" and no posts when none fit."""
def note_for(filed: list[Post], g: ChatGroup, today: str) -> tuple[str, list[str]] {
    me = jid(root);
    posts: dict[str, Post] = {jid(p): p for p in visible_to(all_posts(), me)};
    ids = [jid(p) for p in filed];
    blocked = blocked_keys();
    lines: list[str] = [];
    matched: list[str] = [];
    for s in all_suggestions() {
        if s.origin != "match" or s.withdrawn or s.declined {
            continue;
        }
        if s.post_a not in ids and s.post_b not in ids {
            continue;
        }
        other = posts.get(s.post_b if s.post_a in ids else s.post_a);
        if other is None
            or jid(other) in matched
            or other.owner_root == me
            or other.topic_group_id != jid(g)
            or post_status(other, today) != "live"
            or pair_key(me, other.owner_root) in blocked {
            continue;
        }
        who = other.poster_name or "A student";
        doing = "is looking for this" if other.kind == "request" else "is offering one";
        lines.append(
            f"{who} {doing}: " + ("; ".join(s.reasons) if s.reasons else other.title)
        );
        matched.append(jid(other));
        if len(matched) >= MAX_NOTE_MATCHES {
            break;
        }
    }
    return ("\n".join(lines), matched);
}

"""File a group message into the market if it is about the market (R6-R8). When intent is unclear
it returns one follow-up question for the sender and files nothing."""
def file_market(
    g: ChatGroup, msg: GroupMessage, answers: str, today: str
) -> GroupPostResult {
    message_id = jid(msg);
    text = msg.text;
    drafted = make_draft(text, today, verified_profile());
    if not drafted.ok or drafted.draft is None {
        return GroupPostResult(ok=True, message_id=message_id);
    }
    card = drafted.draft;
    known = parse_answers(answers);
    # Clear market words ("selling", "looking for", "$40") count even when the model says chat;
    # a greeting it can't place is still caught below.
    about = (card.about_market if card.ai_generated else False)
        or looks_like_market(text);
    # A sentence whose kind and category are both guesses is chat, not a question; a bare item
    # name ("desk") still gets the question.
    unsure = card.ai_generated
        and "kind" in card.guessed
        and "category" in card.guessed
        and len(text.split()) > 3
        and not looks_like_market(text);
    if (not about or unsure) and not known {
        return GroupPostResult(ok=True, message_id=message_id);
    }
    question = blocking_question(card, known);
    if question is not None {
        return GroupPostResult(ok=True, message_id=message_id, follow_up=question);
    }
    # One post per distinct need the drafter found (#46). The answer to the question about the
    # first draft applies to the others only where they guessed the same field.
    items = [
        fields_from(
            c,
            known
                if i == 0
                else {
                    k: v
                    for (k, v) in known.items()
                    if k in c.guessed
                },
            text
        ) for (i, c) in enumerate(drafted.drafts or [card])
    ];
    for fields in items {
        # The drafter sometimes puts an item in a neighbouring category (a mattress as
        # essentials); the item list knows better. Only for messages the assistant files.
        fixed = category_for(fields["title"], fields["category"]);
        if fixed {
            fields["category"] = fixed;
        }
    }
    filed: list[Post] = [];
    failed: list[str] = [];
    last_error = "";
    for fields in items {
        result = publish(fields, today, ai_generated=card.ai_generated);
        post = own_post(result.post.id) if result.ok and result.post else None;
        if post is None {
            last_error = result.error or "it couldn't be saved";
            failed.append(f"\"{fields['title']}\" ({last_error})");
            continue;
        }
        post.topic_group_id = jid(g);
        filed.append(post);
    }
    notes: list[str] = [];
    if failed {
        notes.append("I couldn't file " + "; ".join(failed) + ".");
    }
    if drafted.dropped > 0 {
        notes.append(
            f"I filed the first {len(items)} items; post the other {drafted.dropped} in another message."
        );
    }
    notice = " ".join(notes);
    if not filed {
        return GroupPostResult(
            ok=True,
            message_id=message_id,
            notice=f"Your message is posted, but I couldn't file it for the market: {last_error}"
                if len(items) == 1
                else "Your message is posted, but " + notice
        );
    }
    msg.post_ids = [jid(p) for p in filed];
    msg.post_id = msg.post_ids[0];
    msg.untagged = False;
    (note, matched) = note_for(filed, g, today);
    if note {
        add_message(g, note, ai=True, post_ids=matched);
    }
    return GroupPostResult(
        ok=True,
        message_id=message_id,
        filed=True,
        filed_count=len(filed),
        notice=notice
    );
}

"""Post `text` in a theme group the caller has joined (R2, R5)."""
def post_message(group_id: str, text: str, today: str) -> GroupPostResult {
    g = group_by_id(group_id);
    if g is None or not theme_info(g) {
        return GroupPostResult(ok=False, error="That group isn't available.");
    }
    if not is_member(g) {
        return GroupPostResult(ok=False, error="Join the group to post.");
    }
    body = text.strip();
    if not body {
        return GroupPostResult(ok=False, error="Type a message.");
    }
    if len(body) > MAX_GROUP_MESSAGE_CHARS {
        return GroupPostResult(
            ok=False, error=f"Keep it under {MAX_GROUP_MESSAGE_CHARS} characters."
        );
    }
    msg = add_message(g, body);
    return file_market(g, msg, "", today);
}

"""Answer the assistant's follow-up question about one of the caller's messages (R8)."""
def answer_followup(message_id: str, answers: str, today: str) -> GroupPostResult {
    m = message_by_id(message_id);
    if m is None or m.author_root != jid(root) or m.ai or m.post_ids {
        return GroupPostResult(ok=False, error="That message isn't available.");
    }
    g = group_by_id(m.group_id);
    if g is None or not is_member(g) {
        return GroupPostResult(ok=False, error="That message isn't available.");
    }
    return file_market(g, m, answers, today);
}

"""A group as the caller sees it: readable by any signed-in student (R2), with tags derived from
each message's posts (R6, R9)."""
def view(group_id: str, today: str) -> GroupView {
    g = group_by_id(group_id);
    if g is None or not theme_info(g) {
        return GroupView(ok=False, error="That group isn't available.");
    }
    t = theme_info(g);
    me = jid(root);
    blocked = blocked_keys();
    hidden = suspended_roots();
    posts: dict[str, Post] = {jid(p): p for p in visible_to(all_posts(), me)};
    msgs: list[GroupMessageView] = [];
    for m in messages_in(group_id) {
        if not m.ai
            and m.author_root != me
            and (pair_key(me, m.author_root) in blocked or m.author_root in hidden) {
            continue;
        }
        tags = [
            tag_view(posts[pid], today, me)
            for pid in m.post_ids
            if pid in posts
        ]
            if not m.ai and not m.untagged
            else [];
        msgs.append(
            GroupMessageView(
                id=jid(m),
                mine=m.author_root == me and not m.ai,
                author="You" if m.author_root == me and not m.ai else m.author_name,
                text=m.text,
                created_at=m.created_at,
                ai=m.ai,
                tags=tags
            )
        );
    }
    return GroupView(
        ok=True,
        id=group_id,
        key=t["key"],
        name=t["name"],
        icon=t["icon"],
        description=t["description"],
        member=is_member(g),
        members=member_count(g),
        messages=msgs
    );
}

"""The author says a tagged message was just chat (R9): its posts are withdrawn and the tags go."""
def untag(message_id: str, today: str) -> ActionOutcome {
    m = message_by_id(message_id);
    if m is None or m.author_root != jid(root) or m.ai {
        return ActionOutcome(ok=False, error="You can only change your own messages.");
    }
    for pid in m.post_ids {
        p = own_post(pid);
        if p is not None and not p.done {
            finish(pid, today, "withdrawn");
        }
    }
    m.untagged = True;
    return ActionOutcome(ok=True, group_id=m.group_id);
}

"""Open (or reopen) a private chat with a post's owner (R13), like accepting a reply: a one-sided
"direct" suggestion both sides have accepted."""
def message_owner(post_id: str, today: str) -> ActionOutcome {
    me = jid(root);
    post: Post | None = None;
    for p in visible_to(all_posts(), me) {
        if jid(p) == post_id {
            post = p;
        }
    }
    if post is None {
        return ActionOutcome(ok=False, error="That message isn't available.");
    }
    if post.owner_root == me {
        return ActionOutcome(ok=False, error="That's your own message.");
    }
    if post_status(post, today) != "live" {
        return ActionOutcome(ok=False, error="This message is closed.");
    }
    s: Suggestion | None = None;
    for existing in all_suggestions() {
        if existing.origin == "direct"
            and existing.post_a == post_id
            and existing.root_b == me
            and not existing.declined {
            s = existing;
        }
    }
    if s is None {
        s = root.shared ++> Suggestion(
            post_a=post_id,
            post_b="",
            root_a=post.owner_root,
            root_b=me,
            score=0,
            reasons=[],
            created_on=today,
            accepted_a=True,
            accepted_b=True,
            seen_a=False,
            seen_b=True,
            emailed_a=True,
            emailed_b=True,
            origin="direct",
            from_name=my_profile().display_name or "A student"
        );
        s.open_token = token_create(
            CHAT_OPEN_PURPOSE, subject=jid(s), ttl_seconds=CHAT_OPEN_TTL_SECONDS
        );
        Jac.allow_root(s, UUID(post.owner_root), AccessLevel.WRITE);  # jac:ignore[E1053]
    }
    chat = ensure_chat(s);
    if chat is None {
        return ActionOutcome(ok=False, error="Couldn't open the chat. Try again.");
    }
    return ActionOutcome(ok=True, chat_id=jid(chat));
}

def denied -> str {
    return ""
        if verified_profile() is not None
        else "Sign in with your UMich email to use groups.";
}

def:protect list_groups_for_me -> list[GroupSummary] {
    profile = verified_profile();
    return [] if profile is None else list_groups(profile);
}

def:protect group_view(group_id: str) -> GroupView {
    return GroupView(ok=False, error=denied())
        if denied()
        else view(group_id, today_iso());
}

def:protect post_in_group(group_id: str, text: str) -> GroupPostResult {
    return GroupPostResult(ok=False, error=denied())
        if denied()
        else post_message(group_id, text, today_iso());
}

def:protect answer_group_followup(message_id: str, answers: str) -> GroupPostResult {
    return GroupPostResult(ok=False, error=denied())
        if denied()
        else answer_followup(message_id, answers, today_iso());
}

def:protect join_group(group_id: str) -> ActionOutcome {
    if denied() {
        return ActionOutcome(ok=False, error=denied());
    }
    g = group_by_id(group_id);
    if g is None or not theme_info(g) {
        return ActionOutcome(ok=False, error="That group isn't available.");
    }
    join(g);
    return ActionOutcome(ok=True, group_id=group_id);
}

def:protect leave_group(group_id: str) -> ActionOutcome {
    if denied() {
        return ActionOutcome(ok=False, error=denied());
    }
    g = group_by_id(group_id);
    if g is None or not is_member(g) {
        return ActionOutcome(ok=False, error="You're not in that group.");
    }
    leave(g);
    return ActionOutcome(ok=True, group_id=group_id);
}

def:protect untag_group_message(message_id: str) -> ActionOutcome {
    return ActionOutcome(ok=False, error=denied())
        if denied()
        else untag(message_id, today_iso());
}

def:protect close_group_post(post_id: str, reason: str) -> ActionOutcome {
    if denied() {
        return ActionOutcome(ok=False, error=denied());
    }
    r = finish(post_id, today_iso(), reason);
    return ActionOutcome(ok=r.ok, error=r.error);
}

def:protect message_poster(post_id: str) -> ActionOutcome {
    return ActionOutcome(ok=False, error=denied())
        if denied()
        else message_owner(post_id, today_iso());
}

test "suggested groups follow the profile, capped at three and never already joined" {
    assert suggested_keys(Profile(), []) == ["moveout", "furniture"];
    assert suggested_keys(
        Profile(housing_status="looking", needs_airport_ride=True), []
    )
        == ["housing", "rides", "moveout"];
    assert suggested_keys(Profile(housing_status="looking"), ["housing", "moveout"])
        == ["furniture"];
}

test "the facts line uses only the post's facts" {
    p = Post(
        owner_root="x",
        kind="request",
        category="furniture",
        title="Desk",
        price=40.0,
        available_from="2026-09-27",
        available_until="2026-09-28",
        area="Central Campus"
    );
    assert facts_line(p) == "budget $40 · 2026-09-27 to 2026-09-28 · Central Campus";
}
