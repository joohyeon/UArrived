"""Served-app tests for two-way matching and suggestions (U5), with several real students, and
match reasons in the reader's language (native-language U6). No test calls a real model: AI is
off (market/testkit.jac), so post translations fall back to the original."""

import from jaclang.testing.testing { JacTestClient }
import from market.testkit { served }
import from market.constants { reasons_for }
import from market.graph { Post, Suggestion }
import from market.matching { Match, match_pair }

"""The match between `a` and `b` on 2026-08-01; fails the test if they don't match."""
def matched(a: Post, b: Post) -> Match {
    m = match_pair(a, b, "2026-08-01");
    if m is None {
        raise AssertionError("expected a match");
    }
    return m;
}

"""Jae's $25 desk and Mina's $50 desk request, overlapping dates, both on Central Campus."""
def desk_pair -> tuple[Post, Post] {
    offer = Post(
        owner_root="jae",
        kind="offer",
        category="furniture",
        title="Desk",
        price=25.0,
        available_from="2026-08-18",
        available_until="2026-08-25",
        area="Central Campus"
    );
    request = Post(
        owner_root="mina",
        kind="request",
        category="furniture",
        title="Need a desk",
        price=50.0,
        available_from="2026-08-20",
        available_until="2026-08-22",
        area="Central Campus"
    );
    return (offer, request);
}

test "a desk match carries reason codes a ko reader sees in Korean with $25 and $50" {
    (offer, request) = desk_pair();
    m = matched(offer, request);
    assert [c["code"] for c in m.codes]
        == ["dates_overlap", "within_budget", "same_area"];
    assert m.codes[1]["values"] == {"price": "$25", "budget": "$50"};
    ko = reasons_for(m.reasons, m.codes, "ko");
    assert ko == ["날짜가 겹쳐요", "$25, 예산 $50 이내", "둘 다 Central Campus"];
}

test "an English reader sees exactly the stored English reasons" {
    (offer, request) = desk_pair();
    m = matched(offer, request);
    expected = [
        "Dates overlap",
        "$25 is within the $50 budget",
        "Both in Central Campus"
    ];
    assert m.reasons == expected;
    assert reasons_for(m.reasons, m.codes, "en") == expected;
    assert reasons_for(m.reasons, m.codes, "") == expected;
}

test "rides 35 minutes apart render in Korean with 35" {
    a = Post(
        owner_root="jae",
        kind="request",
        category="service",
        title="Ride",
        route_from="DTW",
        route_to="Ann Arbor",
        available_from="2026-08-20",
        time_from="14:00"
    );
    b = Post(
        owner_root="mina",
        kind="request",
        category="service",
        title="Ride",
        route_from="DTW",
        route_to="Ann Arbor",
        available_from="2026-08-20",
        time_from="14:35"
    );
    m = matched(a, b);
    assert "Times are 35 minutes apart" in m.reasons;
    ko = reasons_for(m.reasons, m.codes, "ko");
    assert "시간 차이 35분" in ko;
    assert "같은 경로: DTW → Ann Arbor" in ko;
    assert "时间相差 35 分钟" in reasons_for(m.reasons, m.codes, "zh");
}

test "an arrangement reason names the arrangement in the reader's language" {
    sublet = Post(
        owner_root="jae",
        kind="offer",
        category="housing",
        title="Room",
        price=700.0,
        arrangement="sublet"
    );
    wants = Post(
        owner_root="mina",
        kind="request",
        category="housing",
        title="x",
        price=800.0,
        arrangement="sublet"
    );
    m = matched(sublet, wants);
    assert "Both want a sublet" in m.reasons;
    assert "双方都想要转租" in reasons_for(m.reasons, m.codes, "zh");
}

test "a suggestion stored without codes, or with an unknown code, keeps its English" {
    old = Suggestion(
        post_a="a",
        post_b="b",
        root_a="x",
        root_b="y",
        score=50,
        reasons=["Dates overlap"],
        created_on="2026-08-01"
    );
    assert old.reason_codes == [];
    assert reasons_for(old.reasons, old.reason_codes, "ko") == ["Dates overlap"];
    mixed = reasons_for(
        ["Dates overlap", "Something new"],
        [{"code": "dates_overlap", "values": {}}, {"code": "brand_new", "values": {}}],
        "ko"
    );
    assert mixed == ["날짜가 겹쳐요", "Something new"];
}

test "a ko reader's inbox lists the match reasons in Korean; an en reader's in English" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        assert call(
            client, "update_my_profile", {"changes": {"preferred_language": "ko"}}
        )["ok"];
        publish(client, desk_request());
        student(client, "jae@umich.edu");
        publish(client, desk_offer(25));
        assert "$25 is within the $50 budget"
            in call(client, "list_my_suggestions", {})[0]["reasons"];
        act_as(client, "mina@umich.edu");
        seen = call(client, "list_my_suggestions", {});
        assert len(seen) == 1;
        assert seen[0]["reasons"] == ["$25, 예산 $50 이내"];
    } finally {
        client.close();
    }
}

