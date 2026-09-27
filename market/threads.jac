"""Private match threads (plan 2026-09-27-003 M-R4..M-R9).

A thread is one buyer–seller conversation about one post: a `Chat` plus its `Suggestion`, readable
only by the two students (Jac grants on the Chat and each Message) and checked again on every call
(`my_chat`). Tapping "I'm interested" starts one, anchored on the post (`post_a`, owned by
`root_a`), optionally with the asker's own matching post (`post_b`), and linked back to the group
message it came from.

Inside a thread, a labelled assistant panel shows each side a summary of the offer and the
request (AI guesses marked), what fits, what's still unknown, and suggested replies. Suggestions
only fill the composer; nothing is sent or committed without the student tapping. Reserving and
marking sold change the post and every other thread about it, which then shows "Reserved for
another student" or "Sold to another student" without naming anyone. Rules code: no AI here.
"""

import from uuid { UUID }
import from datetime { datetime }
import from jaclang { JacRuntime as Jac }
import from jaclang.server.identity.app_tokens { token_create }
import from core.auth { verified_profile }
import from core.clock { today_iso }
import from core.profile { my_profile }
import from core.groups { GroupMessage, group_by_id, message_by_id }
import from market.graph {
    Post,
    Suggestion,
    Chat,
    Message,
    all_posts,
    all_suggestions,
    post_status,
    visible_to,
    pair_key,
    blocked_keys
}
import from market.lifecycle { own_post, finish }
import from market.matching { match_pair, CHAT_OPEN_PURPOSE, CHAT_OPEN_TTL_SECONDS }
import from market.connect {
    ensure_chat,
    my_chat,
    sorted_messages,
    message_view,
    send,
    MessageView,
    SendResult
}
import from market.details { facts_split, unknowns, label_guessed }

obj SideSummary {
    has post_id: str,
        role: str,
        name: str,
        title: str,
        confirmed: str,
        guesses: str,
        unknown: list[str] = [];
}

obj ThreadView {
    has ok: bool,
        error: str = "",
        id: str = "",
        title: str = "",
        other_name: str = "",
        my_role: str = "",
        privacy: str = "",
        group_id: str = "",
        group_name: str = "",
        origin_text: str = "",
        state: str = "",
        state_label: str = "",
        offer: SideSummary | None = None,
        request: SideSummary | None = None,
        fits: list[str] = [],
        open_questions: list[str] = [],
        suggestions: list[str] = [],
        actions: list[str] = [],
        can_send: bool = False,
        messages: list[MessageView] = [];
}

obj ThreadItem {
    has id: str,
        title: str,
        other_name: str,
        state: str,
        state_label: str,
        last_message: str,
        last_at: str;
}

obj ThreadResult {
    has ok: bool,
        error: str = "",
        chat_id: str = "";
}

"""The parts of a thread: (anchor post, asker's post or None, offer, request, seller, buyer)."""
def parts(
    s: Suggestion, posts: dict[str, Post]
) -> tuple[Post | None, Post | None, Post | None, Post | None, str, str] {
    anchor = posts.get(s.post_a);
    theirs = posts.get(s.post_b) if s.post_b else None;
    if anchor is None {
        return (None, theirs, None, None, s.root_a, s.root_b);
    }
    if anchor.kind == "offer" {
        return (anchor, theirs, anchor, theirs, s.root_a, s.root_b);
    }
    return (anchor, theirs, theirs, anchor, s.root_b, s.root_a);
}

def names(s: Suggestion, anchor: Post | None) -> tuple[str, str] {
    owner = (anchor.poster_name if anchor else "") or "The poster";
    asker = s.from_name or "A student";
    return (owner, asker);
}

