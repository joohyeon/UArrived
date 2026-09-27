"""Tests for Help me decide (U10). The model is always MockLLM."""

import os;
import tempfile;
import ai.decide;
import ai.translate;
import from jaclang.byllm.lib { MockLLM, MockError, AuthenticationError }
import from jaclang.testing.testing { JacTestClient }
import from ai.decide { DecideNotes }
import from ai.translate { PostText, PostTranslations, Translation }
import from market.graph { Post }
import from market.decide {
    missing_info,
    missing_codes,
    risk_flags,
    risk_codes,
    clean_notes,
    notes_for,
    BANNED_CLAIMS
}

test "a sublet with no lease dates lists them as missing (AE6)" {
    sublet = Post(
        owner_root="jae",
        kind="offer",
        category="housing",
        title="Room",
        price=780.0,
        arrangement="sublet",
        area="Kerrytown"
    );
    assert missing_info(sublet) == ["lease dates"];
}

test "missing info covers price, area, arrangement and ride time" {
    desk = Post(owner_root="jae", kind="offer", category="furniture", title="Desk");
    assert missing_info(desk) == ["price", "dates", "area"];
    room = Post(
        owner_root="jae",
        kind="offer",
        category="housing",
        title="Room",
        price=700.0,
        available_from="2026-09-01",
        area="Downtown"
    );
    assert missing_info(room)
        == ["arrangement (sublet, roommate opening, lease assignment or new lease)"];
    ride = Post(
        owner_root="jae",
        kind="request",
        category="service",
        title="Ride",
        route_from="DTW",
        route_to="Ann Arbor",
        available_from="2026-08-20"
    );
    assert missing_info(ride) == ["time"];
}

test "known risk patterns are flagged by rule" {
    scammy = Post(
        owner_root="x",
        kind="offer",
        category="housing",
        title="Cheap room",
        price=150.0,
        description="Send a deposit by Zelle to hold the room before viewing"
    );
    flags = risk_flags(scammy);
    assert len(flags) == 3;
    fine = Post(
        owner_root="x",
        kind="offer",
        category="furniture",
        title="Desk",
        price=25.0,
        description="Pick up Saturday"
    );
    assert risk_flags(fine) == [];
}

test "a ko sublet whose English copy asks to wire the deposit gets the payment flag (AE11)" {
    sublet = Post(
        owner_root="jae",
        kind="offer",
        category="housing",
        title="방 양도",
        description="보기 전에 보증금 송금해 주세요",
        price=800.0,
        arrangement="sublet",
        language="ko",
        texts={
            "ko": {"title": "방 양도", "description": "보기 전에 보증금 송금해 주세요"},
            "en": {
                "title": "Room sublet",
                "description": "Please wire the deposit before viewing"
            }
        }
    );
    flags = risk_flags(sublet);
    assert any(["payment method" in f for f in flags]);
    assert any(["deposit" in f for f in flags]);
    sublet.texts = {};
    assert risk_flags(sublet) == [];
}

test "a ko reader sees the deposit-before-viewing flag and missing lease dates in Korean" {
    sublet = Post(
        owner_root="jae",
        kind="offer",
        category="housing",
        title="Room",
        price=780.0,
        arrangement="sublet",
        area="Kerrytown",
        description="Send the deposit before viewing"
    );
    assert missing_codes(sublet) == ["lease_dates"];
    assert missing_info(sublet) == ["lease dates"];
    assert missing_info(sublet, "ko") == ["계약 기간"];
    assert risk_codes(sublet) == ["deposit_pressure"];
    assert risk_flags(sublet, "ko") == ["보증금이나 빠른 결정을 요구해요. 직접 보기 전일 수도 있어요"];
    assert risk_flags(sublet)
        == ["Asks for a deposit or quick decision, possibly before viewing"];
}

test "English notes stay as they are; failed translations fall back to English" {
    ai.translate.translator = MockLLM(outputs=[Translation(text="방을 먼저 볼 수 있나요?")]);
    assert notes_for(["Can I see the room first?"], "en")
        == ["Can I see the room first?"];
    assert notes_for(["Can I see the room first?", "Ask for the lease."], "ko")
        == ["방을 먼저 볼 수 있나요?", "Ask for the lease."];
}

