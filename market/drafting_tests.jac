"""Tests for AI drafting (U3). The model is always MockLLM; no test calls a real provider."""

import os;
import tempfile;
import ai.draft;
import from jaclang.byllm.lib { MockLLM, MockError, AuthenticationError }
import from jaclang.testing.testing { JacTestClient }
import from ai.draft { PostDraft, PostKind, Category }
import from market.drafting { make_draft, match_area, DraftCard }

glob TODAY: str = "2026-09-30";

"""Make the next model call return `outputs`, in order."""
def mock(outputs: list[any]) -> MockLLM {
    fake = MockLLM(outputs=outputs);
    ai.draft.drafter = fake;
    return fake;
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

test "an unverified student cannot draft" {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    client = JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
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
    os.environ["UARRIVED_DEV_MODE"] = "1";
    client = JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
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
        assert client.post("/function/list_my_posts", json={}).json()["data"]["result"]
            == [];
    } finally {
        client.close();
    }
}
