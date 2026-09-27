"""Served scenario tests for themed group chats (plan 2026-09-27-002). AI is MockLLM."""

import os;
import json;
import tempfile;
import ai.draft;
import from jaclang.byllm.lib { MockLLM, MockError, AuthenticationError }
import from jaclang.testing.testing { JacTestClient }
import from market.testkit { served }
import from ai.draft { PostDraft, DraftSet, PostKind, Category }
import from market.themes { GroupView }

def call(client: JacTestClient, name: str, body: dict[str, any]) -> any {
    return client.post(f"/function/{name}", json=body).json()["data"]["result"];
}

"""Sign up with a @umich.edu address (#53) and set a display name and profile answers."""
def student(client: JacTestClient, email: str, changes: dict[str, any] = {}) {
    client.register_user(email, "password123");
    name = email.split("@")[0].capitalize();
    assert call(client, "claim_umich_account", {"email": email, "display_name": name})[
        "ok"
    ];
    if changes {
        call(client, "update_my_profile", {"changes": changes});
    }
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

def groups(client: JacTestClient) -> dict[str, dict[str, any]] {
    return {g["key"]: g for g in call(client, "list_groups_for_me", {})};
}

def gid(client: JacTestClient, key: str) -> str {
    return groups(client)[key]["id"];
}

def joined(client: JacTestClient, key: str) -> str {
    g = gid(client, key);
    assert call(client, "join_group", {"group_id": g})["ok"];
    return g;
}

def say(client: JacTestClient, group_id: str, text: str) -> dict[str, any] {
    return call(client, "post_in_group", {"group_id": group_id, "text": text});
}

def messages(client: JacTestClient, group_id: str) -> list[dict[str, any]] {
    return call(client, "group_view", {"group_id": group_id})["messages"];
}

def chat -> PostDraft {
    return PostDraft(
        about_market=False,
        kind=PostKind.REQUEST,
        category=Category.ESSENTIALS,
        title="Hi",
        description="hi",
        guessed=["kind", "category"]
    );
}

def draft(
    title: str,
    kind: any,
    category: any,
    item: str,
    price: float | None = None,
    area: str = ""
) -> PostDraft {
    return PostDraft(
        kind=kind,
        category=category,
        title=title,
        description=f"{title}.",
        price=price,
        area=area,
        item=item
    );
}

def sell_desk -> PostDraft {
    return draft("IKEA desk", PostKind.OFFER, Category.FURNITURE, "desk", 30.0);
}

def want_desk -> PostDraft {
    return draft("Desk", PostKind.REQUEST, Category.FURNITURE, "desk", 40.0);
}

test "every student sees the eight themes, with suggestions from their profile" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        all = call(client, "list_groups_for_me", {});
        assert [g["key"] for g in all]
            == [
                "furniture",
                "electronics",
                "textbooks",
                "kitchen",
                "vehicles",
                "housing",
                "moveout",
                "rides"
            ];
        assert [
            g["key"]
            for g in all
            if g["suggested"]
        ]
            == ["furniture", "moveout"];
        assert not any([g["member"] for g in all]);
        student(
            client,
            "kai@umich.edu",
            {"housing_status": "looking", "needs_airport_ride": True}
        );
        assert sorted(
            [
                k
                for (k, g) in groups(client).items()
                if g["suggested"]
            ]
        )
            == ["housing", "moveout", "rides"];
    } finally {
        client.close();
    }
}

test "joining puts a group first; leaving puts it back" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        g = joined(client, "textbooks");
        first = call(client, "list_groups_for_me", {})[0];
        assert first["key"] == "textbooks"
            and first["member"]
            and first["members"] == 1;
        assert "textbooks"
            not in [
                k
                for (k, x) in groups(client).items()
                if x["suggested"]
            ];
        assert call(client, "leave_group", {"group_id": g})["ok"];
        again = groups(client)["textbooks"];
        assert not again["member"] and again["members"] == 0;
        assert not call(client, "leave_group", {"group_id": g})["ok"];
    } finally {
        client.close();
    }
}