test "AI notes that call a post safe or legit are dropped" {
    kept = clean_notes(
        [
            "Ask for the lease dates.",
            "This post looks safe.",
            "Seems legit to me",
            "  ",
            "Ask to see the room first."
        ]
    );
    assert kept == ["Ask for the lease dates.", "Ask to see the room first."];
    assert clean_notes(["Is it unsafe to pay by wire?"])
        == ["Is it unsafe to pay by wire?"];
}

def call(client: JacTestClient, name: str, body: dict[str, any]) -> any {
    return client.post(f"/function/{name}", json=body).json()["data"]["result"];
}

def student(client: JacTestClient, email: str) {
    client.register_user(email, "password123");
    token = call(client, "start_verification", {"email": email})["dev_token"];
    assert call(client, "confirm_verification", {"token": token})["ok"];
}

"""Two sublets from Jae; returns their ids, acting as Mina."""
def two_sublets(client: JacTestClient) -> list[str] {
    student(client, "jae@umich.edu");
    a = call(
        client,
        "publish_post",
        {
            "fields": {
                "kind": "offer",
                "category": "housing",
                "title": "Room A",
                "price": 780,
                "arrangement": "sublet"
            }
        }
    )["post"]["id"];
    b = call(
        client,
        "publish_post",
        {
            "fields": {
                "kind": "offer",
                "category": "housing",
                "title": "Room B",
                "price": 200,
                "arrangement": "sublet",
                "available_from": "2099-09-01",
                "description": "wire the deposit today"
            }
        }
    )["post"]["id"];
    student(client, "mina@umich.edu");
    return [a, b];
}

test "comparing two posts gives facts, missing info, flags and filtered AI notes" {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    os.environ["ANTHROPIC_API_KEY"] = "";
    ai.decide.advisor = MockLLM(
        outputs=[
            DecideNotes(
                questions=[
                    "When does the lease start and end?",
                    "Can I see the room before paying?"
                ],
                risk_notes=[
                    "Room B looks totally safe.",
                    "Room B asks for a wire transfer, which is hard to reverse."
                ]
            )
        ]
    );
    client = JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
    try {
        ids = two_sublets(client);
        r = call(client, "help_me_decide", {"post_ids": ids});
        assert r["ok"] and r["ai_generated"];
        assert [c["post"]["title"] for c in r["posts"]] == ["Room A", "Room B"];
        assert "lease dates" in r["posts"][0]["missing"];
        assert len(r["posts"][1]["flags"]) == 3;
        assert r["questions"]
            == [
                "When does the lease start and end?",
                "Can I see the room before paying?"
            ];
        assert r["risk_notes"]
            == ["Room B asks for a wire transfer, which is hard to reverse."];
    } finally {
        client.close();
    }
}

test "when AI fails the facts and flags still show, without AI notes" {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    os.environ["ANTHROPIC_API_KEY"] = "";
    ai.decide.advisor = MockLLM(
        outputs=[MockError(error=AuthenticationError("no key"))]
    );
    client = JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
    try {
        ids = two_sublets(client);
        r = call(client, "help_me_decide", {"post_ids": ids});
        assert r["ok"] and not r["ai_generated"] and r["ai_note"];
        assert r["questions"] == [] and len(r["posts"]) == 2;
        assert len(r["posts"][1]["flags"]) == 3;
    } finally {
        client.close();
    }
}

test "one post, four posts, or a closed post cannot be compared" {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    os.environ["ANTHROPIC_API_KEY"] = "";
    client = JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
    try {
        ids = two_sublets(client);
        assert not call(client, "help_me_decide", {"post_ids": [ids[0]]})["ok"];
        assert not call(client, "help_me_decide", {"post_ids": [ids[0], ids[0]]})["ok"];
        assert not call(client, "help_me_decide", {"post_ids": ids + ["x", "y"]})["ok"];
        assert not call(client, "help_me_decide", {"post_ids": [ids[0], "not-a-post"]})[
            "ok"
        ];
    } finally {
        client.close();
    }
}

