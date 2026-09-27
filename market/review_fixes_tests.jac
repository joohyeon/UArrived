"""Served-app tests for the code-review fixes on U1-U11 (each named for the failure it prevents)."""

import os;
import tempfile;
import from jaclang.testing.testing { JacTestClient }

def served -> JacTestClient {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    os.environ["ANTHROPIC_API_KEY"] = "";
    os.environ["UARRIVED_MODERATORS"] = "";
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

def desk(price: float) -> dict[str, any] {
    return {"kind": "offer", "category": "furniture", "title": "Desk", "price": price};
}

def want_desk -> dict[str, any] {
    return {
        "kind": "request",
        "category": "furniture",
        "title": "Need a desk",
        "price": 50
    };
}

test "a moderator listed after posts and reports exist can still see and hide them" {
    client = served();
    try {
        student(client, "mod@umich.edu");
        student(client, "jae@umich.edu");
        post_id = publish(client, desk(25));
        student(client, "mina@umich.edu");
        assert call(client, "report_post", {"post_id": post_id, "reason": "scam"});
        os.environ["UARRIVED_MODERATORS"] = "mod@umich.edu";
        act_as(client, "mod@umich.edu");
        q = call(client, "moderation_queue", {});
        assert len(q) == 1 and q[0]["post_title"] == "Desk";
        assert call(client, "hide_post", {"post_id": post_id});
        act_as(client, "mina@umich.edu");
        assert call(client, "list_live_posts", {}) == [];
    } finally {
        os.environ["UARRIVED_MODERATORS"] = "";
        client.close();
    }
}

test "a moderator removed from the list loses the queue" {
    client = served();
    try {
        os.environ["UARRIVED_MODERATORS"] = "mod@umich.edu";
        student(client, "mod@umich.edu");
        student(client, "jae@umich.edu");
        post_id = publish(client, desk(25));
        call(client, "report_post", {"post_id": post_id, "reason": "spam"});
        act_as(client, "mod@umich.edu");
        assert len(call(client, "moderation_queue", {})) == 1;
        os.environ["UARRIVED_MODERATORS"] = "";
        assert call(client, "moderation_queue", {}) == [];
        assert not call(client, "hide_post", {"post_id": post_id});
    } finally {
        os.environ["UARRIVED_MODERATORS"] = "";
        client.close();
    }
}

test "a suspended poster can't publish and their posts vanish for others" {
    client = served();
    try {
        os.environ["UARRIVED_MODERATORS"] = "mod@umich.edu";
        student(client, "mod@umich.edu");
        student(client, "jae@umich.edu");
        first = publish(client, desk(25));
        publish(
            client,
            {"kind": "offer", "category": "essentials", "title": "Lamp", "price": 5}
        );
        act_as(client, "mod@umich.edu");
        assert call(client, "suspend_poster", {"post_id": first});
        act_as(client, "jae@umich.edu");
        refused = call(client, "publish_post", {"fields": desk(10)});
        assert not refused["ok"] and "can't post" in refused["error"];
        student(client, "mina@umich.edu");
        assert call(client, "list_live_posts", {}) == [];
        publish(client, want_desk());
        assert call(client, "list_my_suggestions", {}) == [];
    } finally {
        os.environ["UARRIVED_MODERATORS"] = "";
        client.close();
    }
}

test "after one side connects, an edit that breaks the budget withdraws the suggestion" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        publish(client, want_desk());
        student(client, "jae@umich.edu");
        post_id = publish(client, desk(25));
        act_as(client, "mina@umich.edu");
        sid = call(client, "list_my_suggestions", {})[0]["id"];
        assert call(client, "connect", {"suggestion_id": sid})["ok"];
        act_as(client, "jae@umich.edu");
        assert call(client, "edit_post", {"post_id": post_id, "changes": {"price": 80}})[
            "ok"
        ];
        act_as(client, "mina@umich.edu");
        assert call(client, "list_my_suggestions", {}) == [];
        assert not call(client, "connect", {"suggestion_id": sid})["ok"];
    } finally {
        client.close();
    }
}

