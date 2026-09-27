"""Served-app tests for the post lifecycle (U4): two verified students on one server."""

import os;
import tempfile;
import from datetime { date, timedelta }
import from jaclang.testing.testing { JacTestClient }

def served -> JacTestClient {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    return JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
}

def call(client: JacTestClient, name: str, body: dict[str, any]) -> any {
    return client.post(f"/function/{name}", json=body).json()["data"]["result"];
}

"""Register and verify `email`; the client is then acting as that student."""
def student(client: JacTestClient, email: str) {
    client.register_user(email, "password123");
    token = call(client, "start_verification", {"email": email})["dev_token"];
    assert call(client, "confirm_verification", {"token": token})["ok"];
}

def desk -> dict[str, any] {
    return {
        "kind": "offer",
        "category": "furniture",
        "title": "Solid wood desk",
        "price": 25,
        "area": "Central Campus"
    };
}

test "a published post is visible to another verified student" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        result = call(client, "publish_post", {"fields": desk()});
        assert result["ok"]
            and result["post"]["mine"]
            and result["post"]["status"] == "live";
        student(client, "mina@umich.edu");
        seen = call(client, "list_live_posts", {});
        assert [p["title"] for p in seen] == ["Solid wood desk"];
        assert not seen[0]["mine"];
        assert call(client, "list_my_posts", {}) == [];
    } finally {
        client.close();
    }
}

test "an unverified student can neither publish nor browse" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        result = call(client, "publish_post", {"fields": desk()});
        assert not result["ok"] and "Verify" in result["error"];
        assert call(client, "list_live_posts", {}) == [];
    } finally {
        client.close();
    }
}

test "another student cannot edit, finish or renew your post" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        post_id = call(client, "publish_post", {"fields": desk()})["post"]["id"];
        student(client, "mina@umich.edu");
        assert not call(
            client, "edit_post", {"post_id": post_id, "changes": {"price": 1}}
        )["ok"];
        assert not call(client, "mark_post_done", {"post_id": post_id})["ok"];
        assert not call(client, "renew_post", {"post_id": post_id})["ok"];
        seen = call(client, "list_live_posts", {});
        assert seen[0]["price"] == 25.0 and seen[0]["status"] == "live";
    } finally {
        client.close();
    }
}

test "marking a post done removes it from everyone's live list (AE5, post part)" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        post_id = call(client, "publish_post", {"fields": desk()})["post"]["id"];
        assert call(client, "mark_post_done", {"post_id": post_id})["post"]["status"]
            == "done";
        assert call(client, "list_my_posts", {})[0]["status"] == "done";
        student(client, "mina@umich.edu");
        assert call(client, "list_live_posts", {}) == [];
    } finally {
        client.close();
    }
}

test "a ride whose day has passed is expired on read, and renewing brings it back" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        tomorrow = (date.today() + timedelta(days=1)).isoformat();
        ride: dict[str, any] = {
            "kind": "offer",
            "category": "service",
            "title": "Ride from DTW",
            "available_from": tomorrow
        };
        post_id = call(client, "publish_post", {"fields": ride})["post"]["id"];
        assert len(call(client, "list_live_posts", {})) == 1;
        os.environ["UARRIVED_TODAY"] = (date.today() + timedelta(days=3)).isoformat();
        assert call(client, "list_live_posts", {}) == [];
        assert call(client, "list_my_posts", {})[0]["status"] == "expired";
        renewed = call(client, "renew_post", {"post_id": post_id});
        assert renewed["ok"] and renewed["post"]["status"] == "live";
        assert len(call(client, "list_live_posts", {})) == 1;
    } finally {
        os.environ["UARRIVED_TODAY"] = "";
        client.close();
    }
}

test "a post whose date has already passed is refused, not published expired" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        yesterday = (date.today() - timedelta(days=1)).isoformat();
        result = call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "offer",
                    "category": "service",
                    "title": "Ride",
                    "available_from": yesterday
                }
            }
        );
        assert not result["ok"] and "already passed" in result["error"];
        assert call(client, "list_my_posts", {}) == [];
    } finally {
        client.close();
    }
}

test "the owner's edit is re-validated and marks the text as no longer AI-written" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        post_id = call(client, "publish_post", {"fields": desk()})["post"]["id"];
        bad = call(client, "edit_post", {"post_id": post_id, "changes": {"price": -3}});
        assert not bad["ok"];
        good = call(
            client, "edit_post", {"post_id": post_id, "changes": {"price": 20}}
        );
        assert good["ok"]
            and good["post"]["price"] == 20.0
            and not good["post"]["ai_generated"];
    } finally {
        client.close();
    }
}

test "a client cannot set the owner, expiry or done flag when publishing" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        fields = desk();
        fields["owner_root"] = "someone-else";
        fields["expires_on"] = "2099-01-01";
        fields["done"] = True;
        result = call(client, "publish_post", {"fields": fields});
        assert result["ok"] and result["post"]["mine"];
        assert result["post"]["status"] == "live"
            and result["post"]["expires_on"] != "2099-01-01";
    } finally {
        client.close();
    }
}
