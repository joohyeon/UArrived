"""Tests for AI drafting (U3). The model is always MockLLM; no test calls a real provider."""

import ai.draft;
import from jaclang.byllm.lib { MockLLM, MockError, AuthenticationError }
import from market.testkit { served }
import from ai.draft { PostDraft, PostKind, Category, DraftSet }
import from core.profile { Profile }
import from market.drafting {
    make_draft,
    match_area,
    date_supported,
    time_supported,
    DraftCard,
    DraftResult
}
import from market.translation { digit_groups }

glob TODAY: str = "2026-09-30";

"""Make the next model calls return `outputs`, in order. A bare PostDraft stands for an English
message with that one draft."""
def mock(outputs: list[any]) -> MockLLM {
    fake = MockLLM(
        outputs=[
            DraftSet(language="en", drafts=[o]) if isinstance(o, PostDraft) else o
            for o in outputs
        ]
    );
    ai.draft.drafter = fake;
    return fake;
}

"""The full result for `message`, failing the test if drafting failed."""
def drafted_all(message: str, profile: Profile | None = None) -> DraftResult {
    result = make_draft(message, TODAY, profile);
    assert result.ok and result.drafts , result.error;
    return result;
}

glob JIWOO: str = "8월 20일 오후 3시 DTW 도착해요. 노스캠퍼스 근처 방 구해요, 900불 이하, 9월 1일부터. 책상도 50불 이하로 구해요.";

"""Ji-woo's three needs as the model would return them (AE8)."""
def jiwoo_set -> DraftSet {
    return DraftSet(
        language="ko",
        drafts=[
            PostDraft(
                kind=PostKind.REQUEST,
                category=Category.SERVICE,
                title="DTW에서 앤아버 가는 차편",
                description="8월 20일 오후 3시 DTW 도착, 같이 탈 사람 구해요.",
                title_en="Ride from DTW to Ann Arbor",
                description_en="Arriving at DTW Aug 20 at 3pm, looking to share a ride.",
                available_from="2026-08-20",
                available_until="2026-08-20",
                time_from="15:00",
                route_from="DTW",
                route_to="Ann Arbor"
            ),
            PostDraft(
                kind=PostKind.REQUEST,
                category=Category.HOUSING,
                title="노스캠퍼스 근처 방 구해요",
                description="9월 1일부터 노스캠퍼스 근처 방, 900불 이하.",
                title_en="Looking for a room near North Campus",
                description_en="Room near North Campus from Sep 1, under $900.",
                price=900.0,
                area="north campus",
                available_from="2026-09-01",
                available_until="2026-12-31",
                arrangement="sublet",
                guessed=["available_until"]
            ),
            PostDraft(
                kind=PostKind.REQUEST,
                category=Category.FURNITURE,
                title="책상 구해요",
                description="책상 50불 이하.",
                title_en="Looking for a desk",
                description_en="Desk under $50.",
                price=50.0
            )
        ]
    );
}

"""The draft card from `message`, failing the test if drafting failed."""
def drafted(message: str) -> DraftCard {
    result = make_draft(message, TODAY);
    assert result.ok and result.draft is not None , result.error;
    return result.draft;
}

test "a free mattress message becomes a free furniture offer in North Campus (AE1)" {
    fake = mock(
        [
            PostDraft(
                kind=PostKind.OFFER,
                category=Category.FURNITURE,
                title="Free twin mattress",
                description="Twin mattress, free, pick up in North Campus.",
                free=True,
                area="north campus",
                available_until="2026-10-03",
                guessed=["available_until"]
            )
        ]
    );
    card = drafted("free twin mattress, north campus, gone by sat");
    assert card.kind == "offer" and card.category == "furniture";
    assert card.free and card.price is None;
    assert card.area == "North Campus";
    assert card.available_until == "2026-10-03" and "available_until" in card.guessed;
    assert card.missing == [] and card.ai_generated;
    assert TODAY in str(fake.sent("messages")[0]);
}