test "a student who hasn't joined can read a group but not post in it" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        g = joined(client, "textbooks");
        ai_says([chat()]);
        say(client, g, "Anyone taking EECS 280 this term?");
        student(client, "kai@umich.edu");
        view = call(client, "group_view", {"group_id": g});
        assert view["ok"] and not view["member"];
        assert [m["text"] for m in view["messages"]]
            == ["Anyone taking EECS 280 this term?"];
        refused = say(client, g, "me!");
        assert not refused["ok"] and "Join" in refused["error"];
    } finally {
        client.close();
    }
}

test "signing in joins no group and creates only the themes" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        assert len(call(client, "list_groups_for_me", {})) == 8;
        assert len(call(client, "list_groups_for_me", {})) == 8;
    } finally {
        client.close();
    }
}

test "a sell message stays in the chat with a Selling tag and its facts" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        g = joined(client, "furniture");
        ai_says([sell_desk()]);
        sent = say(client, g, "Selling my IKEA desk $30");
        assert sent["filed"] and sent["filed_count"] == 1;
        msgs = messages(client, g);
        assert len(msgs) == 1 and msgs[0]["text"] == "Selling my IKEA desk $30";
        tag = msgs[0]["tags"][0];
        assert tag["label"] == "Selling" and tag["title"] == "IKEA desk";
        assert tag["confirmed"].startswith("$30")
            and tag["status"] == "available"
            and tag["mine"];
    } finally {
        client.close();
    }
}

test "plain chat gets no tag and no assistant message" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        g = joined(client, "moveout");
        ai_says([chat()]);
        sent = say(client, g, "Anyone else arriving on the 20th?");
        assert sent["ok"] and not sent["filed"] and sent["follow_up"] is None;
        msgs = messages(client, g);
        assert len(msgs) == 1 and msgs[0]["tags"] == [] and not msgs[0]["ai"];
    } finally {
        client.close();
    }
}

test "an unclear message asks the sender, and the tag appears after the answer" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        g = joined(client, "furniture");
        guess = draft("Desk", PostKind.OFFER, Category.FURNITURE, "desk");
        guess.guessed = ["kind"];
        ai_says([guess]);
        asked = say(client, g, "desk");
        assert not asked["filed"] and "selling" in asked["follow_up"]["question"];
        student(client, "mina@umich.edu");
        assert messages(client, g)[0]["tags"] == [];
        act_as(client, "jae@umich.edu");
        ai_says([guess]);
        done = call(
            client,
            "answer_group_followup",
            {"message_id": asked["message_id"], "answers": "kind:request"}
        );
        assert done["filed"];
        assert messages(client, g)[0]["tags"][0]["label"] == "Buying";
    } finally {
        client.close();
    }
}

test "a message with several items gets one tag per item" {
    client = served();
    try {
        student(client, "kai@umich.edu");
        g = joined(client, "moveout");
        ai_says(
            [
                DraftSet(
                    language="en",
                    drafts=[
                        draft("Bike", PostKind.OFFER, Category.VEHICLE, "bike", 60.0),
                        draft(
                            "Floor lamp",
                            PostKind.OFFER,
                            Category.ESSENTIALS,
                            "lamp",
                            10.0
                        ),
                        draft(
                            "Twin mattress",
                            PostKind.OFFER,
                            Category.FURNITURE,
                            "mattress"
                        )
                    ]
                )
            ]
        );
        sent = say(client, g, "Moving out: bike $60, lamp $10, twin mattress");
        assert sent["filed_count"] == 3;
        tags = messages(client, g)[0]["tags"];
        assert [t["title"] for t in tags] == ["Bike", "Floor lamp", "Twin mattress"];
        assert all([t["label"] == "Selling" for t in tags]);
    } finally {
        client.close();
    }
}

