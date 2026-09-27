"""Tests for Help me decide (U10). The model is always MockLLM."""

import os;
import tempfile;
import ai.decide;
import from jaclang.byllm.lib { MockLLM, MockError, AuthenticationError }
import from jaclang.testing.testing { JacTestClient }
import from ai.decide { DecideNotes }
import from market.graph { Post }
import from market.decide { missing_info, risk_flags, clean_notes }

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