test "a desk request keeps its budget and needs no price" {
    mock(
        [
            PostDraft(
                kind=PostKind.REQUEST,
                category=Category.FURNITURE,
                title="Looking for a desk",
                description="Desk under $50, moving in Aug 20.",
                price=50.0,
                available_from="2026-08-20"
            )
        ]
    );
    card = drafted("looking for a desk under $50, move in Aug 20");
    assert card.kind == "request" and card.price == 50.0;
    assert card.available_from == "2026-08-20" and card.missing == [];
    assert card.suggested_price is None;
}

test "a ride request keeps its route and time window" {
    mock(
        [
            PostDraft(
                kind=PostKind.REQUEST,
                category=Category.SERVICE,
                title="Ride from DTW",
                description="Arriving at DTW Aug 20 around 3pm, looking to share a ride.",
                available_from="2026-08-20",
                available_until="2026-08-20",
                time_from="14:00",
                time_to="16:00",
                route_from="DTW",
                route_to="Ann Arbor"
            )
        ]
    );
    card = drafted("arriving DTW Aug 20 3pm, anyone sharing a ride?");
    assert card.category == "service" and card.route_from == "DTW";
    assert card.time_from == "14:00" and card.time_to == "16:00";
    assert card.missing == [];
}

test "housing without an arrangement type is flagged missing, not defaulted" {
    mock(
        [
            PostDraft(
                kind=PostKind.OFFER,
                category=Category.HOUSING,
                title="Room near campus",
                description="Room available Sept to Dec.",
                price=780.0,
                arrangement="something vague"
            )
        ]
    );
    card = drafted("room near campus sept-dec $780");
    assert card.arrangement == "" and "arrangement" in card.missing;
}

test "invalid AI values are cleared and marked guessed" {
    mock(
        [
            PostDraft(
                kind=PostKind.OFFER,
                category=Category.ESSENTIALS,
                title="Lamp",
                description="Desk lamp.",
                price=-5.0,
                available_from="next tuesday",
                time_from="3pm",
                area="Ypsilanti",
                suggested_price=-1.0
            )
        ]
    );
    card = drafted("lamp");
    assert card.price is None and "price" in card.guessed and "price" in card.missing;
    assert card.available_from == "" and "available_from" in card.guessed;
    assert card.time_from == "" and "time_from" in card.guessed;
    assert card.area == "Other" and "area" in card.guessed;
    assert card.suggested_price is None;
}

test "a suggested price is kept only for item offers" {
    mock(
        [
            PostDraft(
                kind=PostKind.REQUEST,
                category=Category.FURNITURE,
                title="Need a chair",
                description="Chair.",
                suggested_price=20.0,
                price_reason="typical"
            )
        ]
    );
    card = drafted("need a chair");
    assert card.suggested_price is None and card.price_reason == "";
}

test "unreadable model output becomes a friendly error, not a crash" {
    mock(["not a draft", "still not", "nope", "no"]);
    result = make_draft("asdf", TODAY);
    assert not result.ok and "Couldn't read that" in result.error;
    assert result.draft is None;
}

test "when AI is unavailable the student gets a manual, non-AI form with their words" {
    ai.draft.drafter = MockLLM(
        outputs=[MockError(error=AuthenticationError("no API key"))]
    );
    result = make_draft("selling a desk lamp $5, north campus", TODAY);
    assert result.ok and "fill in the details yourself" in result.notice;
    assert result.draft is not None;
    assert not result.draft.ai_generated;
    assert result.draft.title == "selling a desk lamp $5, north campus";
    assert result.draft.guessed == [] and "price" in result.draft.missing;
}

test "empty and overlong messages are refused before calling the model" {
    fake = mock([]);
    assert not make_draft("   ", TODAY).ok;
    assert not make_draft("x" * 1001, TODAY).ok;
    assert len(fake.sent("messages")) == 0;
}

test "area text maps onto the fixed Ann Arbor list" {
    assert match_area("Kerrytown") == "Kerrytown";
    assert match_area("near central campus") == "Central Campus";
    assert match_area("") == "";
    assert match_area("Detroit") == "Other";
}