"""The thread's state for the caller: (key, label). Derived, never stored (M-R9)."""
def thread_state(
    c: Chat, s: Suggestion, posts: dict[str, Post], today: str
) -> tuple[str, str] {
    me = jid(root);
    (anchor, theirs, offer, request, seller, buyer) = parts(s, posts);
    (owner_name, asker_name) = names(s, anchor);
    other = asker_name if me == s.root_a else owner_name;
    cid = jid(c);
    if offer is not None and offer.sold_chat {
        if offer.sold_chat == cid {
            return (
                "completed",
                "Completed · " + ("you sold it" if me == seller else "you got it")
            );
        }
        return ("unavailable", "Sold to another student");
    }
    if request is not None and request.sold_chat == cid {
        return (
            "completed",
            "Completed · " + ("they found it" if me == seller else "you found it")
        );
    }
    if s.declined {
        return ("unavailable", "Closed");
    }
    if anchor is None or post_status(anchor, today) != "live" {
        if anchor is not None and anchor.done {
            return ("unavailable", "No longer available");
        }
        return ("unavailable", "No longer available");
    }
    if offer is not None and offer.reserved_chat {
        if offer.reserved_chat == cid {
            return (
                "reserved",
                "Reserved " + ("for " + other if me == seller else "for you")
            );
        }
        return ("reserved_other", "Reserved for another student");
    }
    msgs = sorted_messages(c);
    if not msgs {
        return ("new", "New thread · say hello");
    }
    last = msgs[-1];
    if last.author_root == me {
        return (
            "awaiting",
            f"Awaiting response from {other} · since {since(last.sent_at)}"
        );
    }
    return ("your_turn", f"{other} replied · your turn");
}

def since(stamp: str) -> str {
    try {
        t = datetime.fromisoformat(stamp);
    } except ValueError {
        return stamp;
    }
    return t.strftime("%b ") + str(t.day) + t.strftime(" %H:%M");
}

def side(p: Post | None, role: str, name: str) -> SideSummary | None {
    if p is None {
        return None;
    }
    (sure, guessed) = facts_split(p);
    return SideSummary(
        post_id=jid(p),
        role=role,
        name=name,
        title=p.title,
        confirmed=sure,
        guesses=guessed,
        unknown=unknowns(p)
    );
}

"""Replies the caller might send next, from the unknowns and the state (M-R7). Placeholders in
[brackets] are for the student to fill in; nothing here states a fact they haven't given."""
def suggested_replies(
    state: str,
    me_seller: bool,
    offer: Post | None,
    request: Post | None,
    has_mine: bool
) -> list[str] {
    out: list[str] = [];
    item = (offer.title if offer else (request.title if request else "it")).lower();
    if state in ["completed", "unavailable"] {
        return ["Thanks!"] if state == "completed" else [];
    }
    if me_seller {
        if not has_mine {
            out.append(f"Hi! Yes, the {item} is still available.");
        }
        if offer is not None and not offer.condition {
            out.append("It's in [condition] condition.");
        }
        out.append("Pickup works at [place] on [day/time]. Does that suit you?");
        if state == "reserved" {
            out.append("I've reserved it for you. See you at pickup!");
        }
    } else {
        if not has_mine {
            out.append(f"Hi! Is the {item} still available?");
        }
        if offer is not None and not offer.condition {
            out.append("What condition is it in?");
        }
        if offer is not None and not offer.pickup {
            out.append("When and where could I pick it up?");
        }
        if offer is not None
            and request is not None
            and offer.price is not None
            and request.price is not None
            and request.price < offer.price {
            out.append(f"Would you take ${request.price:,.0f}?");
        }
        if state == "reserved" {
            out.append("Thanks for holding it! When should I come by?");
        }
    }
    return out[:4];
}

