"""Served-app tests for mutual opt-in and per-post chat (U6), and chat translation per reader
(native-language U7). No test calls a real model: AI is off (market/testkit.jac), so post
translations keep the original, unless a test installs MockLLM replies."""

import os;
import ai.translate;
import from datetime { date, timedelta }
import from jaclang.byllm.lib { MockLLM, MockError, AuthenticationError }
import from jaclang.testing.testing { JacTestClient }
import from market.testkit { served }
import from ai.translate { Translation }
import from market.connect { message_view, translation_for }
import from market.graph { Message }

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
        os.environ["UARRIVED_TODAY"] = "2099-08-22";
        assert not call(client, "send_message", {"chat_id": chat_id, "text": "?"})[
            "ok"
        ];
        chats = call(client, "list_my_chats", {});
        assert len(chats) == 1 and not chats[0]["open"];
    } finally {
        os.environ["UARRIVED_TODAY"] = "";
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

"""Make the next chat translations return `outputs`, in order."""
def mock_translator(outputs: list[any]) -> MockLLM {
    fake = MockLLM(outputs=outputs);
    ai.translate.translator = fake;
    return fake;
}

def set_language(client: JacTestClient, lang: str) {
    assert call(client, "update_my_profile", {"changes": {"preferred_language": lang}})[
        "ok"
    ];
}

"""Jae (`jae_lang`) and Mina (`mina_lang`) both connect, each with their language set first;
returns the chat id, acting as Mina."""
def chat_in(client: JacTestClient, jae_lang: str, mina_lang: str) -> str {
    (post_id, sid) = matched_pair(client);
    set_language(client, jae_lang);
    call(client, "connect", {"suggestion_id": sid});
    act_as(client, "mina@umich.edu");
    set_language(client, mina_lang);
    return call(client, "connect", {"suggestion_id": sid})["chat_id"];
}

glob VIDEO_CALL: str = "Can you do a video call Thursday 7pm EST?";

test "the reader sees the translation with the original; the sender sees their words (AE10)" {
    client = served();
    try {
        chat_id = chat_in(client, "ko", "en");
        fake = mock_translator([Translation(text="목요일 저녁 7시 EST에 영상 통화 가능할까요?")]);
        assert call(client, "send_message", {"chat_id": chat_id, "text": VIDEO_CALL})[
            "ok"
        ];
        assert len(fake.sent("messages")) == 1;
        mine = call(client, "read_chat", {"chat_id": chat_id})["messages"][0];
        assert mine["mine"] and mine["text"] == VIDEO_CALL;
        assert not mine["ai_translated"] and mine["original"] == "";
        assert mine["language"] == "en";
        act_as(client, "jae@umich.edu");
        thread = call(client, "read_chat", {"chat_id": chat_id});
        seen = thread["messages"][0];
        assert not seen["mine"] and seen["ai_translated"];
        assert seen["text"] == "목요일 저녁 7시 EST에 영상 통화 가능할까요?";
        assert seen["original"] == VIDEO_CALL and seen["language"] == "ko";
        assert thread["chat"]["last_message"] == seen["text"];
        assert call(client, "list_my_chats", {})[0]["last_message"] == seen["text"];
        act_as(client, "mina@umich.edu");
        assert call(client, "list_my_chats", {})[0]["last_message"] == VIDEO_CALL;
    } finally {
        client.close();
    }
}

test "two English students chat with no model call" {
    client = served();
    try {
        chat_id = chat_in(client, "en", "en");
        fake = mock_translator([Translation(text="should not be used")]);
        assert call(client, "send_message", {"chat_id": chat_id, "text": VIDEO_CALL})[
            "ok"
        ];
        act_as(client, "jae@umich.edu");
        seen = call(client, "read_chat", {"chat_id": chat_id})["messages"][0];
        assert seen["text"] == VIDEO_CALL and not seen["ai_translated"];
        assert len(fake.sent("messages")) == 0;
    } finally {
        client.close();
    }
}

test "a translation that drops a number is not stored; the reader sees the original" {
    client = served();
    try {
        chat_id = chat_in(client, "ko", "en");
        mock_translator([Translation(text="목요일 저녁에 영상 통화 가능할까요?")]);
        assert call(client, "send_message", {"chat_id": chat_id, "text": VIDEO_CALL})[
            "ok"
        ];
        act_as(client, "jae@umich.edu");
        seen = call(client, "read_chat", {"chat_id": chat_id})["messages"][0];
        assert seen["text"] == VIDEO_CALL and not seen["ai_translated"];
        assert seen["original"] == "" and seen["language"] == "en";
    } finally {
        client.close();
    }
}

test "a translator outage still sends; the reader sees the original" {
    client = served();
    try {
        chat_id = chat_in(client, "ko", "en");
        mock_translator([MockError(error=AuthenticationError("no API key"))]);
        assert call(client, "send_message", {"chat_id": chat_id, "text": VIDEO_CALL})[
            "ok"
        ];
        act_as(client, "jae@umich.edu");
        seen = call(client, "read_chat", {"chat_id": chat_id})["messages"][0];
        assert seen["text"] == VIDEO_CALL and not seen["ai_translated"];
    } finally {
        client.close();
    }
}

test "a language changed after connecting: messages use the languages recorded at connect" {
    client = served();
    try {
        chat_id = chat_in(client, "ko", "en");
        act_as(client, "jae@umich.edu");
        set_language(client, "zh");
        act_as(client, "mina@umich.edu");
        set_language(client, "ko");
        fake = mock_translator([Translation(text="목요일 저녁 7시 EST에 영상 통화 가능할까요?")]);
        call(client, "send_message", {"chat_id": chat_id, "text": VIDEO_CALL});
        assert len(fake.sent("messages")) == 1;
        act_as(client, "jae@umich.edu");
        seen = call(client, "read_chat", {"chat_id": chat_id})["messages"][0];
        assert seen["language"] == "ko" and seen["ai_translated"];
        assert seen["original"] == VIDEO_CALL;
    } finally {
        client.close();
    }
}

test "a chat connected before translation (no recorded language) makes no model call" {
    fake = mock_translator([Translation(text="should not be used")]);
    assert translation_for(VIDEO_CALL, "en", "") is None;
    assert translation_for(VIDEO_CALL, "", "") is None;
    assert len(fake.sent("messages")) == 0;
    old = Message(
        author_root="someone", text=VIDEO_CALL, sent_at="2026-08-01T10:00:00"
    );
    for me in ["someone", "reader"] {
        view = message_view(old, me);
        assert view.text == VIDEO_CALL and not view.ai_translated;
        assert view.original == "" and view.mine == (me == "someone");
    }
}

test "a stored translation is shown only to the reader" {
    m = Message(
        author_root="priya",
        text=VIDEO_CALL,
        sent_at="2026-08-01T10:00:00",
        language="en",
        translated_text="목요일 저녁 7시 EST에 영상 통화 가능할까요?",
        translated_language="ko"
    );
    assert message_view(m, "priya").text == VIDEO_CALL;
    view = message_view(m, "jiwoo");
    assert view.text.startswith("목요일") and view.original == VIDEO_CALL;
}
