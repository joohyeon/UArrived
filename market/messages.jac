"""Chat-first marketplace (plan 2026-09-26-003, C2-C4): drop a message, get a response.

- `send_market_message`: one message becomes a live post immediately when it is clear what the
  student wants (offer or request) and what kind of thing it is. Otherwise the assistant asks one
  short question with quick-reply choices and nothing is published until it is answered.
- The assistant's notes (labeled as automated in the UI) answer in the poster's own thread: up to
  three real matches with reasons and limitations, or "no match yet" with a concrete refinement.
  Notes are built only from real posts and suggestions: no invented people, offers or availability.
- `market_stream`: my messages, the messages that match mine, else recent live messages.
- Threads: react / ask / offer on someone's message; the poster answers or accepts, and accepting
  opens a direct chat. Each reply is visible only to the poster and its author; everyone else
  sees counts.
- `nudge_due`: once per message, some hours after posting with no human reply, the assistant
  follows up (serve-mode schedule).
"""

import os;
import from uuid { UUID }
import from datetime { datetime }
import from jaclang { JacRuntime as Jac }
import from jaclang.server.identity.app_tokens { token_create }
import from core.auth { verified_profile }
import from core.clock { today_iso, now_iso }
import from core.profile { my_profile, sync_mailbox }
import from market.graph {
    Post,
    Suggestion,
    Reply,
    ReplyTick,
    AssistantNote,
    all_posts,
    all_suggestions,
    all_replies,
    reply_counts,
    notes_for,
    post_status,
    availability,
    limitations,
    visible_to,
    commons_or_shared
}
import from market.drafting { make_draft, DraftCard }
import from market.lifecycle {
    publish,
    edit,
    finish,
    view_of,
    own_post,
    PostView,
    CLOSE_REASONS
}
import from market.matching { CHAT_OPEN_PURPOSE, CHAT_OPEN_TTL_SECONDS, money }
import from market.connect { ensure_chat }

glob MAX_NOTE_ITEMS: int = 3,
     MAX_REPLY_CHARS: int = 500,
     STREAM_FALLBACK: int = 20,
     NUDGE_HOURS: float = float(os.environ.get("UARRIVED_NUDGE_HOURS", "4")),
     KIND_CHOICES: list[tuple[str, str]] = [
         ("I'm selling or giving it away", "kind:offer"),
         ("I'm looking for it", "kind:request")
     ],
     CATEGORY_CHOICES: list[tuple[str, str]] = [
         ("Furniture", "category:furniture"),
         ("Household essentials", "category:essentials"),
         ("Housing", "category:housing"),
         ("Vehicle", "category:vehicle"),
         ("Ride or help", "category:service")
     ],
     ARRANGEMENT_CHOICES: list[tuple[str, str]] = [
         ("Roommate opening", "arrangement:roommate opening"),
         ("Sublet", "arrangement:sublet"),
         ("Lease assignment", "arrangement:lease assignment"),
         ("New lease", "arrangement:new lease")
     ];

obj Choice {
    has label: str,
        value: str;
}

obj FollowUp {
    has question: str,
        choices: list[Choice];
}

obj MessageResult {
    has ok: bool,
        error: str = "",
        published: bool = False,
        post_id: str = "",
        follow_up: FollowUp | None = None;
}

obj NoteItem {
    has post: PostView,
        reasons: list[str];
}

obj NoteView {
    has kind: str,
        text: str,
        items: list[NoteItem],
        choices: list[Choice],
        created_at: str;
}

obj ReplyView {
    has id: str,
        kind: str,
        text: str,
        offer_price: float | None,
        mine: bool,
        created_at: str,
        accepted: bool;
}

obj StreamItem {
    has post: PostView,
        reasons: list[str],
        replies: int,
        unread: int;
}

obj ThreadView {
    has ok: bool,
        error: str = "",
        post: PostView | None = None,
        notes: list[NoteView] = [],
        replies: list[ReplyView] = [],
        counts: dict[str, int] = {};
}

