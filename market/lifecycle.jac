"""Post lifecycle (U4): publish a reviewed draft, edit, mark Done, renew; expiry on read.

Every write re-validates what the client sent: the draft card is editable, so nothing from it
is trusted. Only the poster's calls may change a post (owner check here, plus Jac ownership).
"""

import from core.clock { today_iso as clock_today }
import from datetime { date, timedelta }
import from core.auth { verified_profile }
import from core.constants { ANN_ARBOR_AREAS }
import from core.profile { valid_date, valid_time }
import from market.constants { ARRANGEMENTS }
import from market.graph {
    Post,
    KINDS,
    CATEGORIES,
    post_status,
    all_posts,
    visible_to,
    suspended_roots
}
import from market.matching { run_matching }
import from core.profile { Profile, share_with_moderators }
import from market.translation {
    translate_post_texts,
    reader_of,
    language_code,
    profile_language
}

glob ITEM_DAYS: int = 14,
     HOUSING_DAYS: int = 30,
     SERVICE_DAYS: int = 7,
     MAX_PRICE: float = 100000.0,
     EDITABLE: list[str] = [
         "kind",
         "category",
         "title",
         "description",
         "price",
         "free",
         "available_from",
         "available_until",
         "time_from",
         "time_to",
         "area",
         "route_from",
         "route_to",
         "arrangement"
     ];

"""A post as one reader sees it (U5). `title`/`description` are in `language`: the reader's
language when a guarded translation exists, else the poster's original. `ai_translated` is true
only when the shown text is a translation; then `original_title`/`original_description` hold
the poster's words in `source_language` (otherwise they are empty). Price, dates, times and
area always come from the structured fields, never from translated text. Posts from before U5
have an empty `source_language` and show as written."""
obj PostView {
    has id: str,
        mine: bool,
        status: str,
        poster_name: str,
        kind: str,
        category: str,
        title: str,
        description: str,
        price: float | None,
        free: bool,
        available_from: str,
        available_until: str,
        time_from: str,
        time_to: str,
        area: str,
        route_from: str,
        route_to: str,
        arrangement: str,
        ai_generated: bool,
        expires_on: str,
        language: str = "",
        source_language: str = "",
        ai_translated: bool = False,
        original_title: str = "",
        original_description: str = "";
}

obj PostResult {
    has ok: bool,
        error: str = "",
        post: PostView | None = None;
}

def plus_days(day: str, n: int) -> str {
    return (date.fromisoformat(day) + timedelta(days=n)).isoformat();
}

"""When a post stops being visible (exclusive), counted from `start` (YYYY-MM-DD).

Rides and other dated services end the day after their window; undated services after 7 days;
housing after 30; items after 14, or the day after they stop being available if sooner.
"""
def expiry_for(fields: dict[str, any], start: str) -> str {
    category = fields["category"];
    window_end = fields.get("available_until", "") or fields.get("available_from", "");
    if category == "service" {
        return plus_days(window_end, 1)
            if window_end
            else plus_days(start, SERVICE_DAYS);
    }
    if category == "housing" {
        return plus_days(start, HOUSING_DAYS);
    }
    usual = plus_days(start, ITEM_DAYS);
    if fields.get("available_until", "") {
        return min(usual, plus_days(fields["available_until"], 1));
    }
    return usual;
}