def thread_view(chat_id: str, today: str) -> ThreadView {
    found = my_chat(chat_id);
    if found is None {
        return ThreadView(ok=False, error="That thread isn't available.");
    }
    (c, s) = found;
    me = jid(root);
    posts: dict[str, Post] = {jid(p): p for p in visible_to(all_posts(), me)};
    (anchor, theirs, offer, request, seller, buyer) = parts(s, posts);
    if offer is not None {
        release_if_closed(offer);
    }
    (owner_name, asker_name) = names(s, anchor);
    other = asker_name if me == s.root_a else owner_name;
    seller_name = owner_name if seller == s.root_a else asker_name;
    buyer_name = owner_name if buyer == s.root_a else asker_name;
    (state, label) = thread_state(c, s, posts, today);
    fits: list[str] = [];
    if offer is not None and request is not None {
        m = match_pair(offer, request, today);
        fits = label_guessed(m.reasons, m.codes, offer, request)
            if m is not None
            else [];
    }
    open_q: list[str] = [];
    if offer is not None {
        open_q.extend([f"Offer: {u}" for u in unknowns(offer)]);
    }
    if request is not None {
        open_q.extend([f"Request: {u}" for u in unknowns(request)]);
    }
    me_seller = me == seller;
    msgs = sorted_messages(c);
    actions: list[str] = [];
    if state not in ["completed", "unavailable"] {
        mine_offer = own_post(jid(offer)) if me_seller and offer is not None else None;
        if mine_offer is not None {
            if mine_offer.reserved_chat == jid(c) {
                actions.extend(["release", "sell"]);
            } elif not mine_offer.reserved_chat {
                actions.extend(["reserve", "sell"]);
            }
        }
        mine_request = own_post(jid(request))
            if not me_seller and request is not None
            else None;
        if mine_request is not None {
            actions.append("found");
        }
        actions.append("withdraw");
    }
    g = group_by_id(s.group_id) if s.group_id else None;
    origin = message_by_id(s.message_id) if s.message_id else None;
    return ThreadView(
        ok=True,
        id=jid(c),
        title=anchor.title if anchor else "Thread",
        other_name=other,
        my_role="seller" if me_seller else "buyer",
        privacy=f"Private · only you and {other} can see this thread",
        group_id=s.group_id,
        group_name=g.name if g else "",
        origin_text=origin.text if origin else "",
        state=state,
        state_label=label,
        offer=side(offer, "Selling", seller_name),
        request=side(request, "Looking for", buyer_name),
        fits=fits,
        open_questions=open_q,
        suggestions=suggested_replies(
            state, me_seller, offer, request, any([m.author_root == me for m in msgs])
        ),
        actions=actions,
        can_send=state != "unavailable",
        messages=[message_view(m, me) for m in msgs]
    );
}

"""The caller's threads, newest activity first, each with its state."""
def my_threads(today: str) -> list[ThreadItem] {
    me = jid(root);
    posts: dict[str, Post] = {jid(p): p for p in visible_to(all_posts(), me)};
    out: list[ThreadItem] = [];
    for s in all_suggestions() {
        if me not in [s.root_a, s.root_b] or not (s.accepted_a and s.accepted_b) {
            continue;
        }
        c = ensure_chat(s);
        if c is None {
            continue;
        }
        (anchor, _, _, _, _, _) = parts(s, posts);
        (owner_name, asker_name) = names(s, anchor);
        (state, label) = thread_state(c, s, posts, today);
        msgs = sorted_messages(c);
        out.append(
            ThreadItem(
                id=jid(c),
                title=anchor.title if anchor else "Thread",
                other_name=asker_name if me == s.root_a else owner_name,
                state=state,
                state_label=label,
                last_message=message_view(msgs[-1], me).text if msgs else "",
                last_at=msgs[-1].sent_at if msgs else c.created_on
            )
        );
    }
    out.sort(key=lambda (t: ThreadItem) -> str { return t.last_at; }, reverse=True);
    return out;
}