obj ActionResult {
    has ok: bool,
        error: str = "",
        chat_id: str = "";
}

def choice_list(pairs: list[tuple[str, str]]) -> list[Choice] {
    return [Choice(label=l, value=v) for (l, v) in pairs];
}

"""Quick-reply answers arrive as tokens like "kind:offer category:furniture"."""
def parse_answers(answers: str) -> dict[str, str] {
    out: dict[str, str] = {};
    for part in answers.split("|") {
        if ":" in part {
            (key, value) = part.split(":", 1);
            out[key.strip()] = value.strip();
        }
    }
    return out;
}

"""The follow-up question that blocks publishing, or None when the message can be posted."""
def blocking_question(card: DraftCard, known: dict[str, str]) -> FollowUp | None {
    if "kind" not in known and (not card.ai_generated or "kind" in card.guessed) {
        return FollowUp(
            question="Are you selling something, or looking for it?",
            choices=choice_list(KIND_CHOICES)
        );
    }
    # The model always "infers" a category from the fixed list, so a guessed category is normal;
    # ask for it only when there is no AI at all.
    if "category" not in known and not card.ai_generated {
        return FollowUp(
            question="What kind of thing is it?", choices=choice_list(CATEGORY_CHOICES)
        );
    }
    category = known.get("category", card.category);
    if category == "housing" and "arrangement" not in known and not card.arrangement {
        return FollowUp(
            question="What kind of housing arrangement is it?",
            choices=choice_list(ARRANGEMENT_CHOICES)
        );
    }
    return None;
}

def fields_from(card: DraftCard, known: dict[str, str], text: str) -> dict[str, any] {
    return {
        "kind": known.get("kind", card.kind),
        "category": known.get("category", card.category),
        "title": card.title or text[:60],
        "description": card.description if card.ai_generated else text[:500],
        "price": card.price,
        "free": card.free,
        "available_from": card.available_from,
        "available_until": card.available_until,
        "time_from": card.time_from,
        "time_to": card.time_to,
        "area": card.area,
        "route_from": card.route_from,
        "route_to": card.route_to,
        "arrangement": known.get("arrangement", card.arrangement),
        "constraints": card.constraints
    };
}

"""Post `text` (plus any quick-reply answers) as a message, or ask one follow-up question."""
def send_message_as_post(text: str, answers: str, today: str) -> MessageResult {
    drafted = make_draft(text, today);
    if not drafted.ok or drafted.draft is None {
        return MessageResult(ok=False, error=drafted.error);
    }
    known = parse_answers(answers);
    question = blocking_question(drafted.draft, known);
    if question is not None {
        return MessageResult(ok=True, follow_up=question);
    }
    result = publish(
        fields_from(drafted.draft, known, text),
        today,
        ai_generated=drafted.draft.ai_generated
    );
    if not result.ok or result.post is None {
        return MessageResult(ok=False, error=result.error);
    }
    post = own_post(result.post.id);
    if post is not None {
        write_note(post, today, "first");
    }
    return MessageResult(ok=True, published=True, post_id=result.post.id);
}

"""Real matches for `post` right now: the other posts of its open suggestions, best first."""
def match_items(post: Post, today: str, commons: any = None) -> list[NoteItem] {
    pid = jid(post);
    posts: dict[str, Post] = {
        jid(p): p for p in visible_to(all_posts(commons), post.owner_root, commons)
    };
    found: list[tuple[int, NoteItem]] = [];
    for s in all_suggestions(commons) {
        if s.origin != "match"
            or s.withdrawn
            or s.declined
            or pid not in [s.post_a, s.post_b] {
            continue;
        }
        other = posts.get(s.post_b if s.post_a == pid else s.post_a);
        if other is None or post_status(other, today) != "live" {
            continue;
        }
        found.append(
            (s.score, NoteItem(post=view_of(other, today), reasons=s.reasons))
        );
    }
    found.sort(key=lambda (f: tuple[int, NoteItem]) -> int { return -f[0]; });
    return [f[1] for f in found[:MAX_NOTE_ITEMS]];
}

