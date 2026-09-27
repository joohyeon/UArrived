"""Plain marketplace constants shared by server and client code (import-free; see
core/constants.jac for why)."""

glob ARRANGEMENTS: list[str] = [
         "roommate opening",
         "sublet",
         "lease assignment",
         "new lease"
     ];

"""Category-specific safety guidance shown while composing (R16). Plain advice only; never a
claim that a post or person is safe."""
glob SAFETY_TIPS: dict[str, str] = {
         "service": "Rides and moving help: share your trip or visit with a friend, agree on the route and cost before you go, and keep your phone charged.",
         "vehicle": "Vehicles: meet in daylight somewhere public, test drive with a friend, check that the title and registration match the seller's name, and never pay before you have the title.",
         "housing": "Housing: never send a deposit or rent before you have seen the room and read the lease. Check that the lease allows a sublet or transfer.",
         "furniture": "Pickups: meet in a public place or bring a friend, and pay only when you have the item.",
         "essentials": "Pickups: meet in a public place or bring a friend, and pay only when you have the item."
     };

# Native-language marketplace tables (R23, R26-R28). Keyed by language code for the pilot
# languages in core/constants.jac PILOT_LANGUAGES (en, ko, zh); a language outside the set reads
# English. Templates use {named} slots for values (numbers, money, places) so digits are never
# translated. Korean and Chinese wording needs a native-speaker review before the demo.

"""Draft-card field labels and translation controls, per language."""
glob LABELS: dict[str, dict[str, str]] = {
         "en": {
             "category": "Category",
             "price": "Price",
             "budget": "Budget",
             "dates": "Dates",
             "time": "Time",
             "area": "Area",
             "route": "Route",
             "arrangement": "Arrangement",
             "offer": "Offering",
             "request": "Looking for",
             "ai_translated": "AI-translated",
             "see_original": "See original",
             "hide_original": "Hide original",
             "translating": "Translating…",
             "guessed": "Guessed, please check"
         },
         "ko": {
             "category": "카테고리",
             "price": "가격",
             "budget": "예산",
             "dates": "날짜",
             "time": "시간",
             "area": "지역",
             "route": "경로",
             "arrangement": "계약 형태",
             "offer": "드려요",
             "request": "구해요",
             "ai_translated": "AI 번역",
             "see_original": "원문 보기",
             "hide_original": "원문 숨기기",
             "translating": "번역 중…",
             "guessed": "추정한 값이에요. 확인해 주세요"
         },
         "zh": {
             "category": "类别",
             "price": "价格",
             "budget": "预算",
             "dates": "日期",
             "time": "时间",
             "area": "区域",
             "route": "路线",
             "arrangement": "租住方式",
             "offer": "提供",
             "request": "寻找",
             "ai_translated": "AI 翻译",
             "see_original": "查看原文",
             "hide_original": "隐藏原文",
             "translating": "翻译中…",
             "guessed": "系统推测，请核对"
         }
     };

"""Category values shown in the reader's language."""
glob CATEGORY_NAMES: dict[str, dict[str, str]] = {
         "furniture": {"en": "Furniture", "ko": "가구", "zh": "家具"},
         "essentials": {"en": "Essentials", "ko": "생활용품", "zh": "生活用品"},
         "housing": {"en": "Housing", "ko": "주거", "zh": "住房"},
         "vehicle": {"en": "Vehicle", "ko": "이동수단", "zh": "交通工具"},
         "service": {"en": "Rides and help", "ko": "라이드·도움", "zh": "搭车与帮忙"}
     };

"""ARRANGEMENTS values in the reader's language (English is the stored value itself)."""
glob ARRANGEMENT_NAMES: dict[str, dict[str, str]] = {
         "roommate opening": {"en": "roommate opening", "ko": "룸메이트 자리", "zh": "合租空位"},
         "sublet": {"en": "sublet", "ko": "서브렛", "zh": "转租"},
         "lease assignment": {"en": "lease assignment", "ko": "계약 양도", "zh": "租约转让"},
         "new lease": {"en": "new lease", "ko": "신규 계약", "zh": "新租约"}
     };

