"""Served-app tests for two-way matching and suggestions (U5), with several real students."""

import os;
import tempfile;
import from jaclang.testing.testing { JacTestClient }

def served -> JacTestClient {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    os.environ["ANTHROPIC_API_KEY"] = "";
    return JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
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