"""One concrete way to widen the search, from the post's own facts (never invented)."""
def refinements(post: Post) -> list[Choice] {
    out: list[Choice] = [];
    if post.kind == "request" and post.price is not None {
        higher = round(post.price * 1.25);
        out.append(
            Choice(
                label=f"Raise budget to {money(float(higher))}",
                value=f"budget:{higher}"
            )
        );
    }
    if post.kind == "offer" and post.price is not None and post.price > 0 {
        lower = round(post.price * 0.85);
        out.append(
            Choice(
                label=f"Lower price to {money(float(lower))}", value=f"price:{lower}"
            )
        );
    }
    if post.area {
        out.append(Choice(label="Any area near campus", value="area:any"));
    }
    out.append(Choice(label="Email me when something fits", value="notify:on"));
    return out;
}

"""The assistant's note text and choices for `post` now. `moment` is "first" or "nudge"."""
def compose_note(
    post: Post, today: str, moment: str, commons: any = None
) -> tuple[str, str, list[NoteItem], list[Choice]] {
    items = match_items(post, today, commons);
    other_side = "offers" if post.kind == "request" else "students looking for this";
    nobody = "No offers match yet."
        if post.kind == "request"
        else "Nobody is looking for this yet.";
    if items {
        lead = "Nobody has replied yet, but these still fit:"
            if moment == "nudge"
            else f"I found {len(items)} {other_side} that fit:";
        return (
            "matches",
            lead,
            items,
            [Choice(label="Email me about new ones", value="notify:on")]
        );
    }
    lead = (
        "No replies or matches yet. Changing one detail often helps:"
            if moment == "nudge"
            else nobody
                + " I'll keep looking and tell you when one does. To widen the search:"
    );
    return ("no_match", lead, [], refinements(post));
}

def write_note(
    post: Post, today: str, moment: str, commons: any = None
) -> AssistantNote {
    (kind, text, items, choices) = compose_note(post, today, moment, commons);
    shared: Root = commons if commons is not None else root.shared;
    note = shared ++> AssistantNote(
        post_id=jid(post),
        kind=kind if moment == "first" else "nudge",
        text=text,
        created_at=now_iso(),
        items=[{"post_id": i.post.id} for i in items],
        choices=[f"{c.label}|{c.value}" for c in choices]
    );
    if post.owner_root != jid(root) {
        Jac.allow_root(note, UUID(post.owner_root), AccessLevel.READ);  # jac:ignore[E1053]
    }
    return note;
}

"""Apply a quick-reply choice from the assistant to the caller's own message."""
def apply_choice_to(post_id: str, value: str, today: str) -> ActionResult {
    post = own_post(post_id);
    if post is None {
        return ActionResult(ok=False, error="You can only change your own messages.");
    }
    (key, _, arg) = value.partition(":");
    if key == "notify" {
        profile = my_profile();
        profile.email_notifications = True;
        sync_mailbox(profile);
        return ActionResult(ok=True);
    }
    changes: dict[str, any] = {};
    if key == "budget" or key == "price" {
        changes["price"] = float(arg);
    } elif key == "area" {
        changes["area"] = "";
    } else {
        return ActionResult(ok=False, error="That option isn't available.");
    }
    result = edit(post_id, changes, today);
    if not result.ok {
        return ActionResult(ok=False, error=result.error);
    }
    write_note(post, today, "first");
    return ActionResult(ok=True);
}

