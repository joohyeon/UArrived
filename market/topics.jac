"""Topic groups for the secondhand market (plan 004 G3-G5).

A message dropped in a cohort group is chat. If the assistant sees it is about the secondhand
market, it files it: the message becomes a post (the rules from market/lifecycle.jac), the post is
filed into a topic group (reused when one exists for the same topic, like `furniture:desk`), the
poster joins it, and students whose own posts match are invited with a reason. The assistant then
replies in the cohort group with where the message went. It never invents people or counts.
Invites are opt-in: nobody enters a topic group without tapping Join.
"""

import re;
import from uuid { UUID }
import from jaclang { JacRuntime as Jac }
import from core.auth { verified_profile }
import from core.clock { today_iso, now_iso }
import from core.profile { my_profile }
import from core.groups {
    ChatGroup,
    GroupMessage,
    MemberOf,
    group_by_id,
    is_member,
    join,
    ensure_group,
    groups_with_key,
    add_message,
    messages_in,
    member_count,
    member_ids,
    my_group_ids,
    sync_cohort
}
import from market.graph {
    Post,
    all_posts,
    all_suggestions,
    post_status,
    visible_to,
    pair_key,
    blocked_keys
}
import from market.drafting { make_draft }
import from market.lifecycle { publish, view_of, own_post, finish, PostView }
import from market.messages { blocking_question, fields_from, parse_answers, FollowUp }
import from market.matching { place, money }

glob MAX_GROUP_MESSAGE_CHARS: int = 1000,
     SKIP_WORDS: list[str] = [
         "a",
         "an",
         "the",
         "my",
         "some",
         "used",
         "new",
         "old",
         "free",
         "for",
         "sale",
         "near",
         "campus",
         "cheap",
         "small",
         "big",
         "large",
         "good",
         "nice",
         "wooden",
         "wood",
         "black",
         "white",
         "ikea",
         "set",
         "of",
         "and",
         "with"
     ],
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
         "$"
     ];

"""An invitation to a topic group, visible only to the poster who caused it and the invitee."""
node Invite {
    has group_id: str,
        invitee_root: str,
        post_id: str,
        reason: str,
        created_at: str,
        status: str = "pending",
        emailed: bool = False;
}

"""Public, content-free record that `invitee_root` was invited to `group_id`, so whoever files the
next matching post can see it (the Invite itself is visible only to its sender and invitee)."""
node InviteMark {
    has group_id: str,
        invitee_root: str;

    def __jac_access__ -> AccessLevel | None {
        return AccessLevel.READ;
    }
}

obj GroupPostResult {
    has ok: bool,
        error: str = "",
        notice: str = "",
        message_id: str = "",
        filed: bool = False,
        topic_group_id: str = "",
        invited: int = 0,
        follow_up: FollowUp | None = None;
}

obj GroupMessageView {
    has id: str,
        mine: bool,
        author: str,
        text: str,
        created_at: str,
        ai: bool,
        post_id: str,
        topic_group_id: str = "",
        can_open: bool = False;
}

obj GroupView {
    has ok: bool,
        error: str = "",
        id: str = "",
        kind: str = "",
        name: str = "",
        member: bool = False,
        members: int = 0,
        invite_id: str = "",
        invite_reason: str = "",
        messages: list[GroupMessageView] = [],
        posts: list[PostView] = [];
}

obj GroupSummary {
    has id: str,
        kind: str,
        name: str,
        members: int,
        last_message: str,
        last_at: str;
}

obj InviteView {
    has id: str,
        group_id: str,
        group_name: str,
        reason: str,
        members: int,
        created_at: str;
}

obj ActionOutcome {
    has ok: bool,
        error: str = "",
        group_id: str = "";
}

"""The item word of a title: 'Wooden desk' -> 'desk', 'IKEA bookshelves' -> 'bookshelf'."""
def item_word(title: str) -> str {
    words = [
        w
        for w in re.findall(r"[a-z]+", title.lower())
        if w not in SKIP_WORDS
    ];
    if not words {
        return "";
    }
    w = words[-1];
    if w.endswith("ves") {
        return w[:-3] + "f";
    }
    if len(w) > 3 and w.endswith("s") and not w.endswith("ss") {
        return w[:-1];
    }
    return w;
}