"""Match reasons by code (market/matching.jac match_pair). The English templates, filled in,
are exactly the English reason strings stored on Suggestion.reasons. Slots: route_from,
route_to, minutes, price, budget (formatted money, e.g. "$25"), arrangement, area."""
glob REASON_PHRASES: dict[str, dict[str, str]] = {
         "same_route": {
             "en": "Same route: {route_from} to {route_to}",
             "ko": "같은 경로: {route_from} → {route_to}",
             "zh": "同一路线：{route_from} → {route_to}"
         },
         "same_day": {"en": "Same day", "ko": "같은 날이에요", "zh": "同一天"},
         "dates_overlap": {"en": "Dates overlap", "ko": "날짜가 겹쳐요", "zh": "日期有重叠"},
         "times_overlap": {"en": "Times overlap", "ko": "시간이 겹쳐요", "zh": "时间有重叠"},
         "times_apart": {
             "en": "Times are {minutes} minutes apart",
             "ko": "시간 차이 {minutes}분",
             "zh": "时间相差 {minutes} 分钟"
         },
         "free": {"en": "Free", "ko": "무료", "zh": "免费"},
         "within_budget": {
             "en": "{price} is within the {budget} budget",
             "ko": "{price}, 예산 {budget} 이내",
             "zh": "{price}，在 {budget} 预算内"
         },
         "same_arrangement": {
             "en": "Both want a {arrangement}",
             "ko": "둘 다 {arrangement} 희망",
             "zh": "双方都想要{arrangement}"
         },
         "same_area": {"en": "Both in {area}", "ko": "둘 다 {area}", "zh": "都在 {area}"}
     };

"""Help me decide risk flags by code (market/decide.jac risk_flags); English is today's text."""
glob RISK_FLAG_PHRASES: dict[str, dict[str, str]] = {
         "hard_to_reverse_payment": {
             "en": "Mentions a payment method that is hard to reverse (wire, gift card, app transfer)",
             "ko": "되돌리기 어려운 결제 방법을 언급해요 (송금, 기프트 카드, 앱 송금)",
             "zh": "提到难以追回的付款方式（电汇、礼品卡、应用转账）"
         },
         "deposit_pressure": {
             "en": "Asks for a deposit or quick decision, possibly before viewing",
             "ko": "보증금이나 빠른 결정을 요구해요. 직접 보기 전일 수도 있어요",
             "zh": "要求先付押金或尽快决定，可能在看房之前"
         },
         "low_rent": {
             "en": "Rent is far below usual Ann Arbor prices",
             "ko": "월세가 앤아버 평균보다 훨씬 낮아요",
             "zh": "租金远低于安娜堡的一般价格"
         }
     };

"""Help me decide missing information by code (market/decide.jac missing_info); English is
today's text."""
glob MISSING_INFO_PHRASES: dict[str, dict[str, str]] = {
         "price": {"en": "price", "ko": "가격", "zh": "价格"},
         "dates": {"en": "dates", "ko": "날짜", "zh": "日期"},
         "lease_dates": {"en": "lease dates", "ko": "계약 기간", "zh": "租期"},
         "area": {"en": "area", "ko": "지역", "zh": "区域"},
         "arrangement": {
             "en": "arrangement (sublet, roommate opening, lease assignment or new lease)",
             "ko": "계약 형태 (서브렛, 룸메이트 자리, 계약 양도, 신규 계약)",
             "zh": "租住方式（转租、合租空位、租约转让或新租约）"
         },
         "time": {"en": "time", "ko": "시간", "zh": "时间"}
     };

"""The label table for `lang`; any language outside the pilot set gets English."""
def labels_for(lang: str) -> dict[str, str] {
    return LABELS[lang] if lang in LABELS else LABELS["en"];
}

"""Render `code` from a phrase table (REASON_PHRASES, RISK_FLAG_PHRASES, ...) in `lang`, filling
{slot}s from `values`. Falls back to English for other languages and to "" for an unknown code."""
def phrase(
    table: dict[str, dict[str, str]],
    code: str,
    lang: str,
    values: dict[str, str] | None = None
) -> str {
    if code not in table {
        return "";
    }
    texts = table[code];
    text = texts[lang] if lang in texts else texts["en"];
    if values is None {
        return text;
    }
    for key in values {
        text = text.replace("{" + key + "}", str(values[key]));
    }
    return text;
}

"""Match reasons as a `lang` reader sees them. `reasons` are the stored English strings and
`codes` their {"code", "values"} entries (market/matching.jac), in the same order. Each code is
rendered from REASON_PHRASES, with an arrangement shown in the reader's language (areas and
routes stay as written); an unknown code keeps its English reason. English readers, and
suggestions stored without codes, get the stored English unchanged."""
def reasons_for(
    reasons: list[str], codes: list[dict[str, any]], lang: str
) -> list[str] {
    if not lang or lang == "en" or not codes or len(codes) != len(reasons) {
        return reasons;
    }
    out: list[str] = [];
    for (i, item) in enumerate(codes) {
        values: dict[str, str] = dict(item.get("values", {}) or {});
        chosen = values.get("arrangement", "");
        if chosen in ARRANGEMENT_NAMES {
            names = ARRANGEMENT_NAMES[chosen];
            values["arrangement"] = names[lang] if lang in names else chosen;
        }
        text = phrase(REASON_PHRASES, item.get("code", ""), lang, values);
        out.append(text or reasons[i]);
    }
    return out;
}