"""Messages for my stream: mine, the ones matching mine (with reasons), else recent ones."""
def stream(today: str) -> list[StreamItem] {
    me = jid(root);
    posts = [
        p
        for p in visible_to(all_posts(), me)
        if post_status(p, today) == "live"
    ];
    by_id: dict[str, Post] = {jid(p): p for p in posts};
    mine = [
        p
        for p in posts
        if p.owner_root == me
    ];
    reasons: dict[str, list[str]] = {};
    for s in all_suggestions() {
        if s.origin != "match"
            or s.withdrawn
            or s.declined
            or me not in [s.root_a, s.root_b] {
            continue;
        }
        other_id = s.post_b if s.root_a == me else s.post_a;
        if other_id in by_id and other_id not in reasons {
            reasons[other_id] = s.reasons;
        }
    }
    chosen = mine + [by_id[i] for i in reasons];
    if not reasons {
        others = [
            p
            for p in posts
            if p.owner_root != me
        ];
        others.sort(
            key=lambda (p: Post) -> str { return p.published_at or p.published_on; },
            reverse=True
        );
        chosen = mine + others[:STREAM_FALLBACK];
    }
    replies = all_replies();
    items: list[StreamItem] = [];
    for p in chosen {
        pid = jid(p);
        counts = reply_counts(pid);
        unread = len(
            [
                r
                for r in replies
                if r.post_id == pid
                    and r.to_root == me
                    and not r.seen_by_to
                    and r.kind in ["question", "offer", "answer"]
            ]
        );
        items.append(
            StreamItem(
                post=view_of(p, today),
                reasons=reasons.get(pid, []),
                replies=sum(counts.values()),
                unread=unread
            )
        );
    }
    items.sort(
        key=lambda (i: StreamItem) -> str { return by_id[i.post.id].published_at
            or i.post.expires_on; },
        reverse=True
    );
    return items;
}

def note_view(n: AssistantNote, today: str) -> NoteView {
    posts: dict[str, Post] = {jid(p): p for p in all_posts()};
    items: list[NoteItem] = [];
    for it in n.items {
        p = posts.get(it["post_id"]);
        if p is not None and post_status(p, today) == "live" {
            items.append(NoteItem(post=view_of(p, today), reasons=[]));
        }
    }
    choices = [
        Choice(label=c.split("|")[0], value=c.split("|")[1])
        for c in n.choices
        if "|" in c
    ];
    return NoteView(
        kind=n.kind, text=n.text, items=items, choices=choices, created_at=n.created_at
    );
}

"""A message and what the caller may see of its thread."""
def thread(post_id: str, today: str) -> ThreadView {
    me = jid(root);
    post: Post | None = None;
    for p in visible_to(all_posts(), me) {
        if jid(p) == post_id {
            post = p;
        }
    }
    if post is None {
        return ThreadView(ok=False, error="That message isn't available.");
    }
    visible = [
        r
        for r in all_replies()
        if r.post_id == post_id and me in [r.author_root, r.to_root]
    ];
    for r in visible {
        if r.to_root == me and not r.seen_by_to {
            r.seen_by_to = True;
        }
    }
    visible.sort(key=lambda (r: Reply) -> str { return r.created_at; });
    notes = [note_view(n, today) for n in notes_for(post_id)]
        if post.owner_root == me
        else [];
    return ThreadView(
        ok=True,
        post=view_of(post, today),
        notes=notes,
        replies=[
            ReplyView(
                id=jid(r),
                kind=r.kind,
                text=r.text,
                offer_price=r.offer_price,
                mine=r.author_root == me,
                created_at=r.created_at,
                accepted=r.accepted
            ) for r in visible
        ],
        counts=reply_counts(post_id)
    );
}

"""The live, visible, not-my-own post with this id, or None."""
def others_post(post_id: str, today: str) -> Post | None {
    me = jid(root);
    for p in visible_to(all_posts(), me) {
        if jid(p) == post_id
            and p.owner_root != me
            and post_status(p, today) == "live" {
            return p;
        }
    }
    return None;
}

