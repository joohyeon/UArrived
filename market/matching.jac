"""Two-way deterministic matching (U5, R6, R7, R20).

Rules only: no AI here (scripts/check_rules.sh enforces it). Every reason is built from facts
present on both posts, the same facts that decided the match.

Pairs: an offer with a request in the same category, or two ride requests on the same route
(two arriving students can share a taxi). Matching runs whenever a post is published, edited
or renewed; that post's pending suggestions are withdrawn and rebuilt, so no stale reason
survives an edit.
"""

import from uuid { UUID }
import from jaclang { JacRuntime as Jac }
import from jaclang.server.identity.app_tokens { token_create }
import from market.graph { Post, Suggestion, post_status, all_posts, all_suggestions }

glob MAX_SUGGESTIONS_PER_POST: int = 10,
     CHAT_OPEN_PURPOSE: str = "chat-open",
     CHAT_OPEN_TTL_SECONDS: int = 90 * 86400,
     RIDE_GAP_MINUTES: int = 120;

obj Match {
    has score: int,
        reasons: list[str];
}

def money(x: float) -> str {
    return f"${x:,.0f}" if x == int(x) else f"${x:,.2f}";
}

def is_ride(p: Post) -> bool {
    return p.category == "service" and p.route_from != "" and p.route_to != "";
}

"""Canonical place name so 'DTW', 'Detroit Metro Airport' and 'the airport' compare equal."""
def place(text: str) -> str {
    t = text.strip().lower();
    if "dtw" in t or "detroit metro" in t or "airport" in t {
        return "dtw";
    }
    if "ann arbor" in t or "campus" in t or "a2" == t {
        return "ann arbor";
    }
    return t;
}

"""(start, end) dates of a post's window, or None when it gives no dates."""
def window(p: Post) -> tuple[str, str] | None {
    start = p.available_from or p.available_until;
    end = p.available_until or p.available_from;
    return (start, end) if start else None;
}

def minutes(t: str) -> int {
    parts = t.split(":");
    return int(parts[0]) * 60 + int(parts[1]);
}

"""Minutes between two posts' time windows on the same day (0 if they overlap), or None if
either has no time or they are on different or unknown days."""
def time_gap(a: Post, b: Post) -> int | None {
    if not (
        a.time_from
        and b.time_from
        and a.available_from
        and a.available_from == b.available_from
    ) {
        return None;
    }
    (a0, b0) = (minutes(a.time_from), minutes(b.time_from));
    a1 = minutes(a.time_to) if a.time_to else a0;
    b1 = minutes(b.time_to) if b.time_to else b0;
    return max(0, max(a0, b0) - min(a1, b1));
}

"""Whether `a` and `b` match, with a score and fact-only reasons, as of `today`."""
def match_pair(a: Post, b: Post, today: str) -> Match | None {
    if a.owner_root == b.owner_root or a.category != b.category {
        return None;
    }
    if post_status(a, today) != "live" or post_status(b, today) != "live" {
        return None;
    }
    rides = is_ride(a) or is_ride(b);
    share = is_ride(a) and is_ride(b) and a.kind == "request" and b.kind == "request";
    if not share and a.kind == b.kind {
        return None;
    }
    if rides and not (is_ride(a) and is_ride(b)) {
        return None;
    }
    if rides
        and (
            place(a.route_from) != place(b.route_from)
            or place(a.route_to) != place(b.route_to)
        ) {
        return None;
    }
    offer = a if a.kind == "offer" else b;
    request = b if offer is a else a;
    score = 50;
    reasons: list[str] = [];
    if rides {
        reasons.append(f"Same route: {a.route_from} to {a.route_to}");
    }
    (wa, wb) = (window(a), window(b));
    if wa and wb {
        if wa[0] > wb[1] or wb[0] > wa[1] {
            return None;
        }
        score += 20;
        reasons.append(
            "Same day"
                if rides and wa[0] == wa[1] == wb[0] == wb[1]
                else "Dates overlap"
        );
    }
    gap = time_gap(a, b);
    if gap is not None {
        if gap > RIDE_GAP_MINUTES {
            return None;
        }
        score += 15;
        reasons.append(
            "Times overlap" if gap == 0 else f"Times are {gap} minutes apart"
        );
    }
    if not share {
        if offer.free {
            score += 15;
            reasons.append("Free");
        } elif offer.price is not None and request.price is not None {
            if offer.price > request.price {
                return None;
            }
            score += 10
                + min(
                    5, int((request.price - offer.price) / max(request.price, 1.0) * 10)
                );
            reasons.append(
                f"{money(offer.price)} is within the {money(request.price)} budget"
            );
        }
        if a.category == "housing"
            and offer.arrangement
            and request.arrangement
            and offer.arrangement != request.arrangement {
            return None;
        }
        if a.category == "housing"
            and offer.arrangement
            and offer.arrangement == request.arrangement {
            reasons.append(f"Both want a {offer.arrangement}");
        }
    }
    if a.area and b.area and a.area == b.area and a.area != "Other" {
        score += 15;
        reasons.append(f"Both in {a.area}");
    }
    return Match(score=score, reasons=reasons);
}