test "after one side connects, an edit that still fits refreshes the reasons" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        publish(client, want_desk());
        student(client, "jae@umich.edu");
        post_id = publish(client, desk(25));
        act_as(client, "mina@umich.edu");
        sid = call(client, "list_my_suggestions", {})[0]["id"];
        call(client, "connect", {"suggestion_id": sid});
        act_as(client, "jae@umich.edu");
        call(client, "edit_post", {"post_id": post_id, "changes": {"price": 30}});
        act_as(client, "mina@umich.edu");
        seen = call(client, "list_my_suggestions", {});
        assert len(seen) == 1 and "$30 is within the $50 budget" in seen[0]["reasons"];
        assert not any(["$25" in r for r in seen[0]["reasons"]]);
    } finally {
        client.close();
    }
}

test "asking to verify a new address keeps the student verified until they confirm it" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        started = call(client, "start_verification", {"email": "mina.new@umich.edu"});
        assert started["ok"];
        state = call(client, "my_verification", {});
        assert state["verified"] and state["email"] == "mina@umich.edu";
        assert call(client, "confirm_verification", {"token": started["dev_token"]})[
            "ok"
        ];
        assert call(client, "my_verification", {})["email"] == "mina.new@umich.edu";
    } finally {
        client.close();
    }
}

test "an SMTP failure is a clear error and doesn't lock the student out" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        os.environ["UARRIVED_DEV_MODE"] = "0";
        os.environ.pop("UARRIVED_EMAIL_OUTBOX", None);
        os.environ["SMTP_HOST"] = "127.0.0.1";
        os.environ["SMTP_PORT"] = "1";
        result = call(client, "start_verification", {"email": "mina.new@umich.edu"});
        assert not result["ok"] and "couldn't send" in result["error"];
        assert call(client, "my_verification", {})["verified"];
    } finally {
        os.environ.pop("SMTP_HOST", None);
        os.environ.pop("SMTP_PORT", None);
        os.environ["UARRIVED_DEV_MODE"] = "1";
        client.close();
    }
}

test "after a block neither student sees the other's posts anywhere" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        mina_post = publish(client, want_desk());
        student(client, "jae@umich.edu");
        jae_post = publish(client, desk(25));
        publish(
            client,
            {"kind": "offer", "category": "essentials", "title": "Lamp", "price": 5}
        );
        act_as(client, "mina@umich.edu");
        sid = call(client, "list_my_suggestions", {})[0]["id"];
        assert call(client, "block_in_suggestion", {"suggestion_id": sid});
        assert [p["title"] for p in call(client, "list_live_posts", {})]
            == ["Need a desk"];
        assert call(client, "for_you_feed", {}) == [];
        assert not call(client, "help_me_decide", {"post_ids": [jae_post, mina_post]})[
            "ok"
        ];
        act_as(client, "jae@umich.edu");
        assert "Need a desk"
            not in [p["title"] for p in call(client, "list_live_posts", {})];
    } finally {
        client.close();
    }
}

test "an unverified student can't edit, finish, renew, decline or chat" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        post_id = publish(client, desk(25));
        client.register_user("stranger@umich.edu", "password123");
        assert "Verify"
            in call(client, "edit_post", {"post_id": post_id, "changes": {"price": 1}})[
                "error"
            ];
        assert not call(client, "mark_post_done", {"post_id": post_id})["ok"];
        assert not call(client, "renew_post", {"post_id": post_id})["ok"];
        assert not call(client, "stop_suggestions", {"post_id": post_id});
        assert not call(client, "decline", {"suggestion_id": "x"});
        assert not call(client, "send_message", {"chat_id": "x", "text": "hi"})["ok"];
        assert "Verify" in call(client, "read_chat", {"chat_id": "x"})["error"];
    } finally {
        client.close();
    }
}

test "an impossible date is a validation error, not a server crash" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        result = call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "offer",
                    "category": "service",
                    "title": "Ride",
                    "available_from": "2099-02-30"
                }
            }
        );
        assert not result["ok"] and "YYYY-MM-DD" in result["error"];
    } finally {
        client.close();
    }
}
