"""Draft a post from one message (U3): call the AI, then validate and normalize its output.

Nothing is stored here; U4 publishes a confirmed draft. Every rule about what a valid post
looks like lives here, not in the prompt: the AI can guess, but only these checks decide.
"""

import from core.clock { today_iso as clock_today }
import from datetime { date }
import from jaclang.byllm.lib { ByLLMError, OutputConversionError }
import from ai.draft { draft_post, PostDraft, PostKind, Category }
import from core.auth { verified_profile }
import from core.constants { ANN_ARBOR_AREAS }
import from core.profile { valid_date, valid_time }
import from market.constants { ARRANGEMENTS }

glob MAX_MESSAGE_CHARS: int = 1000;

"""A draft ready for the poster to review. Plain fields so the client can edit every one."""
obj DraftCard {
    has kind: str,
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
        guessed: list[str],
        missing: list[str],
        suggested_price: float | None,
        price_reason: str,
        ai_generated: bool = True,
        constraints: list[str] = [],
        about_market: bool = True,
        item: str = "";
}

obj DraftResult {
    has ok: bool,
        error: str = "",
        notice: str = "",
        draft: DraftCard | None = None;
}

"""A blank, non-AI draft holding the student's own words, for when AI drafting is unavailable."""
def manual_card(text: str) -> DraftCard {
    return DraftCard(
        kind="offer",
        category="furniture",
        title=text[:80],
        description=text[:500],
        price=None,
        free=False,
        available_from="",
        available_until="",
        time_from="",
        time_to="",
        area="",
        route_from="",
        route_to="",
        arrangement="",
        guessed=[],
        missing=["price"],
        suggested_price=None,
        price_reason="",
        ai_generated=False
    );
}

"""Map free-text area to one of ANN_ARBOR_AREAS; unknown text becomes "Other"."""
def match_area(text: str) -> str {
    wanted = text.strip().lower();
    if wanted == "" {
        return "";
    }
    for name in ANN_ARBOR_AREAS {
        if name.lower() in wanted or wanted in name.lower() {
            return name;
        }
    }
    return "Other";
}

"""Validate and normalize an AI draft. Anything invalid is cleared and marked guessed."""
def normalize(d: PostDraft) -> DraftCard {
    guessed = [g for g in d.guessed];
    def mark(field: str) {
        if field not in guessed {
            guessed.append(field);
        }
    }
    price = d.price;
    if price is not None and price < 0 {
        price = None;
        mark("price");
    }
    dates: dict[str, str] = {
        "available_from": d.available_from,
        "available_until": d.available_until
    };
    for (field, value) in dates.items() {
        if not valid_date(value) {
            dates[field] = "";
            mark(field);
        }
    }
    if dates["available_from"]
        and dates["available_until"]
        and dates["available_from"] > dates["available_until"] {
        (dates["available_from"], dates["available_until"]) = (
            dates["available_until"],
            dates["available_from"]
        );
        mark("available_from");
    }
    times: dict[str, str] = {"time_from": d.time_from, "time_to": d.time_to};
    for (field, value) in times.items() {
        if not valid_time(value) {
            times[field] = "";
            mark(field);
        }
    }
    area = match_area(d.area);
    if area == "Other" or (area and area.lower() != d.area.strip().lower()) {
        mark("area");
    }
    housing = d.category == Category.HOUSING;
    arrangement = d.arrangement.strip().lower();
    if not housing or arrangement not in ARRANGEMENTS {
        arrangement = "";
    }
    missing: list[str] = [];
    if housing and arrangement == "" {
        missing.append("arrangement");
    }
    if d.kind == PostKind.OFFER
        and price is None
        and not d.free
        and d.category != Category.SERVICE {
        missing.append("price");
    }
    if d.category == Category.SERVICE and dates["available_from"] == "" {
        missing.append("available_from");
    }
    suggested = d.suggested_price;
    if suggested is not None
        and (suggested < 0 or d.kind != PostKind.OFFER or housing) {
        suggested = None;
    }
    return DraftCard(
        kind=d.kind.name.lower(),
        category=d.category.name.lower(),
        title=d.title.strip()[:80],
        description=d.description.strip()[:500],
        price=None if d.free else price,
        free=d.free,
        available_from=dates["available_from"],
        available_until=dates["available_until"],
        time_from=times["time_from"],
        time_to=times["time_to"],
        area=area,
        route_from=d.route_from.strip() if d.category == Category.SERVICE else "",
        route_to=d.route_to.strip() if d.category == Category.SERVICE else "",
        arrangement=arrangement,
        guessed=guessed,
        missing=missing,
        suggested_price=suggested,
        price_reason=d.price_reason.strip() if suggested is not None else "",
        constraints=[
            c.strip()[:60]
            for c in d.constraints
            if c.strip()
        ][:5],
        about_market=d.about_market,
        item=d.item.strip().lower()
    );
}