"""The first reason `fields` is not a publishable post, or "". Normalizes `fields` in place."""
def post_error(fields: dict[str, any], today: str = "") -> str {
    for name in [
        "kind",
        "category",
        "title",
        "description",
        "available_from",
        "available_until",
        "time_from",
        "time_to",
        "area",
        "route_from",
        "route_to",
        "arrangement"
    ] {
        value = fields.get(name, "");
        if not isinstance(value, str) {
            return f"{name} must be text.";
        }
        fields[name] = value.strip();
    }
    if fields["kind"] not in KINDS {
        return "Choose whether you're offering or looking for something.";
    }
    if fields["category"] not in CATEGORIES {
        return "Choose a category.";
    }
    if fields["title"] == "" {
        return "Add a title.";
    }
    fields["title"] = fields["title"][:80];
    fields["description"] = fields["description"][:500];
    free = fields.get("free", False);
    if not isinstance(free, bool) {
        return "free must be true or false.";
    }
    fields["free"] = free;
    price = fields.get("price", None);
    if free {
        price = None;
    }
    if price is not None {
        if isinstance(price, bool) or not isinstance(price, (int, float)) {
            return "Price must be a number.";
        }
        if price < 0 or price > MAX_PRICE {
            return "Price must be between $0 and $100,000.";
        }
        price = float(price);
    }
    fields["price"] = price;
    if not valid_date(fields["available_from"])
        or not valid_date(fields["available_until"]) {
        return "Dates must be written YYYY-MM-DD.";
    }
    if fields["available_from"]
        and fields["available_until"]
        and fields["available_from"] > fields["available_until"] {
        return "The start date is after the end date.";
    }
    window_end = fields["available_until"] or fields["available_from"];
    if today and window_end and window_end < today {
        return "That date has already passed. Pick today or a later date.";
    }
    if not valid_time(fields["time_from"]) or not valid_time(fields["time_to"]) {
        return "Times must be written HH:MM.";
    }
    if fields["area"] and fields["area"] not in ANN_ARBOR_AREAS {
        return "Choose an Ann Arbor area from the list.";
    }
    if fields["category"] == "housing" {
        if fields["arrangement"] not in ARRANGEMENTS {
            return "Say whether it's a roommate opening, sublet, lease assignment or new lease.";
        }
    } else {
        fields["arrangement"] = "";
    }
    if fields["category"] != "service" {
        fields["route_from"] = "";
        fields["route_to"] = "";
    }
    if fields["kind"] == "offer"
        and fields["category"] != "service"
        and price is None
        and not free {
        return "Add a price, or mark it free.";
    }
    return "";
}

"""The (title, description, language) a `reader` sees: the stored `reader` translation when
there is one, else the original. An empty `reader` always gets the original."""
def shown_text(post: Post, reader: str) -> tuple[str, str, str] {
    if reader and reader != post.language and reader in post.texts {
        t = post.texts[reader];
        return (t.get("title", ""), t.get("description", ""), reader);
    }
    return (post.title, post.description, post.language);
}

"""`post` as seen by a `reader` (a pilot language code, "" for the original). The poster always
sees their own words."""
def view_of(post: Post, today: str, reader: str = "") -> PostView {
    mine = post.owner_root == jid(root);
    (title, description, shown) = shown_text(post, "" if mine else reader);
    translated = shown != post.language;
    return PostView(
        id=jid(post),
        mine=mine,
        status=post_status(post, today),
        poster_name=post.poster_name,
        kind=post.kind,
        category=post.category,
        title=title,
        description=description,
        language=shown,
        source_language=post.language,
        ai_translated=translated,
        original_title=post.title if translated else "",
        original_description=post.description if translated else "",
        price=post.price,
        free=post.free,
        available_from=post.available_from,
        available_until=post.available_until,
        time_from=post.time_from,
        time_to=post.time_to,
        area=post.area,
        route_from=post.route_from,
        route_to=post.route_to,
        arrangement=post.arrangement,
        ai_generated=post.ai_generated,
        expires_on=post.expires_on
    );
}

def apply_fields(post: Post, fields: dict[str, any]) {
    post.kind = fields["kind"];
    post.category = fields["category"];
    post.title = fields["title"];
    post.description = fields["description"];
    post.price = fields["price"];
    post.free = fields["free"];
    post.available_from = fields["available_from"];
    post.available_until = fields["available_until"];
    post.time_from = fields["time_from"];
    post.time_to = fields["time_to"];
    post.area = fields["area"];
    post.route_from = fields["route_from"];
    post.route_to = fields["route_to"];
    post.arrangement = fields["arrangement"];
}

def fields_of(post: Post) -> dict[str, any] {
    return {
        "kind": post.kind,
        "category": post.category,
        "title": post.title,
        "description": post.description,
        "price": post.price,
        "free": post.free,
        "available_from": post.available_from,
        "available_until": post.available_until,
        "time_from": post.time_from,
        "time_to": post.time_to,
        "area": post.area,
        "route_from": post.route_from,
        "route_to": post.route_to,
        "arrangement": post.arrangement
    };
}