def add_reply(post: Post, kind: str, text: str, price: float | None, to: str) -> Reply {
    r = root.shared ++> Reply(
        post_id=jid(post),
        author_root=jid(root),
        to_root=to,
        kind=kind,
        created_at=now_iso(),
        text=text,
        offer_price=price
    );
    Jac.allow_root(r, UUID(to), AccessLevel.WRITE);  # jac:ignore[E1053]
    root.shared ++> ReplyTick(post_id=jid(post), kind=kind);
    return r;
}

"""React, ask or offer on someone else's live message."""
def respond(
    post_id: str, kind: str, text: str, price: float | None, today: str
) -> ActionResult {
    post = others_post(post_id, today);
    if post is None {
        return ActionResult(
            ok=False, error="You can reply to other students' live messages only."
        );
    }
    body = text.strip()[:MAX_REPLY_CHARS];
    if kind in ["interested", "available"] {
        me = jid(root);
        if any(
            [
                r.post_id == post_id and r.author_root == me and r.kind == kind
                for r in all_replies()
            ]
        ) {
            return ActionResult(ok=True);
        }
    } elif kind == "question" {
        if not body {
            return ActionResult(ok=False, error="Type your question.");
        }
    } elif kind == "offer" {
        if price is None or price < 0 {
            return ActionResult(ok=False, error="Enter the amount you're offering.");
        }
    } else {
        return ActionResult(ok=False, error="That kind of reply isn't available.");
    }
    add_reply(post, kind, body, price, post.owner_root);
    return ActionResult(ok=True);
}

"""The poster answers one reply. Answering also counts as confirming the item is available."""
def answer(reply_id: str, text: str, today: str) -> ActionResult {
    me = jid(root);
    body = text.strip()[:MAX_REPLY_CHARS];
    if not body {
        return ActionResult(ok=False, error="Type your answer.");
    }
    for r in all_replies() {
        if jid(r) == reply_id and r.to_root == me {
            post = own_post(r.post_id);
            if post is None or post_status(post, today) != "live" {
                return ActionResult(ok=False, error="This message is closed.");
            }
            post.confirmed_on = today;
            add_reply(post, "answer", body, None, r.author_root);
            return ActionResult(ok=True);
        }
    }
    return ActionResult(ok=False, error="That reply isn't available.");
}

"""The poster accepts a reply: a direct chat opens with that student (existing chat rules)."""
def accept(reply_id: str, today: str) -> ActionResult {
    me = jid(root);
    for r in all_replies() {
        if jid(r) != reply_id or r.to_root != me or r.kind == "answer" {
            continue;
        }
        post = own_post(r.post_id);
        if post is None or post_status(post, today) != "live" {
            return ActionResult(ok=False, error="This message is closed.");
        }
        s: Suggestion | None = None;
        for existing in all_suggestions() {
            if existing.origin == "reply"
                and existing.post_a == r.post_id
                and existing.root_b == r.author_root
                and not existing.declined {
                s = existing;
            }
        }
        if s is None {
            s = root.shared ++> Suggestion(
                post_a=r.post_id,
                post_b="",
                root_a=me,
                root_b=r.author_root,
                score=0,
                reasons=[],
                created_on=today,
                accepted_a=True,
                accepted_b=True,
                seen_a=True,
                seen_b=True,
                emailed_a=True,
                emailed_b=True,
                origin="reply",
                reply_id=reply_id
            );
            s.open_token = token_create(
                CHAT_OPEN_PURPOSE, subject=jid(s), ttl_seconds=CHAT_OPEN_TTL_SECONDS
            );
            Jac.allow_root(s, UUID(r.author_root), AccessLevel.WRITE);  # jac:ignore[E1053]
        }
        r.accepted = True;
        post.confirmed_on = today;
        chat = ensure_chat(s);
        return ActionResult(
            ok=chat is not None,
            chat_id=jid(chat) if chat is not None else "",
            error="" if chat is not None else "Couldn't open the chat. Try again."
        );
    }
    return ActionResult(ok=False, error="That reply isn't available.");
}

