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

glob KINDS: list[str] = ["offer", "request"],
     CATEGORIES: list[str] = [
         "furniture",
         "essentials",
         "housing",
         "vehicle",
         "service"
     ];

"""One marketplace post. `language` is the language the poster wrote `title`/`description` in;
`texts` maps a language to {"title", "description"}: the original under `language` plus every
pilot-language translation that passed the number guard (U5). Posts from before U5 have
neither and render as written."""
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
        language: str = "",
        texts: dict[str, dict[str, str]] = {};
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
`reasons` is the English text; `reason_codes` holds one {"code", "values"} entry per reason so
readers see them in their language (suggestions made before that have none and show English).
`language_a`/`language_b` is each side's language, recorded when that side taps Connect; empty
for sides that connected before chat translation, whose chat is not translated.
"""
node Suggestion {
    has post_a: str,
        post_b: str,
        root_a: str,
        root_b: str,
        score: int,
        reasons: list[str],
        created_on: str,
        reason_codes: list[dict[str, any]] = [],
        accepted_a: bool = False,
        accepted_b: bool = False,
        declined: bool = False,
        withdrawn: bool = False,
        seen_a: bool = False,
        seen_b: bool = False,
        emailed_a: bool = False,
        emailed_b: bool = False,
        open_token: str = "",
        language_a: str = "",
        language_b: str = "";
}

"""The private chat for one connected suggestion. Shared WRITE with exactly its two students;
open or closed is derived from the suggestion's posts, never stored."""
node Chat {
    has suggestion_id: str,
        root_a: str,
        root_b: str,
        created_on: str;
}

"""One chat message, attached to its Chat and readable by both students. `text` is what the
author wrote in `language`; `translated_text` is the stored AI translation into
`translated_language` for the other student, empty when none was made or it failed the guard."""
node Message {
    has author_root: str,
        text: str,
        sent_at: str,
        language: str = "",
        translated_text: str = "",
        translated_language: str = "";
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
