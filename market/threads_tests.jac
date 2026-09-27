"""Served tests for clarification, owner matches and private match threads (plan 2026-09-27-003).
AI is MockLLM. The first test is the end-to-end example from the brief."""

import ai.draft;
import from jaclang.byllm.lib { MockLLM }
import from jaclang.testing.testing { JacTestClient }
import from market.testkit { served }
import from ai.draft { PostDraft, DraftSet, PostKind, Category }
import from market.threads { ThreadView }
import from market.themes { GroupView }

def call(client: JacTestClient, name: str, body: dict[str, any]) -> any {
    return client.post(f"/function/{name}", json=body).json()["data"]["result"];
}

def student(client: JacTestClient, email: str) {
    client.register_user(email, "password123");
    name = email.split("@")[0].capitalize();
    assert call(client, "claim_umich_account", {"email": email, "display_name": name})[
        "ok"
    ];
}

def act_as(client: JacTestClient, email: str) {
    client.login(email, "password123");
}

def ai_says(drafts: list[any]) {
    ai.draft.drafter = MockLLM(
        outputs=[
            DraftSet(language="en", drafts=[d]) if isinstance(d, PostDraft) else d
            for d in drafts
        ]
    );
}

def joined(client: JacTestClient, key: str) -> str {
    g = {x["key"]: x["id"] for x in call(client, "list_groups_for_me", {})}[key];
    assert call(client, "join_group", {"group_id": g})["ok"];
    return g;
}

def say(client: JacTestClient, group_id: str, text: str) -> dict[str, any] {
    return call(client, "post_in_group", {"group_id": group_id, "text": text});
}

"""The caller's view of the first tag on the message with this id."""
def tag(client: JacTestClient, group_id: str, message_id: str) -> dict[str, any] {
    for m in call(client, "group_view", {"group_id": group_id})["messages"] {
        if m["id"] == message_id {
            return m["tags"][0];
        }
    }
    return {};
}

def thread(client: JacTestClient, chat_id: str) -> dict[str, any] {
    return call(client, "get_thread", {"chat_id": chat_id});
}

def bike_offer(guessed: list[str] = []) -> PostDraft {
    return PostDraft(
        kind=PostKind.OFFER,
        category=Category.VEHICLE,
        title="Bike",
        description="Selling my bike.",
        price=80.0,
        item="bike",
        available_until="2099-10-30",
        guessed=guessed
    );
}

def bike_request -> PostDraft {
    return PostDraft(
        kind=PostKind.REQUEST,
        category=Category.VEHICLE,
        title="Used bike",
        description="Looking for a bike.",
        price=100.0,
        item="bike"
    );
}