"""The caller's own post with this id, or None (unknown id, or someone else's post)."""
def own_post(post_id: str) -> Post | None {
    for p in all_posts() {
        if jid(p) == post_id and p.owner_root == jid(root) {
            return p;
        }
    }
    return None;
}

"""The language a post's text is written in: the draft's `language` if it is a well-formed code
(any 2-3 letters, so a French draft stays French), else the poster's profile language."""
def post_language(fields: dict[str, any], profile: Profile) -> str {
    given = fields.get("language", "");
    return language_code(
        given if isinstance(given, str) else "", profile_language(profile)
    );
}

"""Store `post`'s language and its title and description in every pilot language."""
def store_texts(post: Post, language: str) {
    post.language = language;
    post.texts = translate_post_texts(post.title, post.description, language);
}

"""Publish the reviewed draft `fields` as a live post, as of `today`. The reviewed native
title and description are translated here; any English copy the client sends is ignored."""
def publish(
    fields: dict[str, any], today: str, ai_generated: bool = True
) -> PostResult {
    profile = verified_profile();
    if profile is None {
        return PostResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    clean: dict[str, any] = {
        k: fields[k]
        for k in EDITABLE
        if k in fields
    };
    if jid(root) in suspended_roots() {
        return PostResult(
            ok=False, error="Your account can't post right now. Contact a moderator."
        );
    }
    error = post_error(clean, today);
    if error {
        return PostResult(ok=False, error=error);
    }
    post = root.shared ++> Post(
        owner_root=jid(root),
        poster_name=profile.display_name,
        kind=clean["kind"],
        category=clean["category"],
        title=clean["title"],
        ai_generated=ai_generated,
        published_on=today,
        expires_on=expiry_for(clean, today)
    );
    apply_fields(post, clean);
    store_texts(post, post_language(fields, profile));
    grant(post, level=AccessLevel.READ);
    share_with_moderators(post);
    run_matching(post, today);
    return PostResult(ok=True, post=view_of(post, today));
}

"""Edit the caller's own post: `changes` overrides any EDITABLE field; the result is re-validated.
Translations are redone only when the title or description changed."""
def edit(post_id: str, changes: dict[str, any], today: str) -> PostResult {
    profile = verified_profile();
    if profile is None {
        return PostResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    post = own_post(post_id);
    if post is None {
        return PostResult(ok=False, error="You can only change your own posts.");
    }
    merged = fields_of(post);
    for k in EDITABLE {
        if k in changes {
            merged[k] = changes[k];
        }
    }
    error = post_error(merged, today);
    if error {
        return PostResult(ok=False, error=error);
    }
    text_changed = merged["title"] != post.title
        or merged["description"] != post.description;
    apply_fields(post, merged);
    if text_changed {
        store_texts(post, post.language or profile_language(profile));
    }
    post.ai_generated = False;
    if not post.done {
        post.expires_on = expiry_for(merged, post.published_on or today);
    }
    run_matching(post, today);
    return PostResult(ok=True, post=view_of(post, today));
}

def finish(post_id: str, today: str) -> PostResult {
    if verified_profile() is None {
        return PostResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    post = own_post(post_id);
    if post is None {
        return PostResult(ok=False, error="You can only change your own posts.");
    }
    post.done = True;
    return PostResult(ok=True, post=view_of(post, today));
}

"""Make an expired post live again from `today`. Done posts stay done."""
def renew(post_id: str, today: str) -> PostResult {
    if verified_profile() is None {
        return PostResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    post = own_post(post_id);
    if post is None {
        return PostResult(ok=False, error="You can only change your own posts.");
    }
    if post.done {
        return PostResult(
            ok=False, error="This post is marked done. Post it again instead."
        );
    }
    post.published_on = today;
    post.expires_on = max(expiry_for(fields_of(post), today), plus_days(today, 1));
    run_matching(post, today);
    return PostResult(ok=True, post=view_of(post, today));
}

"""Live posts visible to the caller, newest first, for a `reader` language."""
def live_posts(today: str, reader: str = "") -> list[PostView] {
    posts = [
        p
        for p in visible_to(all_posts(), jid(root))
        if post_status(p, today) == "live"
    ];
    posts.sort(key=lambda (p: Post) -> str { return p.published_on; }, reverse=True);
    return [view_of(p, today, reader) for p in posts];
}

"""The caller's own posts in any status, newest first, in the poster's own words."""
def mine(today: str) -> list[PostView] {
    posts = [
        p
        for p in all_posts()
        if p.owner_root == jid(root)
    ];
    posts.sort(key=lambda (p: Post) -> str { return p.published_on; }, reverse=True);
    return [view_of(p, today) for p in posts];
}

def today_iso -> str {
    return clock_today();
}

def:protect publish_post(fields: dict[str, any]) -> PostResult {
    ai = fields.get("ai_generated", True);
    return publish(
        fields, today_iso(), ai_generated=ai if isinstance(ai, bool) else True
    );
}

def:protect edit_post(post_id: str, changes: dict[str, any]) -> PostResult {
    return edit(post_id, changes, today_iso());
}

def:protect mark_post_done(post_id: str) -> PostResult {
    return finish(post_id, today_iso());
}

def:protect renew_post(post_id: str) -> PostResult {
    return renew(post_id, today_iso());
}

def:protect list_live_posts -> list[PostView] {
    profile = verified_profile();
    if profile is None {
        return [];
    }
    return live_posts(today_iso(), reader_of(profile));
}

def:protect list_my_posts -> list[PostView] {
    return mine(today_iso());
}

test "expiry follows the category rules" {
    assert expiry_for(
        {"category": "service", "available_from": "2026-08-20"}, "2026-08-01"
    )
        == "2026-08-21";
    assert expiry_for({"category": "service"}, "2026-08-01") == "2026-08-08";
    assert expiry_for({"category": "housing"}, "2026-08-01") == "2026-08-31";
    assert expiry_for({"category": "furniture"}, "2026-08-01") == "2026-08-15";
    assert expiry_for(
        {"category": "furniture", "available_until": "2026-08-03"}, "2026-08-01"
    )
        == "2026-08-04";
    assert expiry_for(
        {"category": "furniture", "available_until": "2026-12-01"}, "2026-08-01"
    )
        == "2026-08-15";
}

test "a post is live until its expiry day, and done beats everything" {
    p = Post(
        owner_root="r",
        kind="offer",
        category="furniture",
        title="Desk",
        expires_on="2026-08-15"
    );
    assert post_status(p, "2026-08-14") == "live";
    assert post_status(p, "2026-08-15") == "expired";
    p.done = True;
    assert post_status(p, "2026-08-01") == "done";
}

test "publishable fields are validated and normalized" {
    ok: dict[str, any] = {
        "kind": "offer",
        "category": "furniture",
        "title": " Desk ",
        "price": 25
    };
    assert post_error(ok) == "" and ok["title"] == "Desk" and ok["price"] == 25.0;
    assert "price"
        in post_error(
            {"kind": "offer", "category": "furniture", "title": "Desk"}
        ).lower();
    assert post_error(
        {"kind": "offer", "category": "furniture", "title": "Desk", "free": True}
    )
        == "";
    assert post_error({"kind": "request", "category": "furniture", "title": "Desk"})
        == "";
    assert "roommate"
        in post_error(
            {"kind": "offer", "category": "housing", "title": "Room", "price": 700}
        );
    assert post_error(
        {
            "kind": "offer",
            "category": "housing",
            "title": "Room",
            "price": 700,
            "arrangement": "sublet"
        }
    )
        == "";
    assert "offering"
        in post_error(
            {"kind": "sell", "category": "furniture", "title": "x", "price": 1}
        );
    assert "area"
        in post_error(
            {
                "kind": "request",
                "category": "furniture",
                "title": "x",
                "area": "Detroit"
            }
        );
    assert "Price"
        in post_error(
            {"kind": "offer", "category": "furniture", "title": "x", "price": -1}
        );
    assert "Price"
        in post_error(
            {"kind": "offer", "category": "furniture", "title": "x", "price": "25"}
        );
    assert "after"
        in post_error(
            {
                "kind": "request",
                "category": "furniture",
                "title": "x",
                "available_from": "2026-08-20",
                "available_until": "2026-08-01"
            }
        );
    route: dict[str, any] = {
        "kind": "offer",
        "category": "furniture",
        "title": "x",
        "free": True,
        "route_from": "DTW"
    };
    assert post_error(route) == "" and route["route_from"] == "";
}
