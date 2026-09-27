"""Served-app tests for reports, blocks and moderation (U11). The moderator verifies first, so
posts published afterwards are shared with them."""

import os;
import tempfile;
import from jaclang.testing.testing { JacTestClient }

def served -> JacTestClient {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    os.environ["ANTHROPIC_API_KEY"] = "";
    os.environ["UARRIVED_MODERATORS"] = "mod@umich.edu";
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

obj Setup {
    has offer_id: str,
        suggestion_id: str,
        chat_id: str;
}

"""Moderator, then Mina (desk request) and Jae (desk offer) connected in a chat. Acting as Mina."""
def connected(client: JacTestClient) -> Setup {
    student(client, "mod@umich.edu");
    student(client, "mina@umich.edu");
    call(
        client,
        "publish_post",
        {
            "fields": {
                "kind": "request",
                "category": "furniture",
                "title": "Need a desk",
                "price": 50
            }
        }
    );
    student(client, "jae@umich.edu");
    offer_id = call(
        client,
        "publish_post",
        {
            "fields": {
                "kind": "offer",
                "category": "furniture",
                "title": "Desk",
                "price": 25
            }
        }
    )["post"]["id"];
    sid = call(client, "list_my_suggestions", {})[0]["id"];
    call(client, "connect", {"suggestion_id": sid});
    act_as(client, "mina@umich.edu");
    chat_id = call(client, "connect", {"suggestion_id": sid})["chat_id"];
    return Setup(offer_id=offer_id, suggestion_id=sid, chat_id=chat_id);
}

test "a report from a chat reaches moderators and no one else" {
    client = served();
    try {
        s = connected(client);
        assert call(
            client,
            "report_chat",
            {"chat_id": s.chat_id, "reason": "Asked me to pay by gift card"}
        );
        assert call(client, "moderation_queue", {}) == [];
        act_as(client, "jae@umich.edu");
        assert call(client, "moderation_queue", {}) == [];
        act_as(client, "mod@umich.edu");
        q = call(client, "moderation_queue", {});
        assert len(q) == 1
            and q[0]["post_title"] == "Desk"
            and q[0]["chat_id"] == s.chat_id;
        assert q[0]["reason"] == "Asked me to pay by gift card";
    } finally {
        client.close();
    }
}

test "a moderator's hide removes the post from feeds and future matches" {
    client = served();
    try {
        s = connected(client);
        call(
            client,
            "report_post",
            {"post_id": s.offer_id, "reason": "Looks like a scam"}
        );
        act_as(client, "mod@umich.edu");
        rid = call(client, "moderation_queue", {})[0]["id"];
        assert call(client, "hide_post", {"post_id": s.offer_id});
        assert call(client, "resolve_report", {"report_id": rid});
        assert call(client, "moderation_queue", {}) == [];
        student(client, "kai@umich.edu");
        assert [p["title"] for p in call(client, "list_live_posts", {})]
            == ["Need a desk"];
        call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "request",
                    "category": "furniture",
                    "title": "Kai needs a desk",
                    "price": 40
                }
            }
        );
        assert call(client, "list_my_suggestions", {}) == [];
        act_as(client, "jae@umich.edu");
        assert call(client, "list_my_posts", {})[0]["status"] == "hidden";
        act_as(client, "mina@umich.edu");
        chats = call(client, "list_my_chats", {});
        assert len(chats) == 1 and not chats[0]["open"];
    } finally {
        client.close();
    }
}

test "only moderators can hide posts or resolve reports" {
    client = served();
    try {
        s = connected(client);
        call(client, "report_post", {"post_id": s.offer_id, "reason": "spam"});
        assert not call(client, "hide_post", {"post_id": s.offer_id});
        act_as(client, "mod@umich.edu");
        rid = call(client, "moderation_queue", {})[0]["id"];
        act_as(client, "mina@umich.edu");
        assert not call(client, "resolve_report", {"report_id": rid});
        assert "Desk" in [p["title"] for p in call(client, "list_live_posts", {})];
    } finally {
        client.close();
    }
}

test "blocking from a chat removes it for both and stops future matches, silently" {
    client = served();
    try {
        s = connected(client);
        assert call(client, "block_in_chat", {"chat_id": s.chat_id});
        assert call(client, "list_my_chats", {}) == [];
        assert call(client, "list_my_suggestions", {}) == [];
        assert not call(client, "send_message", {"chat_id": s.chat_id, "text": "hi"})[
            "ok"
        ];
        act_as(client, "jae@umich.edu");
        assert call(client, "list_my_chats", {}) == [];
        call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "offer",
                    "category": "furniture",
                    "title": "Another desk",
                    "price": 20
                }
            }
        );
        assert call(client, "list_my_suggestions", {}) == [];
    } finally {
        client.close();
    }
}

test "a report needs a reason and a real post; strangers can't report or block a chat" {
    client = served();
    try {
        s = connected(client);
        assert not call(
            client, "report_post", {"post_id": s.offer_id, "reason": "   "}
        );
        assert not call(
            client, "report_post", {"post_id": "not-a-post", "reason": "bad"}
        );
        student(client, "kai@umich.edu");
        assert not call(client, "report_chat", {"chat_id": s.chat_id, "reason": "x"});
        assert not call(client, "block_in_chat", {"chat_id": s.chat_id});
    } finally {
        client.close();
    }
}
