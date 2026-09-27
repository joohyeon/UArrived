"""The "For you" feed (U8, R13): live posts ranked by how well they fit the viewer's own live
requests and offers, using the same deterministic match score as suggestions. Secondary to the
matches inbox; posts that fit nothing fall back to newest first.
"""

import from datetime { date, datetime, timezone }
import from core.auth { verified_profile }
import from core.profile { my_profile }
import from market.graph { Post, post_status, all_posts }
import from market.lifecycle { PostView, view_of }
import from market.matching { match_pair }

"""Other students' live posts, best fit to `mine` first, then newest."""
def rank_feed(posts: list[Post], me: str, today: str) -> list[Post] {
    mine = [
        p
        for p in posts
        if p.owner_root == me and post_status(p, today) == "live"
    ];
    scored: list[tuple[int, str, Post]] = [];
    for p in posts {
        if p.owner_root == me or post_status(p, today) != "live" {
            continue;
        }
        best = 0;
        for m in mine {
            hit = match_pair(m, p, today);
            if hit is not None and hit.score > best {
                best = hit.score;
            }
        }
        scored.append((best, p.published_on, p));
    }
    scored.sort(
        key=lambda (t: tuple[int, str, Post]) -> tuple[int, str] { return (
            t[0],
            t[1]
        ); },
        reverse=True
    );
    return [t[2] for t in scored];
}

def:protect for_you_feed -> list[PostView] {
    if verified_profile() is None {
        return [];
    }
    today = date.today().isoformat();
    return [view_of(p, today) for p in rank_feed(all_posts(), jid(root), today)];
}

"""A tiny write the client calls before each poll. Writes invalidate the client's 60-second read
cache, so the reads that follow are fresh (chat and inbox polling)."""
def:protect heartbeat -> str {
    stamp = datetime.now(timezone.utc).isoformat(timespec="seconds");
    my_profile().last_seen = stamp;
    return stamp;
}

test "the feed puts the post that fits my request first, hides mine and dead posts" {
    mine = Post(
        owner_root="me",
        kind="request",
        category="furniture",
        title="Need a desk",
        price=50.0
    );
    fits = Post(
        owner_root="jae",
        kind="offer",
        category="furniture",
        title="Desk",
        price=25.0,
        published_on="2026-08-01"
    );
    newer = Post(
        owner_root="kai",
        kind="offer",
        category="essentials",
        title="Lamp",
        price=5.0,
        published_on="2026-08-05"
    );
    gone = Post(
        owner_root="kai",
        kind="offer",
        category="furniture",
        title="Old desk",
        price=10.0,
        done=True
    );
    ranked = rank_feed([mine, newer, fits, gone], "me", "2026-08-06");
    assert [p.title for p in ranked] == ["Desk", "Lamp"];
}

test "with no posts of my own the feed is newest first" {
    a = Post(
        owner_root="jae",
        kind="offer",
        category="furniture",
        title="Older",
        free=True,
        published_on="2026-08-01"
    );
    b = Post(
        owner_root="kai",
        kind="offer",
        category="furniture",
        title="Newer",
        free=True,
        published_on="2026-08-03"
    );
    assert [p.title for p in rank_feed([a, b], "me", "2026-08-04")]
        == ["Newer", "Older"];
}
