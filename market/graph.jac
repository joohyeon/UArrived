"""Marketplace graph: the shared records every marketplace unit reads and writes.

Where things live (plan, Key Technical Decisions; doc-review P1s):
- Posts attach to `root.shared`, owned by their poster and granted READ to everyone, so every
  student finds them with one traversal and only the poster's calls can change them.
- A post's effective status (live, done, expired) is computed on read, never stored on the
  records that depend on it, so expiry closes suggestions and chats without a job and without
  anyone writing to a node another student owns.
"""

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
        suggestions_stopped: bool = False;
}

"""live, done or expired, as of `today` (YYYY-MM-DD). A post is visible while today < expires_on."""
def post_status(post: Post, today: str) -> str {
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

"""Every post on the commons that the caller is allowed to see."""
def all_posts -> list[Post] {
    return [root.shared-->][?:Post];
}
