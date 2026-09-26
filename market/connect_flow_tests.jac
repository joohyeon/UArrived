"""Served-app tests for mutual opt-in and per-post chat (U6)."""

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

def student(client: JacTestClient, email: str) {
    client.register_user(email, "password123");
    token = call(client, "start_verification", {"email": email})["dev_token"];
    assert call(client, "confirm_verification", {"token": token})["ok"];
}

def act_as(client: JacTestClient, email: str) {
    client.login(email, "password123");
}

"""Mina requests a desk, Jae offers one; returns (Jae's post id, the suggestion id). Acting as Jae."""
def matched_pair(client: JacTestClient) -> tuple[str, str] {
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
    post_id = call(
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
    suggestions = call(client, "list_my_suggestions", {});
    assert len(suggestions) == 1;
    return (post_id, suggestions[0]["id"]);
}

test "a chat opens only after both students accept, and both can talk" {
    client = served();
    try {
        (post_id, sid) = matched_pair(client);
        first = call(client, "connect", {"suggestion_id": sid});
        assert first["ok"] and not first["connected"];
        assert call(client, "list_my_chats", {}) == [];
        act_as(client, "mina@umich.edu");
        second = call(client, "connect", {"suggestion_id": sid});
        assert second["ok"] and second["connected"] and second["chat_id"];
        chat_id = second["chat_id"];
        assert call(
            client,
            "send_message",
            {"chat_id": chat_id, "text": "Hi! Is the desk still free Saturday?"}
        )["ok"];
        act_as(client, "jae@umich.edu");
        chats = call(client, "list_my_chats", {});
        assert len(chats) == 1 and chats[0]["id"] == chat_id and chats[0]["open"];
        thread = call(client, "read_chat", {"chat_id": chat_id});
        assert [m["text"] for m in thread["messages"]]
            == ["Hi! Is the desk still free Saturday?"];
        assert not thread["messages"][0]["mine"];
        assert call(
            client, "send_message", {"chat_id": chat_id, "text": "Yes, after 2pm."}
        )["ok"];
        act_as(client, "mina@umich.edu");
        thread = call(client, "read_chat", {"chat_id": chat_id});
        assert [m["mine"] for m in thread["messages"]] == [True, False];
    } finally {
        client.close();
    }
}

test "accepting twice on both sides still leaves exactly one chat" {
    client = served();
    try {
        (post_id, sid) = matched_pair(client);
        call(client, "connect", {"suggestion_id": sid});
        act_as(client, "mina@umich.edu");
        a = call(client, "connect", {"suggestion_id": sid})["chat_id"];
        b = call(client, "connect", {"suggestion_id": sid})["chat_id"];
        act_as(client, "jae@umich.edu");
        c = call(client, "connect", {"suggestion_id": sid})["chat_id"];
        assert a == b == c;
        assert len(call(client, "list_my_chats", {})) == 1;
    } finally {
        client.close();
    }
}

test "declining hides the pairing from both, with no chat and no notice (AE3)" {
    client = served();
    try {
        (post_id, sid) = matched_pair(client);
        call(client, "connect", {"suggestion_id": sid});
        act_as(client, "mina@umich.edu");
        assert call(client, "decline", {"suggestion_id": sid});
        assert call(client, "list_my_suggestions", {}) == [];
        assert not call(client, "connect", {"suggestion_id": sid})["ok"];
        act_as(client, "jae@umich.edu");
        assert call(client, "list_my_suggestions", {}) == [];
        assert call(client, "list_my_chats", {}) == [];
    } finally {
        client.close();
    }
}

test "a third student cannot read or post to the chat, even with its id" {
    client = served();
    try {
        (post_id, sid) = matched_pair(client);
        call(client, "connect", {"suggestion_id": sid});
        act_as(client, "mina@umich.edu");
        chat_id = call(client, "connect", {"suggestion_id": sid})["chat_id"];
        call(client, "send_message", {"chat_id": chat_id, "text": "private"});
        student(client, "kai@umich.edu");
        assert not call(client, "read_chat", {"chat_id": chat_id})["ok"];
        assert not call(client, "send_message", {"chat_id": chat_id, "text": "hi"})[
            "ok"
        ];
        assert not call(client, "connect", {"suggestion_id": sid})["ok"];
        assert not call(client, "decline", {"suggestion_id": sid});
        assert call(client, "list_my_chats", {}) == [];
    } finally {
        client.close();
    }
}

test "marking the post done closes the chat: readable, but no new messages (AE5)" {
    client = served();
    try {
        (post_id, sid) = matched_pair(client);
        call(client, "connect", {"suggestion_id": sid});
        act_as(client, "mina@umich.edu");
        chat_id = call(client, "connect", {"suggestion_id": sid})["chat_id"];
        call(client, "send_message", {"chat_id": chat_id, "text": "See you at 2"});
        act_as(client, "jae@umich.edu");
        call(client, "mark_post_done", {"post_id": post_id});
        act_as(client, "mina@umich.edu");
        chats = call(client, "list_my_chats", {});
        assert len(chats) == 1 and not chats[0]["open"];
        assert len(call(client, "read_chat", {"chat_id": chat_id})["messages"]) == 1;
        refused = call(
            client, "send_message", {"chat_id": chat_id, "text": "still there?"}
        );
        assert not refused["ok"] and "closed" in refused["error"];
    } finally {
        client.close();
    }
}

test "a chat closes when its post expires, with nothing written to the chat" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        ride: dict[str, any] = {
            "kind": "request",
            "category": "service",
            "title": "Ride",
            "route_from": "DTW",
            "route_to": "Ann Arbor",
            "available_from": "2099-08-20"
        };
        call(client, "publish_post", {"fields": ride});
        student(client, "jae@umich.edu");
        post_id = call(client, "publish_post", {"fields": ride})["post"]["id"];
        sid = call(client, "list_my_suggestions", {})[0]["id"];
        call(client, "connect", {"suggestion_id": sid});
        act_as(client, "mina@umich.edu");
        chat_id = call(client, "connect", {"suggestion_id": sid})["chat_id"];
        act_as(client, "jae@umich.edu");
        yesterday = (date.today() - timedelta(days=1)).isoformat();
        assert call(
            client,
            "edit_post",
            {"post_id": post_id, "changes": {"available_from": yesterday}}
        )["ok"];
        act_as(client, "mina@umich.edu");
        assert not call(client, "send_message", {"chat_id": chat_id, "text": "?"})[
            "ok"
        ];
    } finally {
        client.close();
    }
}

test "empty and overlong messages are refused" {
    client = served();
    try {
        (post_id, sid) = matched_pair(client);
        call(client, "connect", {"suggestion_id": sid});
        act_as(client, "mina@umich.edu");
        chat_id = call(client, "connect", {"suggestion_id": sid})["chat_id"];
        assert not call(client, "send_message", {"chat_id": chat_id, "text": "   "})[
            "ok"
        ];
        assert not call(
            client, "send_message", {"chat_id": chat_id, "text": "x" * 2001}
        )["ok"];
    } finally {
        client.close();
    }
}