"""Start or reopen the caller's thread about `post_id` (M-R4). `via_post_id` is the caller's own
post that matched it, if any. One thread per pair of students per pair of posts."""
def start(
    post_id: str, via_post_id: str, group_id: str, message_id: str, today: str
) -> ThreadResult {
    me = jid(root);
    posts: dict[str, Post] = {jid(p): p for p in visible_to(all_posts(), me)};
    post = posts.get(post_id);
    if post is None {
        return ThreadResult(ok=False, error="That message isn't available.");
    }
    if post.owner_root == me {
        return ThreadResult(ok=False, error="That's your own message.");
    }
    if post_status(post, today) != "live" {
        return ThreadResult(ok=False, error="This message is closed.");
    }
    if pair_key(me, post.owner_root) in blocked_keys() {
        return ThreadResult(ok=False, error="You can't message this student.");
    }
    via = ""
        if not via_post_id
        else (via_post_id if own_post(via_post_id) is not None else "");
    pair = set([post_id, via]) if via else set([post_id]);
    s: Suggestion | None = None;
    for existing in all_suggestions() {
        if existing.origin != "direct" or existing.declined {
            continue;
        }
        if set([existing.root_a, existing.root_b]) != set([me, post.owner_root]) {
            continue;
        }
        posts_of = set(
            [
                x
                for x in [existing.post_a, existing.post_b]
                if x
            ]
        );
        if post_id in posts_of and (not via or via in posts_of or posts_of == pair) {
            s = existing;
            break;
        }
    }
    if not message_id {
        # From a match card: link the thread to the group message the post came from.
        for m in [root.shared-->][?:GroupMessage] {
            if post_id in m.post_ids {
                message_id = jid(m);
                group_id = m.group_id;
            }
        }
    }
    if s is None {
        s = root.shared ++> Suggestion(
            post_a=post_id,
            post_b=via,
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
            from_name=my_profile().display_name or "A student",
            group_id=group_id or post.topic_group_id,
            message_id=message_id
        );
        s.open_token = token_create(
            CHAT_OPEN_PURPOSE, subject=jid(s), ttl_seconds=CHAT_OPEN_TTL_SECONDS
        );
        Jac.allow_root(s, UUID(post.owner_root), AccessLevel.WRITE);  # jac:ignore[E1053]
    }
    chat = ensure_chat(s);
    if chat is None {
        return ThreadResult(ok=False, error="Couldn't open the thread. Try again.");
    }
    return ThreadResult(ok=True, chat_id=jid(chat));
}

"""Seller actions on the offer in this thread (M-R8): reserve, release, sell. The caller must own
the offer; the buyer is the other participant."""
def seller_action(chat_id: str, action: str, today: str) -> ThreadResult {
    found = my_chat(chat_id);
    if found is None {
        return ThreadResult(ok=False, error="That thread isn't available.");
    }
    (c, s) = found;
    me = jid(root);
    posts: dict[str, Post] = {jid(p): p for p in visible_to(all_posts(), me)};
    (anchor, _, offer, _, seller, buyer) = parts(s, posts);
    if offer is None or seller != me or own_post(jid(offer)) is None {
        return ThreadResult(ok=False, error="Only the seller can do that.");
    }
    mine = own_post(jid(offer));
    if mine is None or post_status(mine, today) != "live" {
        return ThreadResult(ok=False, error="This item is no longer available.");
    }
    if action == "reserve" {
        if mine.reserved_chat and mine.reserved_chat != jid(c) {
            return ThreadResult(
                ok=False, error="It's reserved for another student. Release that first."
            );
        }
        mine.reserved_for = buyer;
        mine.reserved_chat = jid(c);
    } elif action == "release" {
        if mine.reserved_chat != jid(c) {
            return ThreadResult(ok=False, error="It isn't reserved in this thread.");
        }
        mine.reserved_for = "";
        mine.reserved_chat = "";
    } elif action == "sell" {
        finish(jid(mine), today, "sold");
        mine.sold_to = buyer;
        mine.sold_chat = jid(c);
        mine.reserved_for = "";
        mine.reserved_chat = "";
    } else {
        return ThreadResult(ok=False, error="Unknown action.");
    }
    return ThreadResult(ok=True, chat_id=jid(c));
}

