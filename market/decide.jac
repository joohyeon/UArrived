"""Help me decide (U10, R14, F3, AE6): compare 2-3 posts.

Deterministic first: the facts side by side, what each post is missing, and known risk patterns.
Then optional AI phrasing (ai/decide.jac), labeled AI-generated and filtered so it never calls a
post safe or legitimate. If the AI fails, the facts and flags still show.

Native language (U6): missing info and flags are rule codes rendered through the phrase tables in
market/constants.jac for the reader; the advisor still reads and writes English, its notes are
filtered in English first and only then translated for a non-English reader.
"""

import from core.clock { today_iso as clock_today }
import re;
import from datetime { date }
import from jaclang.byllm.lib { ByLLMError }
import from ai.decide { advise, DecideNotes }
import from core.auth { verified_profile }
import from market.constants { MISSING_INFO_PHRASES, RISK_FLAG_PHRASES, phrase }
import from market.graph { Post, post_status, all_posts, visible_to }
import from market.translation { translate_text }
import from market.lifecycle { PostView, view_of, reader_of }

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

"""One compared post. `missing` and `flags` are in the reader's language; `missing_codes` and
`flag_codes` are the rule codes behind them (MISSING_INFO_PHRASES, RISK_FLAG_PHRASES)."""
obj Compared {
    has post: PostView,
        missing: list[str],
        flags: list[str],
        missing_codes: list[str] = [],
        flag_codes: list[str] = [];
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

"""Codes (MISSING_INFO_PHRASES) for what a student would want to know before meeting, that this
post doesn't say."""
def missing_codes(p: Post) -> list[str] {
    out: list[str] = [];
    if p.kind == "offer"
        and p.price is None
        and not p.free
        and p.category != "service" {
        out.append("price");
    }
    if not (p.available_from or p.available_until) {
        out.append("dates" if p.category != "housing" else "lease_dates");
    }
    if not p.area and p.category != "service" {
        out.append("area");
    }
    if p.category == "housing" and not p.arrangement {
        out.append("arrangement");
    }
    if p.category == "service" and p.route_from and not p.time_from {
        out.append("time");
    }
    return out;
}

"""What this post doesn't say, in `lang` (English by default)."""
def missing_info(p: Post, lang: str = "en") -> list[str] {
    return [phrase(MISSING_INFO_PHRASES, c, lang) for c in missing_codes(p)];
}

"""Whether `phrase` appears in `text` as whole words ("wire" matches "wire it", not "wireless")."""
def has_word(text: str, phrase: str) -> bool {
    return re.search(r"\b" + re.escape(phrase) + r"\b", text) is not None;
}

"""Known risk patterns, by rule. A flag is a reason to ask, not a verdict. The poster's words
and the post's stored English copy (U5) are both scanned, so a Korean or Chinese post whose
English translation mentions a wire transfer is flagged too."""
def risk_codes(p: Post) -> list[str] {
    english = p.texts.get("en", {});
    text = " ".join(
        [
            p.title,
            p.description,
            english.get("title", ""),
            english.get("description", "")
        ]
    ).lower();
    out: list[str] = [];
    if any([has_word(text, w) for w in PAYMENT_WORDS]) {
        out.append("hard_to_reverse_payment");
    }
    if any([has_word(text, w) for w in PRESSURE_WORDS]) {
        out.append("deposit_pressure");
    }
    if p.category == "housing"
        and p.kind == "offer"
        and p.price is not None
        and p.price < LOW_RENT {
        out.append("low_rent");
    }
    return out;
}

"""Known risk patterns for `p`, in `lang` (English by default)."""
def risk_flags(p: Post, lang: str = "en") -> list[str] {
    return [phrase(RISK_FLAG_PHRASES, c, lang) for c in risk_codes(p)];
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

"""Already-filtered English AI notes for a `reader`: translated when the reader isn't English,
each note falling back to its English text if its translation fails."""
def notes_for(notes: list[str], reader: str) -> list[str] {
    if not reader or reader == "en" {
        return notes;
    }
    return [translate_text(n, "en", reader).text for n in notes];
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

"""Compare the posts with these ids, as of `today`, shown in the `reader` language. Only posts
the caller can see count. The advisor always gets the English copy and English flags (the
banned-claim filter is English); the reader gets missing info and flags from the phrase tables
and the filtered notes translated."""
def compare(post_ids: list[str], today: str, reader: str = "") -> DecideResult {
    wanted = list(dict.fromkeys(post_ids));
    if len(wanted) < MIN_COMPARE {
        return DecideResult(ok=False, error="Pick at least two posts to compare.");
    }
    if len(wanted) > MAX_COMPARE {
        return DecideResult(ok=False, error="Compare up to three posts at a time.");
    }
    posts: dict[str, Post] = {jid(p): p for p in visible_to(all_posts(), jid(root))};
    items: list[Compared] = [];
    for_advisor: list[Compared] = [];
    for pid in wanted {
        p = posts.get(pid);
        if p is None or post_status(p, today) != "live" {
            return DecideResult(
                ok=False, error="One of those posts isn't available any more."
            );
        }
        (missing, flags) = (missing_codes(p), risk_codes(p));
        items.append(
            Compared(
                post=view_of(p, today, reader),
                missing=missing_info(p, reader),
                flags=risk_flags(p, reader),
                missing_codes=missing,
                flag_codes=flags
            )
        );
        for_advisor.append(
            Compared(
                post=view_of(p, today, "en", own_original=False),
                missing=missing_info(p),
                flags=risk_flags(p)
            )
        );
    }
    try {
        notes = advise(summary_of(for_advisor));
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
        questions=notes_for(clean_notes(notes.questions)[:5], reader),
        risk_notes=notes_for(clean_notes(notes.risk_notes)[:3], reader),
        ai_generated=True
    );
}

def:protect help_me_decide(post_ids: list[str]) -> DecideResult {
    profile = verified_profile();
    if profile is None {
        return DecideResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    return compare(post_ids, clock_today(), reader_of(profile));
}

test "risk words match whole words only" {
    wireless = Post(
        owner_root="x",
        kind="offer",
        category="essentials",
        title="Wireless keyboard",
        price=15.0,
        description="Works great"
    );
    assert risk_flags(wireless) == [];
    wire = Post(
        owner_root="x",
        kind="offer",
        category="essentials",
        title="Keyboard",
        price=15.0,
        description="please wire the money"
    );
    assert len(risk_flags(wire)) == 1;
}