def involves(s: Suggestion, post_id: str) -> bool {
    return s.post_a == post_id or s.post_b == post_id;
}

"""Pending = nobody has accepted or declined yet, and it is still in force."""
def pending(s: Suggestion) -> bool {
    return not (s.withdrawn or s.declined or s.accepted_a or s.accepted_b);
}

"""Withdraw every pending suggestion involving `post_id`. Accepted and declined ones stay."""
def withdraw_pending(post_id: str) {
    for s in all_suggestions() {
        if involves(s, post_id) and pending(s) {
            s.withdrawn = True;
        }
    }
}

"""Order a pair as (a, b): the offer first, or for two requests the smaller id first."""
def ordered(x: Post, y: Post) -> tuple[Post, Post] {
    if x.kind != y.kind {
        return (x, y) if x.kind == "offer" else (y, x);
    }
    return (x, y) if jid(x) < jid(y) else (y, x);
}

"""Re-match `post` against every live post and create suggestions. Returns those created."""
def run_matching(post: Post, today: str) -> list[Suggestion] {
    post_id = jid(post);
    withdraw_pending(post_id);
    if post.suggestions_stopped or post_status(post, today) != "live" {
        return [];
    }
    taken: set[str] = set();
    for s in all_suggestions() {
        if involves(s, post_id) and not s.withdrawn {
            taken.add(s.post_b if s.post_a == post_id else s.post_a);
        }
    }
    found: list[tuple[int, str, Post, Match]] = [];
    for other in all_posts() {
        oid = jid(other);
        if oid == post_id or oid in taken or other.suggestions_stopped {
            continue;
        }
        m = match_pair(post, other, today);
        if m is not None {
            found.append((m.score, oid, other, m));
        }
    }
    found.sort(
        key=lambda (f: tuple[int, str, Post, Match]) -> tuple[int, str] { return (
            -f[0],
            f[1]
        ); }
    );
    made: list[Suggestion] = [];
    for (score, oid, other, m) in found[:MAX_SUGGESTIONS_PER_POST] {
        (a, b) = ordered(post, other);
        s = root.shared ++> Suggestion(
            post_a=jid(a),
            post_b=jid(b),
            root_a=a.owner_root,
            root_b=b.owner_root,
            score=score,
            reasons=m.reasons,
            created_on=today,
            emailed_a=a.owner_root == post.owner_root,
            emailed_b=b.owner_root == post.owner_root,
            seen_a=a.owner_root == post.owner_root,
            seen_b=b.owner_root == post.owner_root
        );
        s.open_token = token_create(
            CHAT_OPEN_PURPOSE, subject=jid(s), ttl_seconds=CHAT_OPEN_TTL_SECONDS
        );
        Jac.allow_root(s, UUID(other.owner_root), AccessLevel.WRITE);  # jac:ignore[E1053]
        made.append(s);
    }
    return made;
}

test "a cheap desk offer matches a desk request with an overlapping move-in week (AE2)" {
    offer = Post(
        owner_root="jae",
        kind="offer",
        category="furniture",
        title="Desk",
        price=25.0,
        available_from="2026-08-18",
        available_until="2026-08-25",
        area="Central Campus"
    );
    request = Post(
        owner_root="mina",
        kind="request",
        category="furniture",
        title="Need a desk",
        price=50.0,
        available_from="2026-08-20",
        available_until="2026-08-22",
        area="Central Campus"
    );
    m = match_pair(offer, request, "2026-08-01");
    assert m is not None;
    assert "Dates overlap" in m.reasons;
    assert "$25 is within the $50 budget" in m.reasons;
    assert "Both in Central Campus" in m.reasons;
    assert match_pair(request, offer, "2026-08-01") is not None;
}

test "hard filters reject wrong category, same kind, same student, budget and dates" {
    desk = Post(
        owner_root="jae", kind="offer", category="furniture", title="Desk", price=60.0
    );
    assert match_pair(
        desk,
        Post(owner_root="mina", kind="request", category="essentials", title="x"),
        "2026-08-01"
    )
        is None;
    assert match_pair(
        desk,
        Post(
            owner_root="mina", kind="offer", category="furniture", title="x", price=5.0
        ),
        "2026-08-01"
    )
        is None;
    assert match_pair(
        desk,
        Post(owner_root="jae", kind="request", category="furniture", title="x"),
        "2026-08-01"
    )
        is None;
    assert match_pair(
        desk,
        Post(
            owner_root="mina",
            kind="request",
            category="furniture",
            title="x",
            price=50.0
        ),
        "2026-08-01"
    )
        is None;
    late = Post(
        owner_root="jae",
        kind="offer",
        category="furniture",
        title="Desk",
        price=5.0,
        available_from="2026-08-01",
        available_until="2026-08-10"
    );
    early = Post(
        owner_root="mina",
        kind="request",
        category="furniture",
        title="x",
        available_from="2026-08-11"
    );
    assert match_pair(late, early, "2026-08-01") is None;
}