test "marking a tagged item sold or no longer available updates its tag" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        g = joined(client, "furniture");
        ai_says([sell_desk()]);
        say(client, g, "Selling my IKEA desk $30");
        tag = messages(client, g)[0]["tags"][0];
        assert call(
            client, "close_group_post", {"post_id": tag["post_id"], "reason": "sold"}
        )["ok"];
        after = messages(client, g)[0]["tags"][0];
        assert after["status"] == "sold" and after["status_label"] == "Sold";
        ai_says([want_desk()]);
        say(client, g, "Looking for a desk under $40");
        second = messages(client, g)[-1]["tags"][0];
        call(
            client,
            "close_group_post",
            {"post_id": second["post_id"], "reason": "withdrawn"}
        );
        assert messages(client, g)[-1]["tags"][0]["status_label"]
            == "No longer available";
    } finally {
        client.close();
    }
}

test "the author can say it was just chat; nobody else can" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        g = joined(client, "furniture");
        ai_says([sell_desk()]);
        sent = say(client, g, "Selling my IKEA desk $30");
        student(client, "mina@umich.edu");
        assert not call(
            client, "untag_group_message", {"message_id": sent["message_id"]}
        )["ok"];
        act_as(client, "jae@umich.edu");
        assert call(client, "untag_group_message", {"message_id": sent["message_id"]})[
            "ok"
        ];
        assert messages(client, g)[0]["tags"] == [];
        assert call(client, "list_my_posts", {})[0]["status"] != "live";
    } finally {
        client.close();
    }
}

test "an expired tagged post shows Expired" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        g = joined(client, "furniture");
        ai_says([sell_desk()]);
        say(client, g, "Selling my IKEA desk $30");
        os.environ["UARRIVED_TODAY"] = "2099-12-31";
        try {
            assert messages(client, g)[0]["tags"][0]["status_label"] == "Expired";
        } finally {
            os.environ.pop("UARRIVED_TODAY", None);
        }
    } finally {
        client.close();
    }
}

test "without AI, a clear sell message asks and then gets its tag" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        g = joined(client, "vehicles");
        ai_says([MockError(error=AuthenticationError("no key"))]);
        asked = say(client, g, "Selling my bike for $80");
        assert asked["follow_up"] is not None;
        ai_says([MockError(error=AuthenticationError("no key"))]);
        done = call(
            client,
            "answer_group_followup",
            {
                "message_id": asked["message_id"],
                "answers": "kind:offer|category:vehicle"
            }
        );
        assert done["filed"]
            and messages(client, g)[0]["tags"][0]["label"] == "Selling";
    } finally {
        client.close();
    }
}

test "a match shows only in the owner's private panel, with the reason; the feed gets no note" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        g = joined(client, "furniture");
        ai_says([want_desk()]);
        say(client, g, "Looking for a desk, up to $40");
        student(client, "jae@umich.edu");
        joined(client, "furniture");
        ai_says([sell_desk()]);
        say(client, g, "Selling my IKEA desk $30");
        msgs = messages(client, g);
        assert [
            m
            for m in msgs
            if m["ai"]
        ]
            == [];
        jae_tag = msgs[-1]["tags"][0];
        card = jae_tag["matches"][0];
        assert card["poster"] == "Mina"
            and "$30 is within the $40 budget" in card["reasons"];
        assert msgs[0]["tags"][0]["matches"] == [];
    } finally {
        client.close();
    }
}

test "a match in another group notifies privately and adds no note" {
    client = served();
    try {
        student(client, "kai@umich.edu");
        bikes = joined(client, "vehicles");
        ai_says([draft("Bike", PostKind.REQUEST, Category.VEHICLE, "bike", 100.0)]);
        say(client, bikes, "Looking for a bike under $100");
        before = call(client, "unread_suggestions", {});
        student(client, "lee@umich.edu");
        moveout = joined(client, "moveout");
        ai_says([draft("Bike", PostKind.OFFER, Category.VEHICLE, "bike", 80.0)]);
        say(client, moveout, "Selling my bike for $80");
        assert [
            m
            for m in messages(client, moveout)
            if m["ai"]
        ]
            == [];
        act_as(client, "kai@umich.edu");
        assert call(client, "unread_suggestions", {}) == before + 1;
        mine = call(client, "list_my_suggestions", {});
        assert len(mine) == 1 and "$80" in " ".join(mine[0]["reasons"]);
    } finally {
        client.close();
    }
}