test "end to end: message, clarification, match, private thread, reserved, completed" {
    client = served();
    try {
        # 1. Lee drops a sell message; the model guessed the end date.
        student(client, "lee@umich.edu");
        moveout = joined(client, "moveout");
        ai_says([bike_offer(["available_until"])]);
        lee_msg = say(
            client, moveout, "Selling my bike for $80, moving out end of October"
        )["message_id"];
        mine = tag(client, moveout, lee_msg);
        assert mine["label"] == "Selling" and mine["confirmed"] == "$80";
        assert mine["guesses"] == "until Oct 30";
        assert mine["owner_state"].startswith("Finding matches");
        # 2. The assistant asks only Lee the focused questions; Lee answers with taps.
        fields = [q["field"] for q in mine["questions"]];
        assert fields == ["condition", "area", "timing"];
        for (field, value) in [
            ("condition", "good"),
            ("area", "Kerrytown"),
            ("timing", "confirm"),
            ("pickup", "pickup only")
        ] {
            assert call(
                client,
                "answer_detail",
                {"post_id": mine["post_id"], "field": field, "value": value}
            )["ok"];
        }
        mine = tag(client, moveout, lee_msg);
        assert mine["guesses"] == "" and mine["questions"] == [];
        assert "good" in mine["confirmed"] and "pickup only" in mine["confirmed"];
        # 3. Rin asks for a bike in another group and sees Lee's bike as a match, with reasons.
        student(client, "rin@umich.edu");
        bikes = joined(client, "vehicles");
        ai_says([bike_request()]);
        rin_msg = say(client, bikes, "Looking for a used bike under $100")[
            "message_id"
        ];
        rin_tag = tag(client, bikes, rin_msg);
        assert rin_tag["owner_state"] == "Match found (1)";
        card = rin_tag["matches"][0];
        assert card["title"] == "Bike" and card["poster"] == "Lee";
        assert "$80 is within the $100 budget" in card["reasons"];
        assert card["unknown"] == [];
        # 4. "I'm interested" opens a private thread linked to Lee's message.
        started = call(
            client,
            "start_thread",
            {
                "post_id": card["post_id"],
                "via_post_id": rin_tag["post_id"],
                "group_id": moveout,
                "message_id": lee_msg
            }
        );
        assert started["ok"];
        chat = started["chat_id"];
        t = thread(client, chat);
        assert t["privacy"] == "Private · only you and Lee can see this thread";
        assert t["group_name"] == "Move-out sales"
            and t["origin_text"].startswith("Selling my bike");
        assert t["state"] == "new" and t["messages"] == [];
        assert t["offer"]["confirmed"]
            == "$80 · Oct 30 · Kerrytown · good · pickup only"
            or "$80" in t["offer"]["confirmed"];
        assert "$80 is within the $100 budget" in t["fits"];
        assert "Hi! Is the bike still available?" in t["suggestions"];
        assert "withdraw" in t["actions"] and "reserve" not in t["actions"];
        # 5. Rin sends; Lee sees the thread and it's Lee's turn.
        assert call(
            client, "thread_send", {"chat_id": chat, "text": "Is it still available?"}
        )["ok"];
        assert thread(client, chat)["state"] == "awaiting";
        act_as(client, "lee@umich.edu");
        lt = thread(client, chat);
        assert lt["state"] == "your_turn" and lt["my_role"] == "seller";
        assert lt["actions"][:2] == ["reserve", "sell"];
        assert tag(client, moveout, lee_msg)["owner_state"] == "1 interested";
        # 6. Lee reserves it for Rin; everyone else sees only "Reserved".
        assert call(client, "thread_action", {"chat_id": chat, "action": "reserve"})[
            "ok"
        ];
        assert thread(client, chat)["state_label"] == "Reserved for Rin";
        act_as(client, "rin@umich.edu");
        assert thread(client, chat)["state_label"] == "Reserved for you";
        # 7. Lee marks it sold to Rin: the thread completes and the public tag says Sold.
        act_as(client, "lee@umich.edu");
        assert call(client, "thread_action", {"chat_id": chat, "action": "sell"})["ok"];
        assert thread(client, chat)["state"] == "completed";
        assert tag(client, moveout, lee_msg)["owner_state"] == "Completed";
        act_as(client, "rin@umich.edu");
        assert thread(client, chat)["state_label"] == "Completed · you got it";
        assert call(
            client, "thread_send", {"chat_id": chat, "text": "See you Saturday!"}
        )["ok"];
        student(client, "kai@umich.edu");
        public = tag(client, moveout, lee_msg);
        assert public["status_label"] == "Sold" and public["threads"] == [];
    } finally {
        client.close();
    }
}

test "threads are private to their two students, even with the id" {
    client = served();
    try {
        student(client, "lee@umich.edu");
        moveout = joined(client, "moveout");
        ai_says([bike_offer()]);
        lee_msg = say(client, moveout, "Selling my bike for $80")["message_id"];
        post_id = tag(client, moveout, lee_msg)["post_id"];
        student(client, "rin@umich.edu");
        rin_chat = call(
            client,
            "start_thread",
            {
                "post_id": post_id,
                "via_post_id": "",
                "group_id": moveout,
                "message_id": lee_msg
            }
        )["chat_id"];
        call(client, "thread_send", {"chat_id": rin_chat, "text": "I'd love it"});
        student(client, "kai@umich.edu");
        kai_chat = call(
            client,
            "start_thread",
            {
                "post_id": post_id,
                "via_post_id": "",
                "group_id": moveout,
                "message_id": lee_msg
            }
        )["chat_id"];
        assert kai_chat != rin_chat;
        assert not thread(client, rin_chat)["ok"];
        assert not call(client, "thread_send", {"chat_id": rin_chat, "text": "hi"})[
            "ok"
        ];
        assert not call(
            client, "thread_action", {"chat_id": rin_chat, "action": "sell"}
        )["ok"];
        assert [t["id"] for t in call(client, "list_threads", {})] == [kai_chat];
        student(client, "mina@umich.edu");
        assert not thread(client, rin_chat)["ok"];
        assert call(client, "list_threads", {}) == [];
        public = tag(client, moveout, lee_msg);
        assert public["threads"] == []
            and public["matches"] == []
            and public["questions"] == [];
        assert public["owner_state"] == "";
    } finally {
        client.close();
    }
}

