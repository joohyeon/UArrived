"""Marketplace graph: the shared records every marketplace unit reads and writes.

Where things live (plan, Key Technical Decisions; doc-review P1s):
- Posts attach to `root.shared`, owned by their poster and granted READ to everyone, so every
  student finds them with one traversal and only the poster's calls can change them.
- A post's effective status (live, done, expired) is computed on read, never stored on the
  records that depend on it, so expiry closes suggestions and chats without a job and without
  anyone writing to a node another student owns.
"""

import os;
import hashlib;
import from datetime { date }

glob KINDS: list[str] = ["offer", "request"],
     CATEGORIES: list[str] = [
         "furniture",
         "essentials",
         "housing",
         "vehicle",
         "service"
     ];

node Post {
    has owner_root: str,
        kind: str,
        category: str,
        title: str,
        poster_name: str = "",
        description: str = "",
        price: float | None = None,
        free: bool = False,
        available_from: str = "",
        available_until: str = "",
        time_from: str = "",
        time_to: str = "",
        area: str = "",
        route_from: str = "",
        route_to: str = "",
        arrangement: str = "",
        ai_generated: bool = True,
        published_on: str = "",
        expires_on: str = "",
        done: bool = False,
        suggestions_stopped: bool = False,
        hidden: bool = False,
        confirmed_on: str = "",
        published_at: str = "",
        constraints: list[str] = [],
        closed_reason: str = "",
        nudged: bool = False;
}

"""live, done, expired or hidden (by a moderator), as of `today` (YYYY-MM-DD). A post is visible while today < expires_on."""
def post_status(post: Post, today: str) -> str {
    if post.hidden {
        return "hidden";
    }
    if post.done {
        return "done";
    }
    if post.expires_on and today >= post.expires_on {
        return "expired";
    }
    return "live";
}

def is_live(post: Post, today: str) -> bool {
    return post_status(post, today) == "live";
}

"""The public commons (`root.shared`), or `commons` when a caller passes one explicitly.

Plain (non-served) tests pass their own root: after a served test has shut down in the same
process, `root.shared` can point at that server's gone root.
"""
def commons_or_shared(commons: any = None) -> any {
    return commons if commons is not None else root.shared;
}

"""Every post on the commons that the caller is allowed to see."""
def all_posts(commons: any = None) -> list[Post] {
    return [commons_or_shared(commons)-->][?:Post];
}

"""One suggested pairing of two posts, shared WRITE with exactly its two students.

`post_a` is the offer (or, for two ride requests, the one with the smaller id); `post_b` the
other. Acceptance is per side (U6). `withdrawn` means matching replaced or stopped it.
"""
node Suggestion {
    has post_a: str,
        post_b: str,
        root_a: str,
        root_b: str,
        score: int,
        reasons: list[str],
        created_on: str,
        accepted_a: bool = False,
        accepted_b: bool = False,
        declined: bool = False,
        withdrawn: bool = False,
        seen_a: bool = False,
        seen_b: bool = False,
        emailed_a: bool = False,
        emailed_b: bool = False,
        origin: str = "match",
        reply_id: str = "",
        open_token: str = "";
}

"""The private chat for one connected suggestion. Shared WRITE with exactly its two students;
open or closed is derived from the suggestion's posts, never stored."""
node Chat {
    has suggestion_id: str,
        root_a: str,
        root_b: str,
        created_on: str;
}

"""One chat message, attached to its Chat and readable by both students."""
node Message {
    has author_root: str,
        text: str,
        sent_at: str;
}

def all_chats -> list[Chat] {
    return [root.shared-->][?:Chat];
}

"""Every suggestion the caller is allowed to see (the commons filters by grant)."""
def all_suggestions(commons: any = None) -> list[Suggestion] {
    return [commons_or_shared(commons)-->][?:Suggestion];
}

"""A block between two students, stored only as a one-way key of the pair so matching can check it
but no one can read who blocked whom. Readable by everyone."""
node Block {
    has pair_key: str;

    def __jac_access__ -> AccessLevel | None {
        return AccessLevel.READ;
    }
}

"""A report of a post or chat. Shared WRITE with every moderator; never with other students."""
node Report {
    has reporter_root: str,
        post_id: str,
        chat_id: str,
        reason: str,
        created_at: str,
        resolved: bool = False;
}

def all_blocks(commons: any = None) -> list[Block] {
    return [commons_or_shared(commons)-->][?:Block];
}

def all_reports(commons: any = None) -> list[Report] {
    return [commons_or_shared(commons)-->][?:Report];
}

"""One-way key for a pair of roots, the same whichever order they come in."""
def pair_key(a: str, b: str) -> str {
    salt = os.environ.get("UARRIVED_BLOCK_SALT", "uarrived-blocks");
    (x, y) = (a, b) if a < b else (b, a);
    return hashlib.sha256(f"{salt}|{x}|{y}".encode()).hexdigest();
}

def blocked_keys(commons: any = None) -> set[str] {
    return {b.pair_key for b in all_blocks(commons)};
}