def confirm(post_id: str, today: str) -> ActionResult {
    post = own_post(post_id);
    if post is None or post_status(post, today) != "live" {
        return ActionResult(
            ok=False, error="You can only confirm your own live messages."
        );
    }
    post.confirmed_on = today;
    return ActionResult(ok=True);
}

"""Due assistant nudges (system sweep): live messages older than NUDGE_HOURS with no human reply
and no nudge yet get exactly one. Returns how many were written."""
def nudge_due(now: str, commons: any = None) -> int {
    today = now[:10];
    replied = {r.post_id for r in all_replies(commons)};
    written = 0;
    for p in all_posts(commons) {
        if p.nudged
            or not p.published_at
            or jid(p) in replied
            or post_status(p, today) != "live" {
            continue;
        }
        age_hours = (
            datetime.fromisoformat(now) - datetime.fromisoformat(p.published_at)
        ).total_seconds()
            / 3600;
        if age_hours < NUDGE_HOURS {
            continue;
        }
        write_note(p, today, "nudge", commons);
        p.nudged = True;
        written += 1;
    }
    return written;
}

@schedule(trigger=ScheduleTrigger.STATIC, interval=600)
def nudge_sweep {
    nudge_due(now_iso());
}

def denied -> ActionResult | None {
    return None
        if verified_profile() is not None
        else ActionResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
}

def:protect send_market_message(text: str, answers: str) -> MessageResult {
    if verified_profile() is None {
        return MessageResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    return send_message_as_post(text, answers, today_iso());
}

def:protect market_stream -> list[StreamItem] {
    return [] if verified_profile() is None else stream(today_iso());
}

def:protect message_thread(post_id: str) -> ThreadView {
    if verified_profile() is None {
        return ThreadView(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    return thread(post_id, today_iso());
}

def:protect react_to_message(post_id: str, kind: str) -> ActionResult {
    return denied() or respond(post_id, kind, "", None, today_iso());
}

def:protect ask_about_message(post_id: str, text: str) -> ActionResult {
    return denied() or respond(post_id, "question", text, None, today_iso());
}

def:protect offer_on_message(post_id: str, price: float, text: str) -> ActionResult {
    return denied() or respond(post_id, "offer", text, price, today_iso());
}

def:protect answer_reply(reply_id: str, text: str) -> ActionResult {
    return denied() or answer(reply_id, text, today_iso());
}

def:protect accept_reply(reply_id: str) -> ActionResult {
    return denied() or accept(reply_id, today_iso());
}

def:protect confirm_available(post_id: str) -> ActionResult {
    return denied() or confirm(post_id, today_iso());
}

def:protect apply_assistant_choice(post_id: str, value: str) -> ActionResult {
    return denied() or apply_choice_to(post_id, value, today_iso());
}

def:protect close_message(post_id: str, reason: str) -> ActionResult {
    blocked = denied();
    if blocked is not None {
        return blocked;
    }
    result = finish(post_id, today_iso(), reason);
    return ActionResult(ok=result.ok, error=result.error);
}

test "quick-reply answers parse into known facts" {
    assert parse_answers("kind:offer|category:furniture")
        == {"kind": "offer", "category": "furniture"};
    assert parse_answers("arrangement:new lease") == {"arrangement": "new lease"};
    assert parse_answers("") == {};
}

test "refinements come only from the message's own facts" {
    req = Post(
        owner_root="x",
        kind="request",
        category="furniture",
        title="Desk",
        price=40.0,
        area="Kerrytown"
    );
    values = [c.value for c in refinements(req)];
    assert values == ["budget:50", "area:any", "notify:on"];
    bare = Post(owner_root="x", kind="request", category="furniture", title="Desk");
    assert [c.value for c in refinements(bare)] == ["notify:on"];
}