def call(client: JacTestClient, name: str, body: dict[str, any]) -> any {
    return client.post(f"/function/{name}", json=body).json()["data"]["result"];
}

def student(client: JacTestClient, email: str) {
    client.register_user(email, "password123");
    token = call(client, "start_verification", {"email": email})["dev_token"];
    assert call(client, "confirm_verification", {"token": token})["ok"];
}

def act_as(client: JacTestClient, email: str) {
    client.login(email, "password123");
}

def publish(client: JacTestClient, fields: dict[str, any]) -> str {
    result = call(client, "publish_post", {"fields": fields});
    assert result["ok"] , result["error"];
    return result["post"]["id"];
}

def desk_request -> dict[str, any] {
    return {
        "kind": "request",
        "category": "furniture",
        "title": "Looking for a desk",
        "price": 50
    };
}

def desk_offer(price: float) -> dict[str, any] {
    return {
        "kind": "offer",
        "category": "furniture",
        "title": "Solid wood desk",
        "price": price
    };
}

test "a new offer reaches an existing request, and only that student (AE7)" {
    client = served();
    try {
        student(client, "kai@umich.edu");
        student(client, "mina@umich.edu");
        publish(client, desk_request());
        student(client, "jae@umich.edu");
        publish(client, desk_offer(25));
        act_as(client, "mina@umich.edu");
        seen = call(client, "list_my_suggestions", {});
        assert len(seen) == 1;
        assert seen[0]["other_post"]["title"] == "Solid wood desk";
        assert "$25 is within the $50 budget" in seen[0]["reasons"];
        assert seen[0]["status"] == "open" and seen[0]["unread"];
        act_as(client, "kai@umich.edu");
        assert call(client, "list_my_suggestions", {}) == [];
    } finally {
        client.close();
    }
}

test "the poster sees who their post was suggested to (R10)" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        publish(client, desk_request());
        student(client, "jae@umich.edu");
        publish(client, desk_offer(25));
        mine = call(client, "list_my_suggestions", {});
        assert len(mine) == 1
            and mine[0]["other_post"]["title"] == "Looking for a desk";
    } finally {
        client.close();
    }
}

test "a request published after the offer is matched too (two-way)" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        publish(client, desk_offer(25));
        student(client, "mina@umich.edu");
        publish(client, desk_request());
        assert len(call(client, "list_my_suggestions", {})) == 1;
    } finally {
        client.close();
    }
}

test "editing the price above the budget withdraws the suggestion" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        publish(client, desk_request());
        student(client, "jae@umich.edu");
        post_id = publish(client, desk_offer(25));
        assert call(client, "edit_post", {"post_id": post_id, "changes": {"price": 80}})[
            "ok"
        ];
        act_as(client, "mina@umich.edu");
        assert call(client, "list_my_suggestions", {}) == [];
    } finally {
        client.close();
    }
}

test "stopping suggestions withdraws pending ones and blocks new ones" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        post_id = publish(client, desk_offer(25));
        student(client, "mina@umich.edu");
        publish(client, desk_request());
        act_as(client, "jae@umich.edu");
        assert call(client, "stop_suggestions", {"post_id": post_id});
        assert call(client, "list_my_suggestions", {}) == [];
        student(client, "kai@umich.edu");
        publish(client, desk_request());
        assert call(client, "list_my_suggestions", {}) == [];
    } finally {
        client.close();
    }
}

test "another student cannot stop suggestions for your post" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        post_id = publish(client, desk_offer(25));
        student(client, "mina@umich.edu");
        assert not call(client, "stop_suggestions", {"post_id": post_id});
        publish(client, desk_request());
        assert len(call(client, "list_my_suggestions", {})) == 1;
    } finally {
        client.close();
    }
}

test "a pending suggestion disappears once its post is done" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        publish(client, desk_request());
        student(client, "jae@umich.edu");
        post_id = publish(client, desk_offer(25));
        call(client, "mark_post_done", {"post_id": post_id});
        act_as(client, "mina@umich.edu");
        assert call(client, "list_my_suggestions", {}) == [];
    } finally {
        client.close();
    }
}

test "two students arriving at DTW within two hours are suggested to each other" {
    client = served();
    try {
        ride: dict[str, any] = {
            "kind": "request",
            "category": "service",
            "title": "Ride from DTW",
            "route_from": "DTW",
            "route_to": "Ann Arbor",
            "available_from": "2099-08-20",
            "time_from": "15:00"
        };
        student(client, "mina@umich.edu");
        publish(client, ride);
        student(client, "jae@umich.edu");
        later = dict(ride);
        later["time_from"] = "16:30";
        publish(client, later);
        seen = call(client, "list_my_suggestions", {});
        assert len(seen) == 1 and "Times are 90 minutes apart" in seen[0]["reasons"];
    } finally {
        client.close();
    }
}