test "one Korean message becomes three bilingual drafts (AE8)" {
    mock([jiwoo_set()]);
    result = drafted_all(JIWOO);
    assert result.language == "ko" and len(result.drafts) == 3;
    assert result.draft is result.drafts[0];
    (ride, room, desk) = (result.drafts[0], result.drafts[1], result.drafts[2]);
    assert [c.category for c in result.drafts] == ["service", "housing", "furniture"];
    for c in result.drafts {
        assert c.language == "ko" and c.ai_generated;
        assert c.title_en and c.description_en and c.title_en != c.title;
    }
    assert ride.route_from == "DTW" and ride.time_from == "15:00";
    assert "time_from" not in ride.guessed and "available_from" not in ride.guessed;
    assert room.area == "North Campus" and room.arrangement == "sublet";
    assert room.price == 900.0 and "price" not in room.guessed;
    assert "available_from" not in room.guessed and "available_until" in room.guessed;
    assert desk.price == 50.0 and "price" not in desk.guessed;
}

test "a single-need English message gives one card whose English copy is the original" {
    mock(
        [
            PostDraft(
                kind=PostKind.OFFER,
                category=Category.ESSENTIALS,
                title="Desk lamp $5",
                description="Selling a desk lamp for $5.",
                title_en="Lamp",
                price=5.0
            )
        ]
    );
    result = drafted_all("selling a desk lamp $5");
    assert result.language == "en" and len(result.drafts) == 1;
    card = result.drafts[0];
    assert card.language == "en";
    assert card.title_en == card.title == "Desk lamp $5";
    assert card.description_en == card.description;
}

test "more than three drafts are trimmed to three" {
    drafts = [
        PostDraft(
            kind=PostKind.REQUEST,
            category=Category.ESSENTIALS,
            title=f"Need item {i}",
            description=f"Item {i}."
        ) for i in range(5)
    ];
    mock([DraftSet(language="en", drafts=drafts)]);
    result = drafted_all("need items 0 1 2 3 4");
    assert len(result.drafts) == 3;
    assert [c.title for c in result.drafts]
        == ["Need item 0", "Need item 1", "Need item 2"];
}

test "an unknown language code is kept and its drafts still normalize" {
    mock(
        [
            DraftSet(
                language="FR",
                drafts=[
                    PostDraft(
                        kind=PostKind.OFFER,
                        category=Category.FURNITURE,
                        title="Bureau à vendre",
                        description="Bureau, 30 dollars, Kerrytown.",
                        title_en="Desk for sale",
                        description_en="Desk, 30 dollars, Kerrytown.",
                        price=30.0,
                        area="kerrytown",
                        time_from="3pm"
                    )
                ]
            )
        ]
    );
    result = drafted_all("Bureau à vendre, 30 dollars, Kerrytown");
    assert result.language == "fr" and result.drafts[0].language == "fr";
    card = result.drafts[0];
    assert card.area == "Kerrytown"
        and card.time_from == ""
        and "time_from" in card.guessed;
    assert card.title_en == "Desk for sale";
}

test "a malformed language code falls back to the poster's language" {
    mock([DraftSet(language="korean!", drafts=jiwoo_set().drafts[:1])]);
    result = drafted_all(JIWOO, Profile(preferred_language="zh"));
    assert result.language == "zh";
}

test "an empty draft set is a friendly error" {
    mock([DraftSet(language="en", drafts=[])]);
    result = make_draft("hmm", TODAY);
    assert not result.ok and "Couldn't read that" in result.error;
}

test "a price, date or time missing from the message is marked guessed (R24)" {
    wrong = jiwoo_set();
    wrong.drafts[1].price = 90.0;
    wrong.drafts[0].available_from = "2026-08-19";
    wrong.drafts[0].time_from = "16:30";
    mock([wrong]);
    result = drafted_all(JIWOO);
    assert "price" in result.drafts[1].guessed;
    assert "available_from" in result.drafts[0].guessed;
    assert "available_until" not in result.drafts[0].guessed;
    assert "time_from" in result.drafts[0].guessed;
    assert result.drafts[2].guessed == [];
}