test "windows touching on one day overlap; a day apart do not" {
    a = Post(
        owner_root="jae",
        kind="offer",
        category="furniture",
        title="Desk",
        free=True,
        available_from="2026-08-01",
        available_until="2026-08-10"
    );
    touch = Post(
        owner_root="mina",
        kind="request",
        category="furniture",
        title="x",
        available_from="2026-08-10"
    );
    apart = Post(
        owner_root="mina",
        kind="request",
        category="furniture",
        title="x",
        available_from="2026-08-11"
    );
    assert match_pair(a, touch, "2026-08-01") is not None;
    assert match_pair(a, apart, "2026-08-01") is None;
}

test "without a price on both sides there is no budget filter and no budget reason" {
    offer = Post(
        owner_root="jae", kind="offer", category="essentials", title="Lamp", price=15.0
    );
    request = Post(
        owner_root="mina", kind="request", category="essentials", title="Lamp please"
    );
    m = match_pair(offer, request, "2026-08-01");
    assert m is not None and not any(["budget" in r for r in m.reasons]);
}

test "two ride requests from DTW within two hours match each other" {
    a = Post(
        owner_root="jae",
        kind="request",
        category="service",
        title="Ride",
        route_from="DTW",
        route_to="Ann Arbor",
        available_from="2026-08-20",
        time_from="14:00",
        time_to="15:00"
    );
    b = Post(
        owner_root="mina",
        kind="request",
        category="service",
        title="Ride",
        route_from="Detroit Metro Airport",
        route_to="ann arbor",
        available_from="2026-08-20",
        time_from="16:30"
    );
    m = match_pair(a, b, "2026-08-01");
    assert m is not None and "Times are 90 minutes apart" in m.reasons;
    far = Post(
        owner_root="mina",
        kind="request",
        category="service",
        title="Ride",
        route_from="DTW",
        route_to="Ann Arbor",
        available_from="2026-08-20",
        time_from="19:00"
    );
    assert match_pair(a, far, "2026-08-01") is None;
    other_day = Post(
        owner_root="mina",
        kind="request",
        category="service",
        title="Ride",
        route_from="DTW",
        route_to="Ann Arbor",
        available_from="2026-08-21",
        time_from="14:00"
    );
    assert match_pair(a, other_day, "2026-08-01") is None;
}

test "a ride never matches a non-ride service" {
    ride = Post(
        owner_root="jae",
        kind="request",
        category="service",
        title="Ride",
        route_from="DTW",
        route_to="Ann Arbor"
    );
    moving = Post(
        owner_root="mina", kind="offer", category="service", title="Help moving"
    );
    assert match_pair(ride, moving, "2026-08-01") is None;
}

test "housing arrangements must agree when both posts state one" {
    sublet = Post(
        owner_root="jae",
        kind="offer",
        category="housing",
        title="Room",
        price=700.0,
        arrangement="sublet"
    );
    wants_sublet = Post(
        owner_root="mina",
        kind="request",
        category="housing",
        title="x",
        price=800.0,
        arrangement="sublet"
    );
    wants_lease = Post(
        owner_root="mina",
        kind="request",
        category="housing",
        title="x",
        price=800.0,
        arrangement="new lease"
    );
    both = match_pair(sublet, wants_sublet, "2026-08-01");
    assert both is not None and "Both want a sublet" in both.reasons;
    assert match_pair(sublet, wants_lease, "2026-08-01") is None;
}

test "done or expired posts never match" {
    offer = Post(
        owner_root="jae",
        kind="offer",
        category="furniture",
        title="Desk",
        free=True,
        expires_on="2026-08-05"
    );
    request = Post(owner_root="mina", kind="request", category="furniture", title="x");
    assert match_pair(offer, request, "2026-08-05") is None;
    request.done = True;
    assert match_pair(offer, request, "2026-08-01") is None;
}

test "every reason is a fact present on the posts" {
    offer = Post(
        owner_root="jae",
        kind="offer",
        category="furniture",
        title="Desk",
        price=25.0,
        available_from="2026-08-18",
        area="Kerrytown"
    );
    request = Post(
        owner_root="mina",
        kind="request",
        category="furniture",
        title="x",
        price=50.0,
        available_from="2026-08-18",
        area="North Campus"
    );
    m = match_pair(offer, request, "2026-08-01");
    assert m is not None;
    assert not any(["Kerrytown" in r or "North Campus" in r for r in m.reasons]);
    for r in m.reasons {
        assert r in ["Dates overlap", "$25 is within the $50 budget"];
    }
}