def plural(word: str) -> str {
    if word.endswith(("s", "x", "ch", "sh")) {
        return word + "es";
    }
    if word.endswith("y") and len(word) > 2 and word[-2] not in "aeiou" {
        return word[:-1] + "ies";
    }
    return word + "s";
}

"""Which topic group a post belongs in; posts with the same key share one group."""
def topic_key(p: Post) -> str {
    if p.category == "service" and p.route_from {
        return f"ride:{place(p.route_from)}>{place(p.route_to)}:{p.available_from}";
    }
    if p.category == "housing" {
        return f"housing:{p.arrangement or 'room'}";
    }
    return f"{p.category}:{item_word(p.title) or p.category}";
}

def topic_name(p: Post) -> str {
    if p.category == "service" and p.route_from {
        return f"Rides {p.route_from} to {p.route_to}"
            + (f" · {p.available_from}" if p.available_from else "");
    }
    if p.category == "housing" {
        return {
            "sublet": "Sublets",
            "roommate opening": "Roommate openings",
            "lease assignment": "Lease transfers",
            "new lease": "New leases"
        }.get(
            p.arrangement, "Rooms and housing"
        );
    }
    return f"{plural(item_word(p.title) or p.category).capitalize()} near campus";
}

"""A one-line summary of a post's facts, for the topic group announcement."""
def facts_line(p: Post) -> str {
    parts: list[str] = [
        ("Offering" if p.kind == "offer" else "Looking for") + ": " + p.title
    ];
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

def invited_already(group_id: str, invitee: str) -> bool {
    for i in [root.shared-->][?:InviteMark] {
        if i.group_id == group_id and i.invitee_root == invitee {
            return True;
        }
    }
    return False;
}

"""Invite students whose own live posts match `post` into `topic`. Returns how many were invited."""
def invite_matches(post: Post, topic: ChatGroup, today: str) -> int {
    me = jid(root);
    pid = jid(post);
    posts: dict[str, Post] = {jid(p): p for p in visible_to(all_posts(), me)};
    members = member_ids(topic);
    count = 0;
    for s in all_suggestions() {
        if s.origin != "match"
            or s.withdrawn
            or s.declined
            or pid not in [s.post_a, s.post_b] {
            continue;
        }
        other_id = s.post_b if s.post_a == pid else s.post_a;
        other = posts.get(other_id);
        if other is None
            or other.owner_root == me
            or post_status(other, today) != "live" {
            continue;
        }
        if other.owner_root in members
            or invited_already(jid(topic), other.owner_root) {
            continue;
        }
        reason = f"Your post \"{other.title}\" fits: "
            + ("; ".join(s.reasons) if s.reasons else "same kind of thing");
        inv = root.shared ++> Invite(
            group_id=jid(topic),
            invitee_root=other.owner_root,
            post_id=pid,
            reason=reason,
            created_at=now_iso()
        );
        Jac.allow_root(inv, UUID(other.owner_root), AccessLevel.WRITE);  # jac:ignore[E1053]
        root.shared ++> InviteMark(group_id=jid(topic), invitee_root=other.owner_root);
        count += 1;
    }
    return count;
}

"""File a cohort message into the market if it is about the market. Returns the outcome; when
intent is unclear it returns one follow-up question for the poster and files nothing."""
def file_market(
    cohort: ChatGroup, text: str, message_id: str, answers: str, today: str
) -> GroupPostResult {
    drafted = make_draft(text, today);
    if not drafted.ok or drafted.draft is None {
        return GroupPostResult(ok=True, message_id=message_id);
    }
    card = drafted.draft;
    known = parse_answers(answers);
    about = card.about_market if card.ai_generated else looks_like_market(text);
    # In a group, a message whose kind and category are both guesses is chat, not a question.
    unsure = card.ai_generated and "kind" in card.guessed and "category" in card.guessed;
    if (not about or unsure) and not known {
        return GroupPostResult(ok=True, message_id=message_id);
    }
    question = blocking_question(card, known);
    if question is not None {
        return GroupPostResult(ok=True, message_id=message_id, follow_up=question);
    }
    result = publish(
        fields_from(card, known, text), today, ai_generated=card.ai_generated
    );
    if not result.ok or result.post is None {
        return GroupPostResult(
            ok=True,
            message_id=message_id,
            notice=f"Your message is posted, but I couldn't file it for the market: {result.error}"
        );
    }
    post = own_post(result.post.id);
    if post is None {
        return GroupPostResult(
            ok=False, message_id=message_id, error="Couldn't file that message."
        );
    }
    reused = len(groups_with_key(topic_key(post))) > 0;
    topic = ensure_group(
        "topic", topic_key(post), topic_name(post), reason=facts_line(post)
    );
    join(topic);
    post.topic_group_id = jid(topic);
    add_message(
        topic, "New in this group. " + facts_line(post), ai=True, post_id=jid(post)
    );
    invited = invite_matches(post, topic, today);
    where = f"I added this to \"{topic.name}\"" if reused else f"I started a group for this, \"{topic.name}\"";
    reply = (
        f"{where} and invited {invited} student{'s' if invited != 1 else ''} whose posts fit."
            if invited > 0
            else f"{where}. Nobody else's posts fit yet; I'll invite people as matching posts come in."
    );
    add_message(cohort, reply, ai=True, post_id=jid(post));
    return GroupPostResult(
        ok=True,
        message_id=message_id,
        filed=True,
        topic_group_id=jid(topic),
        invited=invited
    );
}

"""Post `text` in a group the caller belongs to. In a cohort group the assistant may file it."""
def post_message(group_id: str, text: str, today: str) -> GroupPostResult {
    g = group_by_id(group_id);
    if g is None or not is_member(g) {
        return GroupPostResult(
            ok=False, error="You can only post in groups you've joined."
        );
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
    if g.kind != "cohort" {
        return GroupPostResult(ok=True, message_id=jid(msg));
    }
    return file_market(g, body, jid(msg), "", today);
}

"""Answer the assistant's follow-up question about one of the caller's cohort messages."""
def answer_followup(message_id: str, answers: str, today: str) -> GroupPostResult {
    me = jid(root);
    for m in [root.shared-->][?:GroupMessage] {
        if jid(m) == message_id and m.author_root == me and not m.ai {
            g = group_by_id(m.group_id);
            if g is None or g.kind != "cohort" {
                break;
            }
            return file_market(g, m.text, message_id, answers, today);
        }
    }
    return GroupPostResult(ok=False, error="That message isn't available.");
}

def my_invite_for(group_id: str) -> Invite | None {
    me = jid(root);
    for i in [root.shared-->][?:Invite] {
        if i.group_id == group_id and i.invitee_root == me and i.status == "pending" {
            return i;
        }
    }
    return None;
}

def view(group_id: str, today: str) -> GroupView {
    g = group_by_id(group_id);
    if g is None {
        return GroupView(ok=False, error="That group isn't available.");
    }
    me = jid(root);
    if not is_member(g) {
        inv = my_invite_for(group_id);
        if inv is None {
            return GroupView(ok=False, error="You're not in this group.");
        }
        return GroupView(
            ok=True,
            id=group_id,
            kind=g.kind,
            name=g.name,
            member=False,
            members=member_count(g),
            invite_id=jid(inv),
            invite_reason=inv.reason
        );
    }
    blocked = blocked_keys();
    visible = visible_to(all_posts(), me);
    topic_of: dict[str, str] = {jid(p): p.topic_group_id for p in visible};
    mine = my_group_ids();
    msgs = [
        GroupMessageView(
            id=jid(m),
            mine=m.author_root == me,
            author="You" if m.author_root == me and not m.ai else m.author_name,
            text=m.text,
            created_at=m.created_at,
            ai=m.ai,
            post_id=m.post_id,
            topic_group_id=topic_of.get(m.post_id, "") if g.kind == "cohort" else "",
            can_open=topic_of.get(m.post_id, "") in mine
        )
        for m in messages_in(group_id)
        if m.ai or m.author_root == me or pair_key(me, m.author_root) not in blocked
    ];
    filed = [
        view_of(p, today)
        for p in visible
        if p.topic_group_id == group_id and post_status(p, today) == "live"
    ];
    return GroupView(
        ok=True,
        id=group_id,
        kind=g.kind,
        name=g.name,
        member=True,
        members=member_count(g),
        messages=msgs,
        posts=filed
    );
}

def groups_of_mine -> list[GroupSummary] {
    out: list[GroupSummary] = [];
    for g in [root->:MemberOf:->] {
        msgs = messages_in(jid(g));
        out.append(
            GroupSummary(
                id=jid(g),
                kind=g.kind,
                name=g.name,
                members=member_count(g),
                last_message=msgs[-1].text if msgs else "",
                last_at=msgs[-1].created_at if msgs else g.created_at
            )
        );
    }
    out.sort(
        key=lambda (s: GroupSummary) -> tuple[int, str] { return (
            0 if s.kind == "cohort" else 1,
            s.last_at
        ); }
    );
    return out;
}

def pending_invites -> list[InviteView] {
    me = jid(root);
    out: list[InviteView] = [];
    seen: list[str] = [];
    for i in [root.shared-->][?:Invite] {
        if i.invitee_root != me or i.status != "pending" or i.group_id in seen {
            continue;
        }
        seen.append(i.group_id);
        g = group_by_id(i.group_id);
        if g is not None and not is_member(g) {
            out.append(
                InviteView(
                    id=jid(i),
                    group_id=i.group_id,
                    group_name=g.name,
                    reason=i.reason,
                    members=member_count(g),
                    created_at=i.created_at
                )
            );
        }
    }
    return out;
}

def respond_invite(invite_id: str, accept: bool) -> ActionOutcome {
    me = jid(root);
    for i in [root.shared-->][?:Invite] {
        if jid(i) == invite_id and i.invitee_root == me and i.status == "pending" {
            g = group_by_id(i.group_id);
            if g is None {
                return ActionOutcome(ok=False, error="That group isn't available.");
            }
            if accept {
                join(g);
            }
            for other in [root.shared-->][?:Invite] {
                if other.group_id == i.group_id
                    and other.invitee_root == me
                    and other.status == "pending" {
                    other.status = "joined" if accept else "dismissed";
                }
            }
            return ActionOutcome(ok=True, group_id=i.group_id);
        }
    }
    return ActionOutcome(ok=False, error="That invite isn't available.");
}

def denied -> str {
    return ""
        if verified_profile() is not None
        else "Verify your UMich email to use groups.";
}

def:protect my_groups -> list[GroupSummary] {
    if denied() {
        return [];
    }
    sync_cohort(my_profile());
    return groups_of_mine();
}

def:protect my_group_invites -> list[InviteView] {
    return [] if denied() else pending_invites();
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

def:protect join_topic_group(invite_id: str) -> ActionOutcome {
    return ActionOutcome(ok=False, error=denied())
        if denied()
        else respond_invite(invite_id, True);
}

def:protect dismiss_topic_invite(invite_id: str) -> ActionOutcome {
    return ActionOutcome(ok=False, error=denied())
        if denied()
        else respond_invite(invite_id, False);
}

def:protect close_group_post(post_id: str, reason: str) -> ActionOutcome {
    if denied() {
        return ActionOutcome(ok=False, error=denied());
    }
    r = finish(post_id, today_iso(), reason);
    return ActionOutcome(ok=r.ok, error=r.error);
}

test "item words and topic keys group similar posts together" {
    assert item_word("Wooden desk") == "desk"
        and item_word("IKEA bookshelves") == "bookshelf";
    assert item_word("Desks") == "desk" and item_word("glass") == "glass";
    a = Post(
        owner_root="x", kind="offer", category="furniture", title="Solid wood desk"
    );
    b = Post(owner_root="y", kind="request", category="furniture", title="Need a desk");
    assert topic_key(a) == topic_key(b) == "furniture:desk";
    assert topic_name(a) == "Desks near campus";
    ride = Post(
        owner_root="x",
        kind="request",
        category="service",
        title="Ride",
        route_from="DTW",
        route_to="Ann Arbor",
        available_from="2026-08-20"
    );
    assert topic_key(ride) == "ride:dtw>ann arbor:2026-08-20";
    assert topic_key(
        Post(
            owner_root="x",
            kind="offer",
            category="housing",
            title="Room",
            arrangement="sublet"
        )
    )
        == "housing:sublet";
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
    assert facts_line(p)
        == "Looking for: Desk · budget $40 · 2026-09-27 to 2026-09-28 · Central Campus";
}