test "help me decide shows a ko sublet in the reader's language and advises on its English" {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    os.environ["ANTHROPIC_API_KEY"] = "";
    ai.translate.translator = MockLLM(
        outputs=[
            PostTranslations(
                items=[
                    PostText(
                        language="en",
                        title="Room sublet",
                        description="Please wire the deposit before viewing, $800 a month"
                    ),
                    PostText(language="zh", title="房间转租", description="看房前请电汇押金，每月$800")
                ]
            ),
            PostTranslations(items=[])
        ]
    );
    advisor = MockLLM(
        outputs=[DecideNotes(questions=["Can I see the room before paying?"])]
    );
    ai.decide.advisor = advisor;
    client = JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
    try {
        student(client, "jae@umich.edu");
        ko_room = call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "offer",
                    "category": "housing",
                    "title": "방 양도",
                    "description": "보기 전에 보증금 송금해 주세요, 월 $800",
                    "price": 800,
                    "arrangement": "sublet",
                    "language": "ko"
                }
            }
        )["post"]["id"];
        room_a = call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "offer",
                    "category": "housing",
                    "title": "Room A",
                    "price": 780,
                    "arrangement": "sublet"
                }
            }
        )["post"]["id"];
        student(client, "mina@umich.edu");
        r = call(client, "help_me_decide", {"post_ids": [room_a, ko_room]});
        assert r["ok"] and r["ai_generated"];
        shown = r["posts"][1]["post"];
        assert shown["title"] == "Room sublet" and shown["ai_translated"];
        assert shown["original_title"] == "방 양도";
        assert any(["payment method" in f for f in r["posts"][1]["flags"]]);
        assert "wire the deposit" in str(advisor.sent("messages")[0]);
    } finally {
        client.close();
    }
}

test "a ko reader comparing two sublets gets Korean labels and notes, filtered first (AE11)" {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    os.environ["ANTHROPIC_API_KEY"] = "";
    translator = MockLLM(
        outputs=[
            PostTranslations(items=[]),
            PostTranslations(items=[]),
            Translation(text="임대 기간은 언제 시작하고 끝나나요?"),
            Translation(text="B 방은 되돌리기 어려운 송금을 요구해요.")
        ]
    );
    ai.translate.translator = translator;
    ai.decide.advisor = MockLLM(
        outputs=[
            DecideNotes(
                questions=["When does the lease start and end?"],
                risk_notes=[
                    "This listing is safe.",
                    "Room B asks for a wire transfer, which is hard to reverse."
                ]
            )
        ]
    );
    client = JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
    try {
        ids = two_sublets(client);
        assert call(
            client, "update_my_profile", {"changes": {"preferred_language": "ko"}}
        )["ok"];
        r = call(client, "help_me_decide", {"post_ids": ids});
        assert r["ok"] and r["ai_generated"];
        assert r["posts"][0]["missing"] == ["계약 기간", "지역"];
        assert r["posts"][0]["missing_codes"] == ["lease_dates", "area"];
        assert r["posts"][1]["flag_codes"]
            == ["hard_to_reverse_payment", "deposit_pressure", "low_rent"];
        assert "되돌리기 어려운 결제 방법을 언급해요 (송금, 기프트 카드, 앱 송금)" in r["posts"][1]["flags"];
        assert r["questions"] == ["임대 기간은 언제 시작하고 끝나나요?"];
        assert r["risk_notes"] == ["B 방은 되돌리기 어려운 송금을 요구해요."];
        sent = str(translator.sent("messages"));
        assert "This listing is safe" not in sent;
        shown = str(
            [
                r["questions"],
                r["risk_notes"],
                [c["flags"] + c["missing"] for c in r["posts"]]
            ]
        ).lower();
        assert not any([w in shown for w in BANNED_CLAIMS]);
    } finally {
        client.close();
    }
}