"""The buyer closes their own request as found in this thread."""
def found_here(chat_id: str, today: str) -> ThreadResult {
    found = my_chat(chat_id);
    if found is None {
        return ThreadResult(ok=False, error="That thread isn't available.");
    }
    (c, s) = found;
    posts: dict[str, Post] = {jid(p): p for p in visible_to(all_posts(), jid(root))};
    (_, _, _, request, _, _) = parts(s, posts);
    mine = own_post(jid(request)) if request is not None else None;
    if mine is None {
        return ThreadResult(
            ok=False, error="Only the student looking for it can do that."
        );
    }
    finish(jid(mine), today, "found");
    mine.sold_chat = jid(c);
    return ThreadResult(ok=True, chat_id=jid(c));
}

"""Either participant closes the thread. A reservation held in it is released."""
def withdraw(chat_id: str) -> ThreadResult {
    found = my_chat(chat_id);
    if found is None {
        return ThreadResult(ok=False, error="That thread isn't available.");
    }
    (c, s) = found;
    s.declined = True;
    # The seller closing it releases their reservation now; a buyer closing it releases it the
    # next time the seller looks (release_if_closed).
    for p in visible_to(all_posts(), jid(root)) {
        if p.reserved_chat == jid(c) {
            mine = own_post(jid(p));
            if mine is not None {
                mine.reserved_for = "";
                mine.reserved_chat = "";
            }
        }
    }
    return ThreadResult(ok=True, chat_id=jid(c));
}

"""The seller's post keeps no reservation for a thread the buyer has closed. The buyer can't write
the seller's post, so the seller's own reads release it."""
def release_if_closed(p: Post) {
    if not p.reserved_chat or p.owner_root != jid(root) {
        return;
    }
    found = my_chat(p.reserved_chat);
    if found is None or found[1].declined {
        p.reserved_for = "";
        p.reserved_chat = "";
    }
}

"""Send in a thread: allowed while it's open, and after completion so the pair can arrange pickup."""
def send_here(chat_id: str, text: str, today: str) -> SendResult {
    found = my_chat(chat_id);
    if found is None {
        return SendResult(ok=False, error="That thread isn't available.");
    }
    (c, s) = found;
    posts: dict[str, Post] = {jid(p): p for p in visible_to(all_posts(), jid(root))};
    (state, _) = thread_state(c, s, posts, today);
    if state == "unavailable" {
        return SendResult(ok=False, error="This thread is closed.");
    }
    profile = verified_profile();
    if profile is None {
        return SendResult(ok=False, error="Sign in to send messages.");
    }
    return send(chat_id, text, profile, allow_closed=state == "completed");
}

def denied -> str {
    return "" if verified_profile() is not None else "Sign in with your UMich email.";
}

def:protect start_thread(
    post_id: str, via_post_id: str, group_id: str, message_id: str
) -> ThreadResult {
    return ThreadResult(ok=False, error=denied())
        if denied()
        else start(post_id, via_post_id, group_id, message_id, today_iso());
}

def:protect get_thread(chat_id: str) -> ThreadView {
    return ThreadView(ok=False, error=denied())
        if denied()
        else thread_view(chat_id, today_iso());
}

def:protect list_threads -> list[ThreadItem] {
    return [] if denied() else my_threads(today_iso());
}

def:protect thread_send(chat_id: str, text: str) -> SendResult {
    return SendResult(ok=False, error=denied())
        if denied()
        else send_here(chat_id, text, today_iso());
}

def:protect thread_action(chat_id: str, action: str) -> ThreadResult {
    if denied() {
        return ThreadResult(ok=False, error=denied());
    }
    if action == "found" {
        return found_here(chat_id, today_iso());
    }
    if action == "withdraw" {
        return withdraw(chat_id);
    }
    return seller_action(chat_id, action, today_iso());
}
