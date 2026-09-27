"""What a post says for sure, what the AI only guessed, and what's still unknown (plan
2026-09-27-003 M-R1, M-R2). Rules code: no AI here.

A post's facts are split into confirmed ones (the student wrote or confirmed them) and guesses
(fields listed in `post.inferred`). Missing useful details become unknowns, and the owner gets up
to MAX_QUESTIONS focused questions about them, each answered with one tap or one short input.
"""

import from datetime { date, timedelta }
import from core.constants { ANN_ARBOR_AREAS }
import from market.constants { CONDITIONS, PICKUPS }
import from market.graph { Post }
import from market.matching { money }

glob MAX_QUESTIONS: int = 3,
     GOODS: list[str] = ["furniture", "essentials", "vehicle"],
     AREA_CHOICES: list[str] = [
         "Central Campus",
         "North Campus",
         "South Campus",
         "Kerrytown",
         "Downtown"
     ];

obj Choice {
    has label: str,
        value: str;
}

"""One focused question for the owner. `input` is "price" when the answer is a number, else ""
(pick a choice). `guess` holds the AI's value when the question asks to confirm it."""
obj DetailQuestion {
    has field: str,
        question: str,
        choices: list[Choice] = [],
        input: str = "",
        guess: str = "";
}

def is_goods(p: Post) -> bool {
    return p.category in GOODS;
}

def short_date(day: str) -> str {
    try {
        d = date.fromisoformat(day);
    } except ValueError {
        return day;
    }
    return d.strftime("%b ") + str(d.day);
}

"""Each fact of `p` as (field, text): price, dates, time, area, condition, pickup."""
def fact_items(p: Post) -> list[tuple[str, str]] {
    out: list[tuple[str, str]] = [];
    if p.free {
        out.append(("price", "free"));
    } elif p.price is not None {
        out.append(
            ("price", ("budget " if p.kind == "request" else "") + money(p.price))
        );
    }
    if p.available_from
        and p.available_until
        and p.available_from != p.available_until {
        out.append(
            (
                "available_until",
                short_date(p.available_from) + "–" + short_date(p.available_until)
            )
        );
    } elif p.available_until {
        out.append(
            (
                "available_until",
                ("needed by " if p.kind == "request" else "until ")
                    + short_date(p.available_until)
            )
        );
    } elif p.available_from {
        out.append(("available_from", "from " + short_date(p.available_from)));
    }
    if p.time_from {
        out.append(("time_from", p.time_from + (f"–{p.time_to}" if p.time_to else "")));
    }
    if p.area {
        out.append(("area", p.area));
    }
    if p.condition {
        out.append(("condition", p.condition));
    }
    if p.pickup {
        out.append(("pickup", p.pickup));
    }
    return out;
}

"""(confirmed facts, AI guesses) as display lines, e.g. ("$30 · like new", "until Sep 30")."""
def facts_split(p: Post) -> tuple[str, str] {
    sure: list[str] = [];
    guessed: list[str] = [];
    for (field, text) in fact_items(p) {
        if field in p.inferred
            or (field == "available_until" and "available_from" in p.inferred) {
            guessed.append(text);
        } else {
            sure.append(text);
        }
    }
    return (" · ".join(sure), " · ".join(guessed));
}

"""Useful details `p` doesn't state yet, as short phrases ("condition not stated")."""
def unknowns(p: Post) -> list[str] {
    out: list[str] = [];
    if p.price is None and not p.free {
        out.append("budget not stated" if p.kind == "request" else "price not stated");
    }
    if is_goods(p) and p.kind == "offer" and not p.condition {
        out.append("condition not stated");
    }
    if not p.area {
        out.append("area not stated");
    }
    if not p.available_until and not p.available_from {
        out.append(
            "timing not stated" if p.kind == "request" else "availability not stated"
        );
    }
    if is_goods(p) and p.kind == "offer" and not p.pickup {
        out.append("pickup or delivery not stated");
    }
    return out;
}

def choices(pairs: list[str]) -> list[Choice] {
    return [Choice(label=x[0].upper() + x[1:], value=x) for x in pairs];
}

