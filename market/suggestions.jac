"""The caller's suggestions (U5): list them, and stop suggestions for one of their posts (R10).

A suggestion's status is derived on read from its posts: if either post is done or expired, the
suggestion is closed, with nothing written to it (the doc-review expiry-cascade fix).
"""

import from core.clock { today_iso as clock_today }
import from datetime { date }
import from core.auth { verified_profile }
import from market.graph { Post, Suggestion, post_status, all_posts, all_suggestions }
import from market.lifecycle { PostView, view_of, own_post }
import from market.matching { withdraw_pending }

"""A suggestion as one of its two students sees it."""
obj SuggestionView {
    has id: str,
        status: str,
        score: int,
        reasons: list[str],
        my_post: PostView,
        other_post: PostView,
        i_accepted: bool,
        unread: bool;
}

"""open, connected, closed, declined or withdrawn, as of `today`."""
def suggestion_status(
    s: Suggestion, a: Post | None, b: Post | None, today: str
) -> str {
    if s.withdrawn {
        return "withdrawn";
    }
    if s.declined {
        return "declined";
    }
    if s.origin == "reply" {
        if a is None or post_status(a, today) != "live" {
            return "closed";
        }
    } elif a is None
        or b is None
        or post_status(a, today) != "live"
        or post_status(b, today) != "live" {
        return "closed";
    }
    return "connected" if s.accepted_a and s.accepted_b else "open";
}

"""The caller's suggestions, best first. Declined and withdrawn ones never show (AE3); closed
ones show only if the pair had connected, so the chat stays findable."""
def my_suggestions(today: str) -> list[SuggestionView] {
    me = jid(root);
    posts: dict[str, Post] = {jid(p): p for p in all_posts()};
    views: list[SuggestionView] = [];
    for s in all_suggestions() {
        if me != s.root_a and me != s.root_b {
            continue;
        }
        (a, b) = (posts.get(s.post_a), posts.get(s.post_b));
        if s.origin == "reply" {
            continue;
        }
        status = suggestion_status(s, a, b, today);
        connected = s.accepted_a and s.accepted_b;
        if status in ["withdrawn", "declined"]
            or (status == "closed" and not connected) {
            continue;
        }
        if a is None or b is None {
            continue;
        }
        mine_is_a = s.root_a == me;
        views.append(
            SuggestionView(
                id=jid(s),
                status=status,
                score=s.score,
                reasons=s.reasons,
                my_post=view_of(a if mine_is_a else b, today),
                other_post=view_of(b if mine_is_a else a, today),
                i_accepted=s.accepted_a if mine_is_a else s.accepted_b,
                unread=not (s.seen_a if mine_is_a else s.seen_b)
            )
        );
    }
    views.sort(key=lambda (v: SuggestionView) -> int { return -v.score; });
    return views;
}

"""Stop suggesting the caller's post: pending suggestions are withdrawn, no new ones are made."""
def stop_for(post_id: str) -> bool {
    post = own_post(post_id);
    if post is None {
        return False;
    }
    post.suggestions_stopped = True;
    withdraw_pending(post_id);
    return True;
}

def:protect list_my_suggestions -> list[SuggestionView] {
    if verified_profile() is None {
        return [];
    }
    return my_suggestions(clock_today());
}

def:protect stop_suggestions(post_id: str) -> bool {
    return verified_profile() is not None and stop_for(post_id);
}
