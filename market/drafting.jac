"""Draft posts from one message (U3, native-language U4): call the AI, then validate and
normalize its output.

One message in any language becomes up to MAX_DRAFTS drafts, each in the student's language with
an English preview copy. Nothing is stored here; publishing a confirmed draft is separate. Every
rule about what a valid post looks like lives here, not in the prompt: the AI can guess, but
only these checks decide.
"""

import from core.clock { today_iso as clock_today }
import from datetime { date }
import from jaclang.byllm.lib { OutputConversionError }
import from ai.draft { draft_posts, drafter_ready, PostDraft, PostKind, Category }
import from core.auth { verified_profile }
import from core.constants { ANN_ARBOR_AREAS }
import from core.profile { Profile, valid_date, valid_time, default_language_from }
import from market.constants { ARRANGEMENTS }
import from market.translation {
    digit_groups,
    language_code,
    profile_language,
    note_ai_failure
}

glob MAX_MESSAGE_CHARS: int = 1000,
     MAX_DRAFTS: int = 5;

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
        language: str = "en",
        title_en: str = "",
        description_en: str = "",
        constraints: list[str] = [],
        about_market: bool = True,
        item: str = "",
        condition: str = "";
}

"""`language` is the detected (or, for non-AI cards, the poster's profile) language; `draft`
is `drafts[0]`, kept for callers that handle a single draft."""
obj DraftResult {
    has ok: bool,
        error: str = "",
        notice: str = "",
        draft: DraftCard | None = None,
        drafts: list[DraftCard] = [],
        language: str = "",
        dropped: int = 0;
}

"""A successful result holding `cards` (at least one) in `language`."""
def drafted_result(
    cards: list[DraftCard], language: str, notice: str = ""
) -> DraftResult {
    return DraftResult(
        ok=True, notice=notice, draft=cards[0], drafts=cards, language=language
    );
}

"""Tag `card` with `language`; an English card's English copy is its own text."""
def in_language(card: DraftCard, language: str) -> DraftCard {
    card.language = language;
    if language == "en" {
        card.title_en = card.title;
        card.description_en = card.description;
    }
    return card;
}

"""A blank, non-AI draft holding the student's own words, for when AI drafting is unavailable."""
def manual_card(text: str, language: str = "en") -> DraftCard {
    card = DraftCard(
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
    return in_language(card, language);
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
        item=d.item.strip().lower(),
        condition=d.condition.strip().lower()
            if d.condition.strip().lower() in ["new", "like new", "good", "fair"]
            else ""
    );
}

"""The digit groups of a price: 900.0 -> {"900"}, 12.5 -> {"12", "5"}."""
def price_groups(price: float) -> set[str] {
    return digit_groups(f"{price:.0f}" if price == int(price) else f"{price}");
}

"""Whether the message digit `groups` support the YYYY-MM-DD `value`: its day number appears,
and so does its month, as a number ("8월 20일", "8/20", "8月20日") or an English month word
("Aug 20", which `digit_groups` maps to its number). The year is not required."""
def date_supported(value: str, groups: set[str]) -> bool {
    (month, day) = (int(value[5:7]), int(value[8:10]));
    return str(day) in groups and str(month) in groups;
}

"""Whether `message` supports the HH:MM `value`: its hour appears on the 24- or 12-hour clock
("15:00" from "3pm" or "오후 3시"), and so do non-zero minutes."""
def time_supported(value: str, groups: set[str]) -> bool {
    (hour, minute) = (int(value[:2]), int(value[3:]));
    twelve = hour % 12 or 12;
    if str(hour) not in groups and str(twelve) not in groups {
        return False;
    }
    return minute == 0 or str(minute) in groups;
}

"""Key-fact check (R24): a price, date or time on `card` whose numbers do not appear in the
original `message` is marked guessed, so the poster checks it before publishing."""
def check_key_facts(card: DraftCard, message: str) -> DraftCard {
    groups = digit_groups(message);
    unsupported: list[str] = [];
    if card.price is not None and not price_groups(card.price).issubset(groups) {
        unsupported.append("price");
    }
    for field in ["available_from", "available_until"] {
        value = getattr(card, field);
        if value and not date_supported(value, groups) {
            unsupported.append(field);
        }
    }
    for field in ["time_from", "time_to"] {
        value = getattr(card, field);
        if value and not time_supported(value, groups) {
            unsupported.append(field);
        }
    }
    for field in unsupported {
        if field not in card.guessed {
            card.guessed.append(field);
        }
    }
    return card;
}

