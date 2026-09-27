"""Help me decide (U10, R14, F3, AE6): compare 2-3 posts.

Deterministic first: the facts side by side, what each post is missing, and known risk patterns.
Then optional AI phrasing (ai/decide.jac), labeled AI-generated and filtered so it never calls a
post safe or legitimate. If the AI fails, the facts and flags still show.
"""

import re;
import from datetime { date }
import from jaclang.byllm.lib { ByLLMError }
import from ai.decide { advise, DecideNotes }
import from core.auth { verified_profile }
import from market.graph { Post, post_status, all_posts }
import from market.lifecycle { PostView, view_of }

glob MIN_COMPARE: int = 2,
     MAX_COMPARE: int = 3,
     LOW_RENT: float = 300.0,
     PAYMENT_WORDS: list[str] = [
         "wire",
         "western union",
         "gift card",
         "zelle",
         "venmo",
         "cashapp",
         "cash app",
         "crypto",
         "bitcoin"
     ],
     PRESSURE_WORDS: list[str] = [
         "deposit",
         "hold it",
         "hold the room",
         "before viewing",
         "without viewing",
         "urgent",
         "today only"
     ],
     BANNED_CLAIMS: list[str] = [
         "safe",
         "legit",
         "legitimate",
         "verified",
         "trustworthy",
         "guaranteed",
         "scam-free",
         "no risk"
     ];

obj Compared {
    has post: PostView,
        missing: list[str],
        flags: list[str];
}

obj DecideResult {
    has ok: bool,
        error: str = "",
        posts: list[Compared] = [],
        questions: list[str] = [],
        risk_notes: list[str] = [],
        ai_generated: bool = False,
        ai_note: str = "";
}

"""What a student would want to know before meeting, that this post doesn't say."""
def missing_info(p: Post) -> list[str] {
    out: list[str] = [];
    if p.kind == "offer"
        and p.price is None
        and not p.free
        and p.category != "service" {
        out.append("price");
    }
    if not (p.available_from or p.available_until) {
        out.append("dates" if p.category != "housing" else "lease dates");
    }
    if not p.area and p.category != "service" {
        out.append("area");
    }
    if p.category == "housing" and not p.arrangement {
        out.append(
            "arrangement (sublet, roommate opening, lease assignment or new lease)"
        );
    }
    if p.category == "service" and p.route_from and not p.time_from {
        out.append("time");
    }
    return out;
}

"""Known risk patterns, by rule. A flag is a reason to ask, not a verdict."""
def risk_flags(p: Post) -> list[str] {
    text = (p.title + " " + p.description).lower();
    out: list[str] = [];
    if any([w in text for w in PAYMENT_WORDS]) {
        out.append(
            "Mentions a payment method that is hard to reverse (wire, gift card, app transfer)"
        );
    }
    if any([w in text for w in PRESSURE_WORDS]) {
        out.append("Asks for a deposit or quick decision, possibly before viewing");
    }
    if p.category == "housing"
        and p.kind == "offer"
        and p.price is not None
        and p.price < LOW_RENT {
        out.append("Rent is far below usual Ann Arbor prices");
    }
    return out;
}

"""Drop any AI sentence that makes a safety or legitimacy claim (R14)."""
def clean_notes(lines: list[str]) -> list[str] {
    out: list[str] = [];
    for line in lines {
        text = line.strip();
        low = text.lower();
        if text
            and not any(
                [re.search(r"\b" + re.escape(w) + r"\b", low) for w in BANNED_CLAIMS]
            ) {
            out.append(text);
        }
    }
    return out;
}

def summary_of(items: list[Compared]) -> str {
    parts: list[str] = [];
    for (i, c) in enumerate(items) {
        p = c.post;
        parts.append(
            f"Post {i + 1}: {p.title} ({p.kind}, {p.category}); price {p.price}; free {p.free}; "
                + f"dates {p.available_from}..{p.available_until}; area {p.area}; arrangement {p.arrangement}; "
                + f"poster's words: {p.description!r}; missing: {', '.join(c.missing)
                    or 'nothing'}; "
                + f"flags: {'; '.join(c.flags) or 'none'}"
        );
    }
    return "\n".join(parts);
}

"""Compare the posts with these ids, as of `today`. Only posts the caller can see count."""
def compare(post_ids: list[str], today: str) -> DecideResult {
    wanted = list(dict.fromkeys(post_ids));
    if len(wanted) < MIN_COMPARE {
        return DecideResult(ok=False, error="Pick at least two posts to compare.");
    }
    if len(wanted) > MAX_COMPARE {
        return DecideResult(ok=False, error="Compare up to three posts at a time.");
    }
    posts: dict[str, Post] = {jid(p): p for p in all_posts()};
    items: list[Compared] = [];
    for pid in wanted {
        p = posts.get(pid);
        if p is None or post_status(p, today) != "live" {
            return DecideResult(
                ok=False, error="One of those posts isn't available any more."
            );
        }
        items.append(
            Compared(
                post=view_of(p, today), missing=missing_info(p), flags=risk_flags(p)
            )
        );
    }
    try {
        notes = advise(summary_of(items));
    } except ByLLMError {
        return DecideResult(
            ok=True,
            posts=items,
            ai_note="AI notes aren't available right now; the facts and flags above still apply."
        );
    }
    return DecideResult(
        ok=True,
        posts=items,
        questions=clean_notes(notes.questions)[:5],
        risk_notes=clean_notes(notes.risk_notes)[:3],
        ai_generated=True
    );
}

def:protect help_me_decide(post_ids: list[str]) -> DecideResult {
    if verified_profile() is None {
        return DecideResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    return compare(post_ids, date.today().isoformat());
}