glob REASON_FIELDS: dict[str, list[str]] = {
         "within_budget": ["price"],
         "same_area": ["area"],
         "dates_overlap": ["available_from", "available_until"],
         "same_day": ["available_from", "available_until"],
         "times_overlap": ["time_from"],
         "times_apart": ["time_from"]
     };

"""Match reasons with any that rest on an AI guess (on either post) labelled as such (M-R1), so a
guess is never presented as a confirmed fit."""
def label_guessed(
    reasons: list[str], codes: list[dict[str, any]], a: Post, b: Post
) -> list[str] {
    guessed = set(a.inferred + b.inferred);
    out: list[str] = [];
    for (i, r) in enumerate(reasons) {
        code = str(codes[i].get("code", "")) if i < len(codes) else "";
        fields = REASON_FIELDS.get(code, []);
        out.append(r + " (based on an AI guess)" if guessed & set(fields) else r);
    }
    return out;
}

"""Up to MAX_QUESTIONS focused questions for the owner: missing details first by importance, then
AI guesses to confirm. Questions already answered or skipped don't come back."""
def detail_questions(p: Post) -> list[DetailQuestion] {
    out: list[DetailQuestion] = [];
    def ask(q: DetailQuestion) {
        if q.field not in p.answered and len(out) < MAX_QUESTIONS {
            out.append(q);
        }
    }
    offer = p.kind == "offer";
    if p.price is None and not p.free and p.category != "service" {
        ask(
            DetailQuestion(
                field="price",
                question="What's your price?" if offer else "What's your budget?",
                input="price",
                choices=[Choice(label="Free", value="free")] if offer else []
            )
        );
    } elif "price" in p.inferred and p.price is not None {
        read = money(p.price);
        ask(
            DetailQuestion(
                field="price",
                question=f"I read the {'price' if offer else 'budget'} as {read}. Is that right?",
                input="price",
                guess=read,
                choices=[Choice(label="Yes, that's right", value="confirm")]
            )
        );
    }
    if is_goods(p) and offer and not p.condition {
        ask(
            DetailQuestion(
                field="condition",
                question="What condition is it in?",
                choices=choices(CONDITIONS)
            )
        );
    }
    if not p.area or "area" in p.inferred {
        guess = p.area if "area" in p.inferred else "";
        ask(
            DetailQuestion(
                field="area",
                question=f"I guessed {guess} — is that the area?"
                    if guess
                    else ("Where is pickup?" if offer else "Which area works for you?"),
                guess=guess,
                choices=(
                    [Choice(label="Yes, that's right", value="confirm")]
                        if guess
                        else []
                )
                    + [
                        Choice(label=a, value=a)
                        for a in AREA_CHOICES
                        if a != guess
                    ]
            )
        );
    }
    timing_guessed = "available_until" in p.inferred or "available_from" in p.inferred;
    if not (p.available_until or p.available_from) or timing_guessed {
        ask(
            DetailQuestion(
                field="timing",
                question=(
                    f"I guessed {facts_split(p)[1] or 'the dates'} — is that right?"
                        if timing_guessed
                        else (
                            "When is it available until?"
                                if offer
                                else "When do you need it by?"
                        )
                ),
                guess=facts_split(p)[1] if timing_guessed else "",
                choices=(
                    [Choice(label="Yes, that's right", value="confirm")]
                        if timing_guessed
                        else []
                )
                    + [
                        Choice(label="This week", value="week"),
                        Choice(label="This month", value="month"),
                        Choice(label="No rush", value="open")
                    ]
            )
        );
    }
    if is_goods(p) and offer and not p.pickup {
        ask(
            DetailQuestion(
                field="pickup", question="Pickup or delivery?", choices=choices(PICKUPS)
            )
        );
    }
    return out;
}