test "several interested buyers: reserving and selling tell the others without naming anyone" {
    client = served();
    try {
        student(client, "lee@umich.edu");
        moveout = joined(client, "moveout");
        ai_says([bike_offer()]);
        lee_msg = say(client, moveout, "Selling my bike for $80")["message_id"];
        post_id = tag(client, moveout, lee_msg)["post_id"];
        chats: dict[str, str] = {};
        for name in ["rin", "kai"] {
            student(client, f"{name}@umich.edu");
            chats[name] = call(
                client,
                "start_thread",
                {
                    "post_id": post_id,
                    "via_post_id": "",
                    "group_id": moveout,
                    "message_id": lee_msg
                }
            )["chat_id"];
        }
        act_as(client, "lee@umich.edu");
        assert tag(client, moveout, lee_msg)["owner_state"] == "2 interested";
        assert call(
            client, "thread_action", {"chat_id": chats["rin"], "action": "reserve"}
        )["ok"];
        assert "reserve" not in thread(client, chats["kai"])["actions"];
        refused = call(
            client, "thread_action", {"chat_id": chats["kai"], "action": "reserve"}
        );
        assert not refused["ok"];
        act_as(client, "kai@umich.edu");
        assert thread(client, chats["kai"])["state_label"]
            == "Reserved for another student";
        assert not call(
            client, "thread_action", {"chat_id": chats["kai"], "action": "sell"}
        )["ok"];
        act_as(client, "lee@umich.edu");
        call(client, "thread_action", {"chat_id": chats["rin"], "action": "sell"});
        act_as(client, "kai@umich.edu");
        kt = thread(client, chats["kai"]);
        assert kt["state_label"] == "Sold to another student" and not kt["can_send"];
        assert not call(
            client, "thread_send", {"chat_id": chats["kai"], "text": "still?"}
        )["ok"];
    } finally {
        client.close();
    }
}

test "withdrawing interest closes the thread and releases a reservation" {
    client = served();
    try {
        student(client, "lee@umich.edu");
        moveout = joined(client, "moveout");
        ai_says([bike_offer()]);
        lee_msg = say(client, moveout, "Selling my bike for $80")["message_id"];
        post_id = tag(client, moveout, lee_msg)["post_id"];
        student(client, "rin@umich.edu");
        chat = call(
            client,
            "start_thread",
            {
                "post_id": post_id,
                "via_post_id": "",
                "group_id": moveout,
                "message_id": lee_msg
            }
        )["chat_id"];
        act_as(client, "lee@umich.edu");
        call(client, "thread_action", {"chat_id": chat, "action": "reserve"});
        act_as(client, "rin@umich.edu");
        assert call(client, "thread_action", {"chat_id": chat, "action": "withdraw"})[
            "ok"
        ];
        act_as(client, "lee@umich.edu");
        assert tag(client, moveout, lee_msg)["status_label"] == "Available";
    } finally {
        client.close();
    }
}

test "starting a thread twice reopens it, and your own post or a sold one is refused" {
    client = served();
    try {
        student(client, "lee@umich.edu");
        moveout = joined(client, "moveout");
        ai_says([bike_offer()]);
        lee_msg = say(client, moveout, "Selling my bike for $80")["message_id"];
        post_id = tag(client, moveout, lee_msg)["post_id"];
        body = {
            "post_id": post_id,
            "via_post_id": "",
            "group_id": moveout,
            "message_id": lee_msg
        };
        assert not call(client, "start_thread", body)["ok"];
        student(client, "rin@umich.edu");
        first = call(client, "start_thread", body)["chat_id"];
        assert call(client, "start_thread", body)["chat_id"] == first;
        act_as(client, "lee@umich.edu");
        call(client, "close_group_post", {"post_id": post_id, "reason": "sold"});
        student(client, "kai@umich.edu");
        assert not call(client, "start_thread", body)["ok"];
    } finally {
        client.close();
    }
}

test "only the owner can answer questions about a post" {
    client = served();
    try {
        student(client, "lee@umich.edu");
        moveout = joined(client, "moveout");
        ai_says([bike_offer()]);
        lee_msg = say(client, moveout, "Selling my bike for $80")["message_id"];
        post_id = tag(client, moveout, lee_msg)["post_id"];
        student(client, "rin@umich.edu");
        assert not call(
            client,
            "answer_detail",
            {"post_id": post_id, "field": "condition", "value": "new"}
        )["ok"];
        act_as(client, "lee@umich.edu");
        bad = call(
            client,
            "answer_detail",
            {"post_id": post_id, "field": "condition", "value": "broken"}
        );
        assert not bad["ok"];
    } finally {
        client.close();
    }
}

test "a listing the assistant can't read says so instead of failing silently" {
    client = served();
    try {
        student(client, "lee@umich.edu");
        moveout = joined(client, "moveout");
        ai_says([DraftSet(language="en", drafts=[])]);
        sent = say(client, moveout, "Selling my bike for $80");
        assert not sent["filed"]
            and "couldn't read that as a listing" in sent["notice"];
        ai_says([DraftSet(language="en", drafts=[])]);
        chat = say(client, moveout, "hello everyone");
        assert chat["notice"] == "";
    } finally {
        client.close();
    }
}
