"""Themed group chats (plan 2026-09-27-002).

A fixed set of groups (market/constants.jac THEMES) that every signed-in student can read and
join. Members chat normally. When the assistant recognizes a buy or sell message, the message stays
where it was written: the posts it becomes (the rules from market/lifecycle.jac) are linked to it
and shown as Buying/Selling tags, derived from the posts on every read. Matches in the same group
get one labelled assistant note under the message; matches anywhere are notified privately
(market/notify.jac). "Message privately" opens a one-to-one chat with a post's owner. The assistant
never invents people, items or counts.
"""

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
    message_by_id,
    member_count
}
import from market.constants { THEMES }
import from market.graph {
    Post,
    Suggestion,
    Chat,
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
import from market.matching { money, run_matching }
import from market.connect { chat_for }
import from market.items { category_for }
import from market.details {
    DetailQuestion,
    facts_split,
    unknowns,
    detail_questions,
    apply_detail,
    label_guessed
}
import from market.threads { thread_state, release_if_closed }

glob MAX_GROUP_MESSAGE_CHARS: int = 1000,
     MAX_MATCHES: int = 5,
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
     BUY_WORDS: list[str] = [
         "looking for",
         "i need",
         "need a",
         "need an",
         "want to buy",
         "wtb",
         "buying",
         "anyone selling",
         "iso "
     ],
     SELL_WORDS: list[str] = [
         "selling",
         "for sale",
         "giving away",
         "give away",
         "giveaway",
         "wts"
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

"""A compatible post shown only to the owner (M-R3): why it fits (confirmed facts), what's still
unknown, and the thread with its poster if one exists."""
obj MatchCard {
    has post_id: str,
        label: str,
        title: str,
        poster: str,
        confirmed: str,
        guesses: str,
        reasons: list[str],
        unknown: list[str],
        chat_id: str = "",
        thread_label: str = "";
}

"""A private thread about the owner's post, listed only for the owner."""
obj ThreadLink {
    has chat_id: str,
        other_name: str,
        state_label: str;
}

"""One Buying/Selling tag on a message: one post filed from it. Everyone sees the public part;
`questions`, `matches`, `threads` and `owner_state` are filled only for the post's owner, and
`my_chat` only for a viewer who already has a thread about it."""
obj TagView {
    has post_id: str,
        kind: str,
        label: str,
        title: str,
        confirmed: str,
        guesses: str,
        unknown: list[str],
        status: str,
        status_label: str,
        mine: bool,
        interest_label: str = "",
        owner_state: str = "",
        questions: list[DetailQuestion] = [],
        matches: list[MatchCard] = [],
        threads: list[ThreadLink] = [],
        my_chat: str = "";
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

"""The kind the words settle on their own: "request" for buy-only phrases ("looking for"),
"offer" for sell-only ones ("selling"), "" when neither or both appear."""
def kind_from_words(text: str) -> str {
    t = " " + text.lower() + " ";
    buying = any([w in t for w in BUY_WORDS]);
    # "Anyone selling a desk?" asks to buy; don't let its "selling" count as selling.
    t = t.replace("anyone selling", "");
    selling = any([w in t for w in SELL_WORDS]);
    if buying and not selling {
        return "request";
    }
    if selling and not buying {
        return "offer";
    }
    return "";
}

"""Without AI: does the text look like a market message?"""
def looks_like_market(text: str) -> bool {
    t = text.lower();
    return any([w in t for w in MARKET_WORDS]);
}

"""The public status of a post (M-R9): available, reserved, sold, found, withdrawn, expired or
hidden. Never says who is interested or how many."""
def tag_status(p: Post, today: str) -> str {
    status = post_status(p, today);
    if status == "done" {
        return p.closed_reason or "sold";
    }
    if status == "live" {
        return "reserved" if p.reserved_chat else "available";
    }
    return status;
}

"""The caller's threads about post `pid`, as (suggestion, chat) pairs."""
def threads_about(pid: str) -> list[tuple[Suggestion, Chat]] {
    me = jid(root);
    out: list[tuple[Suggestion, Chat]] = [];
    for s in all_suggestions() {
        if s.origin != "direct"
            or s.declined
            or me not in [s.root_a, s.root_b]
            or pid not in [s.post_a, s.post_b] {
            continue;
        }
        c = chat_for(jid(s));
        if c is not None {
            out.append((s, c));
        }
    }
    return out;
}

"""Compatible live posts for the owner's post `p` (M-R3), best first, at most MAX_MATCHES."""
def matches_for(p: Post, posts: dict[str, Post], today: str) -> list[MatchCard] {
    me = jid(root);
    pid = jid(p);
    blocked = blocked_keys();
    mine_threads = threads_about(pid);
    found: list[tuple[int, MatchCard]] = [];
    for s in all_suggestions() {
        if s.origin != "match"
            or s.withdrawn
            or s.declined
            or pid not in [s.post_a, s.post_b] {
            continue;
        }
        other = posts.get(s.post_b if s.post_a == pid else s.post_a);
        if other is None
            or other.owner_root == me
            or post_status(other, today) != "live"
            or pair_key(me, other.owner_root) in blocked {
            continue;
        }
        (sure, guessed) = facts_split(other);
        card = MatchCard(
            post_id=jid(other),
            label="Selling" if other.kind == "offer" else "Buying",
            title=other.title,
            poster=other.poster_name or "A student",
            confirmed=sure,
            guesses=guessed,
            reasons=label_guessed(s.reasons, s.reason_codes, p, other),
            unknown=unknowns(other)
        );
        for (ts, tc) in mine_threads {
            if jid(other) in [ts.post_a, ts.post_b] {
                card.chat_id = jid(tc);
                card.thread_label = thread_state(tc, ts, posts, today)[1];
            }
        }
        found.append((s.score, card));
    }
    found.sort(key=lambda (f: tuple[int, MatchCard]) -> int { return -f[0]; });
    return [c for (_, c) in found][:MAX_MATCHES];
}

"""What the owner sees about their post's progress (M-R9)."""
def owner_state(
    p: Post, matches: list[MatchCard], links: list[ThreadLink], today: str
) -> str {
    status = post_status(p, today);
    if status == "done" {
        if p.sold_chat {
            return "Completed";
        }
        return STATUS_LABELS.get(p.closed_reason or "sold", "Closed");
    }
    if status != "live" {
        return STATUS_LABELS.get(status, "Closed");
    }
    if p.reserved_chat {
        who = [
            l.other_name
            for l in links
            if l.chat_id == p.reserved_chat
        ];
        return "Reserved for " + (who[0] if who else "a student");
    }
    if links {
        return f"{len(links)} interested";
    }
    if matches {
        return f"Match found ({len(matches)})";
    }
    return "Finding matches — nothing fits yet. You'll get a notification when something does.";
}

def tag_view(p: Post, today: str, me: str, posts: dict[str, Post]) -> TagView {
    release_if_closed(p);
    status = tag_status(p, today);
    (sure, guessed) = facts_split(p);
    view = TagView(
        post_id=jid(p),
        kind="selling" if p.kind == "offer" else "buying",
        label="Selling" if p.kind == "offer" else "Buying",
        title=p.title,
        confirmed=sure,
        guesses=guessed,
        unknown=unknowns(p),
        status=status,
        status_label={"available": "Available", "reserved": "Reserved"}.get(
            status, STATUS_LABELS.get(status, "")
        ),
        mine=p.owner_root == me,
        interest_label="I'm interested" if p.kind == "offer" else "I have one"
    );
    if p.owner_root == me {
        links = [
            ThreadLink(
                chat_id=jid(c),
                other_name=s.from_name or "A student",
                state_label=thread_state(c, s, posts, today)[1]
            )
            for (s, c) in threads_about(jid(p))
            if s.root_a == me
        ];
        view.matches = matches_for(p, posts, today)
            if post_status(p, today) == "live"
            else [];
        view.threads = links;
        view.questions = detail_questions(p) if post_status(p, today) == "live" else [];
        view.owner_state = owner_state(p, view.matches, links, today);
    } else {
        for (s, c) in threads_about(jid(p)) {
            view.my_chat = jid(c);
        }
    }
    return view;
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
        # Never fail silently on something that reads like a listing (M-R10).
        return GroupPostResult(
            ok=True,
            message_id=message_id,
            notice="I couldn't read that as a listing, so it's posted as a plain message. Try again with what it is and a price or budget."
                if looks_like_market(text)
                else ""
        );
    }
    card = drafted.draft;
    known = parse_answers(answers);
    # "Looking for a bike" needs no question even when the model marks the kind as a guess.
    worded = kind_from_words(text);
    if worded
        and "kind" not in known
        and (not card.ai_generated or "kind" in card.guessed) {
        known["kind"] = worded;
    }
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
            tag_view(posts[pid], today, me, posts)
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

"""Answer one clarifying question about the caller's own post (M-R2); matching re-runs."""
def answer(post_id: str, field: str, value: str, today: str) -> ActionOutcome {
    p = own_post(post_id);
    if p is None {
        return ActionOutcome(ok=False, error="You can only change your own posts.");
    }
    error = apply_detail(p, field, value, today);
    if error {
        return ActionOutcome(ok=False, error=error);
    }
    run_matching(p, today);
    return ActionOutcome(ok=True);
}

def:protect answer_detail(post_id: str, field: str, value: str) -> ActionOutcome {
    return ActionOutcome(ok=False, error=denied())
        if denied()
        else answer(post_id, field, value, today_iso());
}

def:protect close_group_post(post_id: str, reason: str) -> ActionOutcome {
    if denied() {
        return ActionOutcome(ok=False, error=denied());
    }
    r = finish(post_id, today_iso(), reason);
    return ActionOutcome(ok=r.ok, error=r.error);
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

test "clear buy or sell words settle the kind; mixed or missing words don't" {
    assert kind_from_words("Looking for a bike under $100") == "request";
    assert kind_from_words("Selling my bike for $80") == "offer";
    assert kind_from_words("anyone selling a desk?") == "request";
    assert kind_from_words("Selling my bike, looking for a desk") == "";
    assert kind_from_words("desk") == "";
}