"""One reviewed card from an AI draft in `language`: normalized, English copy attached (the
card's own text when the language is English), key facts checked against `message`."""
def card_from(d: PostDraft, language: str, message: str) -> DraftCard {
    card = normalize(d);
    card.title_en = d.title_en.strip()[:80];
    card.description_en = d.description_en.strip()[:500];
    return check_key_facts(in_language(card, language), message);
}

"""Draft posts from `message` as of `today` (YYYY-MM-DD) for `profile` (the poster; None in
tests without one). A detected pilot language becomes the poster's default language unless
they chose one; non-AI cards use the profile's language."""
def make_draft(
    message: str, today: str, profile: Profile | None = None
) -> DraftResult {
    text = message.strip();
    if text == "" {
        return DraftResult(ok=False, error="Type what you're offering or looking for.");
    }
    if len(text) > MAX_MESSAGE_CHARS {
        return DraftResult(
            ok=False, error=f"Keep it under {MAX_MESSAGE_CHARS} characters."
        );
    }
    unreadable = DraftResult(
        ok=False,
        error="Couldn't read that. Try adding what it is, a price or budget, and dates."
    );
    fallback = profile_language(profile);
    manual = drafted_result(
        [manual_card(text, fallback)],
        fallback,
        notice="AI drafting isn't available right now, so fill in the details yourself."
    );
    if not drafter_ready() {
        return manual;
    }
    try {
        raw = draft_posts(text, today);
    } except OutputConversionError {
        return unreadable;
    } except Exception as err {
        note_ai_failure("draft_posts", err);
        return manual;
    }
    if not raw.drafts {
        return unreadable;
    }
    language = language_code(raw.language, fallback);
    cards = [card_from(d, language, text) for d in raw.drafts[:MAX_DRAFTS]];
    dropped = max(0, len(raw.drafts) - MAX_DRAFTS);
    if profile is not None {
        default_language_from(language, profile);
    }
    result = drafted_result(cards, language);
    result.dropped = dropped;
    return result;
}

"""Draft a post from the caller's message. Verified UMich students only (R15)."""
def:protect draft_from_message(message: str) -> DraftResult {
    profile = verified_profile();
    if profile is None {
        return DraftResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    return make_draft(message, clock_today(), profile);
}

"""A non-AI ride-request draft from the DTW prompt (U9): DTW to Ann Arbor on `day`, from `time`
for two hours. Invalid values are dropped; the student reviews everything before publishing.
The text is app-written English, so the card is English whatever the poster's language."""
def ride_card(day: str, time: str) -> DraftCard {
    day = day if day and valid_date(day) else "";
    start = time if time and valid_time(time) else "";
    end = "";
    if start {
        (h, m) = (int(start.split(":")[0]), start.split(":")[1]);
        end = f"{min(h + 2, 23):02d}:{m}";
    }
    card = DraftCard(
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
    return in_language(card, "en");
}

"""The pre-filled ride draft for compose's `?prefill=ride&date=&time=` link. Nothing is stored.
The card is English (app-written text); the result's `language` is the poster's, for labels."""
def:protect ride_prefill(day: str, time: str) -> DraftResult {
    profile = verified_profile();
    if profile is None {
        return DraftResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    language = profile_language(profile);
    return drafted_result([ride_card(day, time)], language);
}

test "the ride prefill is a non-AI DTW request on the arrival day, two hours from the time" {
    card = ride_card("2026-08-20", "15:00");
    assert card.kind == "request" and card.category == "service";
    assert card.route_from == "DTW" and card.route_to == "Ann Arbor";
    assert card.available_from == card.available_until == "2026-08-20";
    assert card.time_from == "15:00" and card.time_to == "17:00";
    assert not card.ai_generated and card.missing == [];
    assert card.language == "en" and card.title_en == card.title;
}

test "bad prefill values are dropped, and a missing date is flagged" {
    card = ride_card("tomorrow", "3pm");
    assert card.available_from == "" and card.time_from == "" and card.time_to == "";
    assert card.missing == ["available_from"];
    assert ride_card("2026-08-20", "23:30").time_to == "23:30";
}