"""Apply one answer to `p` (the caller's own post). Returns "" or an error. The detail becomes
confirmed: it leaves `inferred` and the question won't come back."""
def apply_detail(p: Post, field: str, value: str, today: str) -> str {
    v = value.strip();
    if v == "skip" {
        v = "skip";
    } elif field == "price" {
        if v == "free" {
            p.free = True;
            p.price = None;
        } elif v != "confirm" {
            try {
                amount = float(v.replace("$", "").replace(",", ""));
            } except ValueError {
                return "Enter a number, like 30.";
            }
            if amount < 0 or amount > 100000 {
                return "Enter a price between 0 and 100000.";
            }
            p.price = amount;
            p.free = False;
        }
    } elif field == "condition" {
        if v not in CONDITIONS {
            return "Pick one of the choices.";
        }
        p.condition = v;
    } elif field == "area" {
        if v != "confirm" and v not in ANN_ARBOR_AREAS {
            return "Pick one of the choices.";
        }
        if v != "confirm" {
            p.area = v;
        }
    } elif field == "timing" {
        if v == "week" or v == "month" {
            days = 7 if v == "week" else 30;
            p.available_until = (
                date.fromisoformat(today) + timedelta(days=days)
            ).isoformat();
            if p.available_from and p.available_from > p.available_until {
                p.available_from = "";
            }
        } elif v == "open" {
            p.available_until = "";
            p.available_from = "";
        } elif v != "confirm" {
            return "Pick one of the choices.";
        }
    } elif field == "pickup" {
        if v not in PICKUPS {
            return "Pick one of the choices.";
        }
        p.pickup = v;
    } else {
        return "That question isn't available.";
    }
    confirmed = ["available_until", "available_from", "time_from"]
        if field == "timing"
        else [field];
    p.inferred = [
        f
        for f in p.inferred
        if f not in confirmed
    ];
    if field not in p.answered {
        p.answered = p.answered + [field];
    }
    return "";
}

test "facts split into confirmed ones and AI guesses" {
    p = Post(
        owner_root="x",
        kind="offer",
        category="furniture",
        title="Desk",
        price=30.0,
        area="Kerrytown",
        available_until="2026-09-30",
        inferred=["available_until"]
    );
    assert facts_split(p) == ("$30 · Kerrytown", "until Sep 30");
    assert unknowns(p) == ["condition not stated", "pickup or delivery not stated"];
}

test "the owner gets at most three questions, most useful first" {
    p = Post(owner_root="x", kind="offer", category="furniture", title="Desk");
    qs = detail_questions(p);
    assert [q.field for q in qs] == ["price", "condition", "area"];
    p.answered = ["price", "condition"];
    assert [q.field for q in detail_questions(p)] == ["area", "timing", "pickup"];
    full = Post(
        owner_root="x",
        kind="offer",
        category="furniture",
        title="Desk",
        price=30.0,
        area="Kerrytown",
        condition="good",
        pickup="pickup only",
        available_until="2026-10-01"
    );
    assert detail_questions(full) == [];
}

test "answers confirm details and bad answers are refused" {
    p = Post(
        owner_root="x",
        kind="offer",
        category="furniture",
        title="Desk",
        area="Kerrytown",
        inferred=["area"]
    );
    assert apply_detail(p, "area", "confirm", "2026-09-27") == "";
    assert p.inferred == [] and "area" in p.answered;
    assert apply_detail(p, "condition", "broken", "2026-09-27") != "";
    assert apply_detail(p, "price", "abc", "2026-09-27") != "";
    assert apply_detail(p, "price", "$45", "2026-09-27") == "" and p.price == 45.0;
    assert apply_detail(p, "timing", "week", "2026-09-27") == ""
        and p.available_until == "2026-10-04";
}

test "a reason that rests on a guessed area is labelled" {
    a = Post(
        owner_root="x", kind="offer", category="vehicle", title="Bike", area="Kerrytown"
    );
    b = Post(
        owner_root="y",
        kind="request",
        category="vehicle",
        title="Bike",
        area="Kerrytown",
        inferred=["area"]
    );
    out = label_guessed(
        ["$80 is within the $100 budget", "Both in Kerrytown"],
        [{"code": "within_budget"}, {"code": "same_area"}],
        a,
        b
    );
    assert out
        == [
            "$80 is within the $100 budget",
            "Both in Kerrytown (based on an AI guess)"
        ];
}
