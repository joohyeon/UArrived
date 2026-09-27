"""Tests for the native-language tables in market/constants.jac (U1)."""

import re;
import from core.constants { PILOT_LANGUAGES, DEFAULT_LANGUAGE, LANGUAGE_NAMES }
import from market.constants {
    ARRANGEMENTS,
    LABELS,
    CATEGORY_NAMES,
    ARRANGEMENT_NAMES,
    REASON_PHRASES,
    RISK_FLAG_PHRASES,
    MISSING_INFO_PHRASES,
    labels_for,
    localized,
    phrase
}

def slots(template: str) -> list[str] {
    return sorted(re.findall(r"\{(\w+)\}", template));
}

test "the pilot languages are en, ko and zh, English by default, each with a name" {
    assert PILOT_LANGUAGES == ["en", "ko", "zh"] and DEFAULT_LANGUAGE == "en";
    assert sorted(LANGUAGE_NAMES.keys()) == sorted(PILOT_LANGUAGES);
    assert LANGUAGE_NAMES["ko"] == "한국어" and LANGUAGE_NAMES["zh"] == "中文";
}

test "every pilot language has every label key" {
    keys = sorted(LABELS["en"].keys());
    for lang in [
        "category",
        "price",
        "dates",
        "time",
        "area",
        "route",
        "arrangement"
    ] {
        assert lang in keys;
    }
    for lang in PILOT_LANGUAGES {
        assert lang in LABELS , lang;
        assert sorted(LABELS[lang].keys()) == keys , lang;
        assert all([LABELS[lang][k].strip() != "" for k in keys]) , lang;
    }
}

test "every phrase table has every code in every pilot language" {
    for table in [
        REASON_PHRASES,
        RISK_FLAG_PHRASES,
        MISSING_INFO_PHRASES,
        CATEGORY_NAMES,
        ARRANGEMENT_NAMES
    ] {
        for (code, texts) in table.items() {
            for lang in PILOT_LANGUAGES {
                assert lang in texts and texts[lang].strip() != "" , f"{code}/{lang}";
            }
        }
    }
    assert sorted(ARRANGEMENT_NAMES.keys()) == sorted(ARRANGEMENTS);
    assert all([ARRANGEMENT_NAMES[a]["en"] == a for a in ARRANGEMENTS]);
}

test "ko and zh reason templates use exactly the English slot names" {
    for table in [REASON_PHRASES, RISK_FLAG_PHRASES, MISSING_INFO_PHRASES] {
        for (code, texts) in table.items() {
            for lang in PILOT_LANGUAGES {
                assert slots(texts[lang]) == slots(texts["en"]) , f"{code}/{lang}";
            }
        }
    }
}

test "English reason templates reproduce today's match_pair strings" {
    en = lambda (code: str, values: dict[str, str]) -> str { return phrase(
        REASON_PHRASES, code, "en", values
    ); };
    assert en("same_route", {"route_from": "DTW", "route_to": "Ann Arbor"})
        == "Same route: DTW to Ann Arbor";
    assert en("same_day", {}) == "Same day";
    assert en("dates_overlap", {}) == "Dates overlap";
    assert en("times_overlap", {}) == "Times overlap";
    assert en("times_apart", {"minutes": "90"}) == "Times are 90 minutes apart";
    assert en("free", {}) == "Free";
    assert en("within_budget", {"price": "$25", "budget": "$50"})
        == "$25 is within the $50 budget";
    assert en("same_arrangement", {"arrangement": "sublet"}) == "Both want a sublet";
    assert en("same_area", {"area": "Central Campus"}) == "Both in Central Campus";
}

test "Korean and Chinese reasons keep the numbers from the slots" {
    ko = phrase(
        REASON_PHRASES, "within_budget", "ko", {"price": "$25", "budget": "$50"}
    );
    assert "$25" in ko and "$50" in ko and "{" not in ko;
    zh = phrase(REASON_PHRASES, "times_apart", "zh", {"minutes": "35"});
    assert "35" in zh and "{" not in zh;
}

test "English risk-flag and missing-info phrases reproduce today's decide strings" {
    assert phrase(RISK_FLAG_PHRASES, "hard_to_reverse_payment", "en")
        == "Mentions a payment method that is hard to reverse (wire, gift card, app transfer)";
    assert phrase(RISK_FLAG_PHRASES, "deposit_pressure", "en")
        == "Asks for a deposit or quick decision, possibly before viewing";
    assert phrase(RISK_FLAG_PHRASES, "low_rent", "en")
        == "Rent is far below usual Ann Arbor prices";
    assert [
        phrase(MISSING_INFO_PHRASES, c, "en")
        for c in ["price", "dates", "lease_dates", "area", "arrangement", "time"]
    ]
        == [
            "price",
            "dates",
            "lease dates",
            "area",
            "arrangement (sublet, roommate opening, lease assignment or new lease)",
            "time"
        ];
}

test "a language outside the pilot set gets English labels and phrases" {
    assert labels_for("fr") == LABELS["en"];
    assert labels_for("ko") == LABELS["ko"];
    assert phrase(REASON_PHRASES, "dates_overlap", "fr") == "Dates overlap";
    assert phrase(REASON_PHRASES, "no_such_code", "ko") == "";
    assert localized(CATEGORY_NAMES, "housing", "ko") == "주거";
    assert localized(CATEGORY_NAMES, "housing", "fr") == "Housing";
    assert localized(ARRANGEMENT_NAMES, "a tent", "ko") == "a tent";
}