"""A student a moderator suspended (U11): they can't publish, and their posts are hidden from
everyone else. Readable by everyone; holds only a root id."""
node Suspension {
    has root_id: str;

    def __jac_access__ -> AccessLevel | None {
        return AccessLevel.READ;
    }
}

def suspended_roots(commons: any = None) -> set[str] {
    return {x.root_id for x in [commons_or_shared(commons)-->][?:Suspension]};
}

"""The posts in `posts` that `me` should see: not from a student either side has blocked, and
not from a suspended student (their own posts always stay visible to them)."""
def visible_to(posts: list[Post], me: str, commons: any = None) -> list[Post] {
    blocked = blocked_keys(commons);
    suspended = suspended_roots(commons);
    return [
        p
        for p in posts
        if p.owner_root == me
            or (
                p.owner_root not in suspended
                and pair_key(me, p.owner_root) not in blocked
            )
    ];
}

glob CONFIRMED_DAYS: int = 3,
     REPLY_KINDS: list[str] = [
         "interested",
         "available",
         "question",
         "offer",
         "answer"
     ];

"""For offers: "confirmed" if the poster confirmed it (posted, edited, replied or tapped Still
available) within CONFIRMED_DAYS, else "needs_checking". Requests are always "active"."""
def availability(post: Post, today: str) -> str {
    if post.kind != "offer" {
        return "active";
    }
    if not post.confirmed_on {
        return "needs_checking";
    }
    age = (date.fromisoformat(today) - date.fromisoformat(post.confirmed_on)).days;
    return "confirmed" if age <= CONFIRMED_DAYS else "needs_checking";
}

"""Things a student should know before acting on `post`, as short plain statements."""
def limitations(post: Post, today: str) -> list[str] {
    out: list[str] = [];
    if post.kind == "offer"
        and post.price is None
        and not post.free
        and post.category != "service" {
        out.append("Price not stated");
    }
    if availability(post, today) == "needs_checking" {
        out.append(
            f"Availability not confirmed since {post.confirmed_on}: ask first"
                if post.confirmed_on
                else "Availability not confirmed: ask first"
        );
    }
    if not post.area and post.category != "service" {
        out.append("Area not given");
    }
    return out + [c for c in post.constraints];
}

"""A reaction, question, offer or answer on a message. Visible only to the poster and its author
(and, for an answer, the student it answers)."""
node Reply {
    has post_id: str,
        author_root: str,
        to_root: str,
        kind: str,
        created_at: str,
        text: str = "",
        offer_price: float | None = None,
        accepted: bool = False,
        seen_by_to: bool = False,
        emailed: bool = False;
}

"""A public, content-free count of replies on a message (what everyone else sees)."""
node ReplyTick {
    has post_id: str,
        kind: str;

    def __jac_access__ -> AccessLevel | None {
        return AccessLevel.READ;
    }
}

"""The assistant's note in a poster's thread (labeled as automated in the UI). Visible only to the
poster. `items` are real matched posts: [{"post_id", "title", "reasons", "limits", "availability"}]."""
node AssistantNote {
    has post_id: str,
        kind: str,
        text: str,
        created_at: str,
        items: list[dict[str, any]] = [],
        choices: list[str] = [];
}

def all_replies(commons: any = None) -> list[Reply] {
    return [commons_or_shared(commons)-->][?:Reply];
}

def reply_counts(post_id: str, commons: any = None) -> dict[str, int] {
    counts: dict[str, int] = {};
    for t in [commons_or_shared(commons)-->][?:ReplyTick] {
        if t.post_id == post_id {
            counts[t.kind] = counts.get(t.kind, 0) + 1;
        }
    }
    return counts;
}

def notes_for(post_id: str, commons: any = None) -> list[AssistantNote] {
    notes = [
        n
        for n in [commons_or_shared(commons)-->][?:AssistantNote]
        if n.post_id == post_id
    ];
    notes.sort(key=lambda (n: AssistantNote) -> str { return n.created_at; });
    return notes;
}

test "offers are confirmed for three days, then need checking; requests are always active" {
    offer = Post(
        owner_root="x",
        kind="offer",
        category="furniture",
        title="Desk",
        price=25.0,
        confirmed_on="2026-09-01",
        area="Kerrytown"
    );
    assert availability(offer, "2026-09-04") == "confirmed";
    assert availability(offer, "2026-09-05") == "needs_checking";
    assert availability(
        Post(owner_root="x", kind="request", category="furniture", title="x"),
        "2026-09-05"
    )
        == "active";
    assert "Availability not confirmed since 2026-09-01: ask first"
        in limitations(offer, "2026-09-05");
    assert limitations(offer, "2026-09-02") == [];
}

test "limitations name missing price and area and the poster's own conditions" {
    p = Post(
        owner_root="x",
        kind="offer",
        category="furniture",
        title="Sofa",
        confirmed_on="2026-09-01",
        constraints=["Pickup only"]
    );
    assert limitations(p, "2026-09-01")
        == ["Price not stated", "Area not given", "Pickup only"];
}