test "dates and times are checked by their numbers, not their spelling" {
    groups = digit_groups("8월 20일 오후 3시");
    assert date_supported("2026-08-20", groups);
    assert not date_supported("2026-08-21", groups);
    assert date_supported("2026-08-25", digit_groups("书桌 8月21–25日"));
    assert date_supported("2026-08-20", digit_groups("move in Aug 20"));
    assert not date_supported("2026-03-20", digit_groups("market on the 20th"));
    assert time_supported("15:00", groups) and not time_supported("15:30", groups);
    assert time_supported("15:00", digit_groups("arriving 3pm"));
    assert time_supported("00:00", digit_groups("at 12 midnight"));
    assert not time_supported("14:00", digit_groups("arriving 3pm"));
}

test "when AI is unavailable a Korean student's manual card is in Korean" {
    ai.draft.drafter = MockLLM(
        outputs=[MockError(error=AuthenticationError("no API key"))]
    );
    result = make_draft("책상 팝니다 $40", TODAY, Profile(preferred_language="ko"));
    assert result.ok and result.language == "ko" and len(result.drafts) == 1;
    card = result.drafts[0];
    assert result.draft is card;
    assert card.language == "ko" and not card.ai_generated;
    assert card.title_en == "";
}

test "a first draft sets an unchosen profile language, never a chosen one (R29)" {
    fresh = Profile();
    mock([jiwoo_set()]);
    drafted_all(JIWOO, fresh);
    assert fresh.preferred_language == "ko" and not fresh.language_chosen;
    chose = Profile(preferred_language="en", language_chosen=True);
    mock([jiwoo_set()]);
    drafted_all(JIWOO, chose);
    assert chose.preferred_language == "en";
    other = Profile();
    mock([DraftSet(language="fr", drafts=jiwoo_set().drafts[:1])]);
    drafted_all(JIWOO, other);
    assert other.preferred_language == "en";
}

test "with AI switched off, drafting over the served endpoint gives a manual card in the profile's language" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        token = client.post(
            "/function/start_verification", json={"email": "mina@umich.edu"}
        ).json()["data"]["result"]["dev_token"];
        client.post("/function/confirm_verification", json={"token": token});
        client.post(
            "/function/update_my_profile",
            json={"changes": {"preferred_language": "ko"}}
        );
        result = client.post(
            "/function/draft_from_message", json={"message": "책상 팝니다 $40"}
        ).json()["data"]["result"];
        assert result["ok"] and "fill in the details yourself" in result["notice"];
        assert result["language"] == "ko" and len(result["drafts"]) == 1;
        card = result["drafts"][0];
        assert card["language"] == "ko" and not card["ai_generated"];
        assert card["title"] == "책상 팝니다 $40";
    } finally {
        client.close();
    }
}

test "an unverified student cannot draft" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        resp = client.post(
            "/function/draft_from_message", json={"message": "desk $25"}
        );
        result = resp.json()["data"]["result"];
        assert not result["ok"] and "Verify" in result["error"];
    } finally {
        client.close();
    }
}

test "the ride prefill needs a verified student and returns a reviewable draft (AE4)" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        denied = client.post(
            "/function/ride_prefill", json={"day": "2099-08-20", "time": "15:00"}
        ).json()["data"]["result"];
        assert not denied["ok"];
        token = client.post(
            "/function/start_verification", json={"email": "mina@umich.edu"}
        ).json()["data"]["result"]["dev_token"];
        client.post("/function/confirm_verification", json={"token": token});
        got = client.post(
            "/function/ride_prefill", json={"day": "2099-08-20", "time": "15:00"}
        ).json()["data"]["result"];
        assert got["ok"]
            and got["draft"]["route_from"] == "DTW"
            and got["draft"]["time_to"] == "17:00";
        assert got["language"] == "en" and len(got["drafts"]) == 1;
        assert got["draft"]["language"] == "en";
        assert client.post("/function/list_my_posts", json={}).json()["data"]["result"]
            == [];
    } finally {
        client.close();
    }
}