test "with nothing that fits the owner sees Finding matches, and a match panel lists at most five" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        g = joined(client, "furniture");
        ai_says([sell_desk()]);
        say(client, g, "Selling my IKEA desk $30");
        first = messages(client, g)[0]["tags"][0];
        assert first["owner_state"].startswith("Finding matches");
        for name in ["a1", "a2", "a3", "a4", "a5", "a6"] {
            student(client, f"{name}@umich.edu");
            joined(client, "furniture");
            ai_says([want_desk()]);
            say(client, g, "Looking for a desk, up to $40");
        }
        act_as(client, "jae@umich.edu");
        mine = messages(client, g)[0]["tags"][0];
        assert len(mine["matches"]) == 5 and mine["owner_state"] == "Match found (5)";
    } finally {
        client.close();
    }
}

test "a same-category match with no fact doesn't notify" {
    client = served();
    try {
        student(client, "kai@umich.edu");
        g = joined(client, "furniture");
        ai_says([draft("Kayak rack", PostKind.REQUEST, Category.FURNITURE, "other")]);
        say(client, g, "Looking for a kayak rack");
        before = call(client, "unread_suggestions", {});
        student(client, "lee@umich.edu");
        joined(client, "furniture");
        ai_says([draft("Coat stand", PostKind.OFFER, Category.FURNITURE, "other")]);
        say(client, g, "Selling a coat stand");
        act_as(client, "kai@umich.edu");
        assert call(client, "unread_suggestions", {}) == before;
    } finally {
        client.close();
    }
}

test "I'm interested opens one private thread with the poster, who sees who started it" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        g = joined(client, "furniture");
        ai_says([sell_desk()]);
        say(client, g, "Selling my IKEA desk $30");
        msg = messages(client, g)[0];
        body = {
            "post_id": msg["tags"][0]["post_id"],
            "via_post_id": "",
            "group_id": g,
            "message_id": msg["id"]
        };
        student(client, "mina@umich.edu");
        first = call(client, "start_thread", body);
        assert first["ok"];
        assert messages(client, g)[0]["tags"][0]["my_chat"] == first["chat_id"];
        call(
            client, "thread_send", {"chat_id": first["chat_id"], "text": "Still there?"}
        );
        act_as(client, "jae@umich.edu");
        threads = call(client, "list_threads", {});
        assert [t["other_name"] for t in threads] == ["Mina"];
        assert threads[0]["state"] == "your_turn";
        owner = messages(client, g)[0]["tags"][0];
        assert owner["owner_state"] == "1 interested"
            and owner["threads"][0]["other_name"] == "Mina";
    } finally {
        client.close();
    }
}

test "blocked students don't see each other's messages or get matched" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        g = joined(client, "furniture");
        call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "request",
                    "category": "furniture",
                    "title": "Desk",
                    "price": 40
                }
            }
        );
        student(client, "jae@umich.edu");
        call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "offer",
                    "category": "furniture",
                    "title": "Old desk",
                    "price": 20
                }
            }
        );
        sid = call(client, "list_my_suggestions", {})[0]["id"];
        assert call(client, "block_in_suggestion", {"suggestion_id": sid});
        joined(client, "furniture");
        ai_says([chat()]);
        say(client, g, "hello from jae");
        act_as(client, "mina@umich.edu");
        assert [m["text"] for m in messages(client, g)] == [];
    } finally {
        client.close();
    }
}

test "a clear buy phrase files without asking even when the model guessed the kind" {
    client = served();
    try {
        student(client, "kai@umich.edu");
        g = joined(client, "vehicles");
        guess = draft("Bike", PostKind.OFFER, Category.VEHICLE, "bike", 100.0);
        guess.guessed = ["kind"];
        ai_says([guess]);
        sent = say(client, g, "Looking for a bike under $100");
        assert sent["filed"] and sent["follow_up"] is None;
        assert messages(client, g)[0]["tags"][0]["label"] == "Buying";
    } finally {
        client.close();
    }
}