"""Draft a post from `message` as of `today` (YYYY-MM-DD)."""
def make_draft(message: str, today: str) -> DraftResult {
    text = message.strip();
    if text == "" {
        return DraftResult(ok=False, error="Type what you're offering or looking for.");
    }
    if len(text) > MAX_MESSAGE_CHARS {
        return DraftResult(
            ok=False, error=f"Keep it under {MAX_MESSAGE_CHARS} characters."
        );
    }
    try {
        raw = draft_post(text, today);
    } except OutputConversionError {
        return DraftResult(
            ok=False,
            error="Couldn't read that. Try adding what it is, a price or budget, and dates."
        );
    } except ByLLMError {
        return DraftResult(
            ok=True,
            notice="AI drafting isn't available right now, so fill in the details yourself.",
            draft=manual_card(text)
        );
    }
    return DraftResult(ok=True, draft=normalize(raw));
}

"""Draft a post from the caller's message. Verified UMich students only (R15)."""
def:protect draft_from_message(message: str) -> DraftResult {
    if verified_profile() is None {
        return DraftResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    return make_draft(message, clock_today());
}

"""A non-AI ride-request draft from the DTW prompt (U9): DTW to Ann Arbor on `day`, from `time`
for two hours. Invalid values are dropped; the student reviews everything before publishing."""
def ride_card(day: str, time: str) -> DraftCard {
    day = day if day and valid_date(day) else "";
    start = time if time and valid_time(time) else "";
    end = "";
    if start {
        (h, m) = (int(start.split(":")[0]), start.split(":")[1]);
        end = f"{min(h + 2, 23):02d}:{m}";
    }
    return DraftCard(
        kind="request",
        category="service",
        title="Ride from DTW to Ann Arbor",
        description="Arriving at DTW and looking for students to share a ride to Ann Arbor.",
        price=None,
        free=False,
        available_from=day,
        available_until=day,
        time_from=start,
        time_to=end,
        area="",
        route_from="DTW",
        route_to="Ann Arbor",
        arrangement="",
        guessed=[],
        missing=[] if day else ["available_from"],
        suggested_price=None,
        price_reason="",
        ai_generated=False
    );
}

"""The pre-filled ride draft for compose's `?prefill=ride&date=&time=` link. Nothing is stored."""
def:protect ride_prefill(day: str, time: str) -> DraftResult {
    if verified_profile() is None {
        return DraftResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    return DraftResult(ok=True, draft=ride_card(day, time));
}

test "the ride prefill is a non-AI DTW request on the arrival day, two hours from the time" {
    card = ride_card("2026-08-20", "15:00");
    assert card.kind == "request" and card.category == "service";
    assert card.route_from == "DTW" and card.route_to == "Ann Arbor";
    assert card.available_from == card.available_until == "2026-08-20";
    assert card.time_from == "15:00" and card.time_to == "17:00";
    assert not card.ai_generated and card.missing == [];
}

test "bad prefill values are dropped, and a missing date is flagged" {
    card = ride_card("tomorrow", "3pm");
    assert card.available_from == "" and card.time_from == "" and card.time_to == "";
    assert card.missing == ["available_from"];
    assert ride_card("2026-08-20", "23:30").time_to == "23:30";
}
