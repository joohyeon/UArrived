"""Scenario tests for the chat-first market (plan 003 C1-C5): buying, selling, ambiguous
messages, unavailable items, no match, private threads, direct chat, nudges and reply emails.
The AI is always MockLLM."""

import os;
import json;
import uuid;
import tempfile;
import ai.draft;
import from jaclang.byllm.lib { MockLLM, MockError, AuthenticationError }
import from jaclang.testing.testing { JacTestClient }
import from ai.draft { PostDraft, PostKind, Category }
import from core.profile { Mailbox }
import from market.graph { Post, Reply, notes_for }
import from market.messages { nudge_due }
import from market.notify { reply_sweep }

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

def ai_says(drafts: list[any]) {
    ai.draft.drafter = MockLLM(outputs=drafts);
}

def desk_offer -> PostDraft {
    return PostDraft(
        kind=PostKind.OFFER,
        category=Category.FURNITURE,
        title="Solid wood desk",
        description="Desk, pickup only.",
        price=25.0,
        area="central campus",
        constraints=["Pickup only"]
    );
}

def desk_request -> PostDraft {
    return PostDraft(
        kind=PostKind.REQUEST,
        category=Category.FURNITURE,
        title="Need a desk",
        description="Need a desk near campus this weekend.",
        price=40.0,
        area="central campus"
    );
}

def send(client: JacTestClient, text: str, answers: str = "") -> dict[str, any] {
    return call(client, "send_market_message", {"text": text, "answers": answers});
}

test "buying: a message posts at once and the assistant shows the offer that fits" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        ai_says([desk_offer()]);
        assert send(client, "selling my desk $25, central campus, pickup only")[
            "published"
        ];
        student(client, "mina@umich.edu");
        ai_says([desk_request()]);
        sent = send(client, "I need a desk near campus this weekend, ~$40");
        assert sent["ok"] and sent["published"] and sent["follow_up"] is None;
        thread = call(client, "message_thread", {"post_id": sent["post_id"]});
        note = thread["notes"][0];
        assert note["kind"] == "matches"
            and "I found 1 offers that fit" in note["text"];
        assert note["items"][0]["post"]["title"] == "Solid wood desk";
        assert note["items"][0]["post"]["availability"] == "confirmed";
        assert "Pickup only" in note["items"][0]["post"]["limitations"];
        stream = call(client, "market_stream", {});
        desk = [
            i
            for i in stream
            if i["post"]["title"] == "Solid wood desk"
        ][0];
        assert "$25 is within the $40 budget" in desk["reasons"];
    } finally {
        client.close();
    }
}

test "selling: a new offer reaches the open request, both ways" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        ai_says([desk_request()]);
        send(client, "need a desk ~$40 near campus");
        student(client, "jae@umich.edu");
        ai_says([desk_offer()]);
        sent = send(client, "selling my desk $25");
        note = call(client, "message_thread", {"post_id": sent["post_id"]})["notes"][0];
        assert "students looking for this" in note["text"]
            and note["items"][0]["post"]["title"] == "Need a desk";
        act_as(client, "mina@umich.edu");
        titles = [i["post"]["title"] for i in call(client, "market_stream", {})];
        assert "Solid wood desk" in titles;
    } finally {
        client.close();
    }
}

test "ambiguous: the assistant asks one question and posts nothing until it is answered" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        unclear = PostDraft(
            kind=PostKind.REQUEST,
            category=Category.FURNITURE,
            title="Desk",
            description="desk",
            guessed=["kind"]
        );
        ai_says([unclear]);
        first = send(client, "desk");
        assert first["ok"] and not first["published"];
        assert first["follow_up"]["question"]
            == "Are you selling something, or looking for it?";
        assert call(client, "list_my_posts", {}) == [];
        ai_says([unclear]);
        second = send(client, "desk", "kind:offer");
        assert second["published"];
        assert call(client, "list_my_posts", {})[0]["kind"] == "offer";
    } finally {
        client.close();
    }
}

test "without AI the assistant asks what and which way, then posts the student's own words" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        ai_says([MockError(error=AuthenticationError("no key"))]);
        q1 = send(client, "Selling my bike before I move next Friday");
        assert "selling something" in q1["follow_up"]["question"];
        ai_says([MockError(error=AuthenticationError("no key"))]);
        q2 = send(client, "Selling my bike before I move next Friday", "kind:offer");
        assert "What kind of thing" in q2["follow_up"]["question"];
        ai_says([MockError(error=AuthenticationError("no key"))]);
        done = send(
            client,
            "Selling my bike before I move next Friday",
            "kind:offer|category:vehicle"
        );
        assert done["published"];
        mine = call(client, "list_my_posts", {})[0];
        assert mine["category"] == "vehicle" and not mine["ai_generated"];
        assert mine["description"] == "Selling my bike before I move next Friday";
    } finally {
        client.close();
    }
}

test "no match: the assistant says so and a refinement re-checks" {
    client = served();
    try {
        student(client, "mina@umich.edu");
        ai_says([desk_request()]);
        sent = send(client, "need a desk ~$40");
        note = call(client, "message_thread", {"post_id": sent["post_id"]})["notes"][0];
        assert note["kind"] == "no_match" and note["items"] == [];
        values = [c["value"] for c in note["choices"]];
        assert "budget:50" in values and "notify:on" in values;
        assert call(
            client,
            "apply_assistant_choice",
            {"post_id": sent["post_id"], "value": "budget:50"}
        )["ok"];
        assert call(client, "list_my_posts", {})[0]["price"] == 50.0;
        assert len(
            call(client, "message_thread", {"post_id": sent["post_id"]})["notes"]
        )
            == 2;
    } finally {
        client.close();
    }
}

test "unavailable: a sold item leaves streams and can't be replied to" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        ai_says([desk_offer()]);
        desk_id = send(client, "selling my desk $25")["post_id"];
        student(client, "mina@umich.edu");
        ai_says([desk_request()]);
        mine = send(client, "need a desk ~$40")["post_id"];
        act_as(client, "jae@umich.edu");
        assert call(client, "close_message", {"post_id": desk_id, "reason": "sold"})[
            "ok"
        ];
        assert call(client, "list_my_posts", {})[0]["closed_reason"] == "sold";
        act_as(client, "mina@umich.edu");
        assert "Solid wood desk"
            not in [i["post"]["title"] for i in call(client, "market_stream", {})];
        assert call(client, "message_thread", {"post_id": mine})["notes"][0]["items"]
            == [];
        assert not call(
            client, "react_to_message", {"post_id": desk_id, "kind": "interested"}
        )["ok"];
    } finally {
        client.close();
    }
}

test "replies are private to poster and author; others see only counts" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        ai_says([desk_offer()]);
        desk_id = send(client, "selling my desk $25")["post_id"];
        student(client, "mina@umich.edu");
        assert call(
            client,
            "offer_on_message",
            {"post_id": desk_id, "price": 20, "text": "Can pick up Saturday"}
        )["ok"];
        assert call(
            client, "react_to_message", {"post_id": desk_id, "kind": "interested"}
        )["ok"];
        assert call(
            client, "react_to_message", {"post_id": desk_id, "kind": "interested"}
        )["ok"];
        student(client, "kai@umich.edu");
        seen = call(client, "message_thread", {"post_id": desk_id});
        assert seen["replies"] == []
            and seen["counts"] == {"offer": 1, "interested": 1};
        assert seen["notes"] == [];
        act_as(client, "jae@umich.edu");
        mine = call(client, "message_thread", {"post_id": desk_id});
        assert [r["kind"] for r in mine["replies"]] == ["offer", "interested"];
        assert mine["replies"][0]["offer_price"] == 20.0
            and not mine["replies"][0]["mine"];
    } finally {
        client.close();
    }
}

test "the poster answers, then accepts an offer, and a direct chat opens" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        ai_says([desk_offer()]);
        desk_id = send(client, "selling my desk $25")["post_id"];
        student(client, "mina@umich.edu");
        call(
            client,
            "ask_about_message",
            {"post_id": desk_id, "text": "Does it have drawers?"}
        );
        call(client, "offer_on_message", {"post_id": desk_id, "price": 22, "text": ""});
        act_as(client, "jae@umich.edu");
        replies = call(client, "message_thread", {"post_id": desk_id})["replies"];
        assert call(
            client,
            "answer_reply",
            {"reply_id": replies[0]["id"], "text": "Two drawers"}
        )["ok"];
        accepted = call(client, "accept_reply", {"reply_id": replies[1]["id"]});
        assert accepted["ok"] and accepted["chat_id"];
        assert call(
            client,
            "send_message",
            {"chat_id": accepted["chat_id"], "text": "Deal. Saturday 2pm?"}
        )["ok"];
        act_as(client, "mina@umich.edu");
        thread = call(client, "message_thread", {"post_id": desk_id});
        assert "Two drawers" in [r["text"] for r in thread["replies"]];
        chats = call(client, "list_my_chats", {});
        assert len(chats) == 1
            and chats[0]["open"]
            and chats[0]["other_post_title"] == "Solid wood desk";
        assert call(client, "read_chat", {"chat_id": accepted["chat_id"]})["messages"][
            0
        ]["text"]
            == "Deal. Saturday 2pm?";
        assert call(client, "list_my_suggestions", {}) == [];
    } finally {
        client.close();
    }
}

test "you can't reply to your own message, and an offer needs an amount" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        ai_says([desk_offer()]);
        desk_id = send(client, "selling my desk $25")["post_id"];
        assert not call(
            client, "react_to_message", {"post_id": desk_id, "kind": "interested"}
        )["ok"];
        student(client, "mina@umich.edu");
        assert not call(
            client, "offer_on_message", {"post_id": desk_id, "price": -1, "text": ""}
        )["ok"];
        assert not call(
            client, "ask_about_message", {"post_id": desk_id, "text": "   "}
        )["ok"];
    } finally {
        client.close();
    }
}

test "the assistant nudges once after hours with no reply, and never after a reply" {
    me = jid(root);
    quiet = root ++> Post(
        owner_root=me,
        kind="request",
        category="furniture",
        title=f"quiet-{uuid.uuid4()}",
        price=40.0,
        published_on="2099-08-01",
        published_at="2099-08-01T09:00:00+00:00",
        expires_on="2099-08-15"
    );
    answered = root ++> Post(
        owner_root=me,
        kind="request",
        category="furniture",
        title=f"answered-{uuid.uuid4()}",
        published_on="2099-08-01",
        published_at="2099-08-01T09:00:00+00:00",
        expires_on="2099-08-15"
    );
    reply = root ++> Reply(
        post_id=jid(answered),
        author_root="someone",
        to_root=me,
        kind="question",
        created_at="2099-08-01T10:00:00+00:00",
        text="hi"
    );
    try {
        assert nudge_due("2099-08-01T11:00:00+00:00", root) == 0 or not quiet.nudged;
        assert not quiet.nudged;
        nudge_due("2099-08-01T13:30:00+00:00", root);
        assert quiet.nudged and not answered.nudged;
        notes = notes_for(jid(quiet), root);
        assert len(notes) == 1 and notes[0].kind == "nudge";
        nudge_due("2099-08-02T13:30:00+00:00", root);
        assert len(notes_for(jid(quiet), root)) == 1;
    } finally {
        for n in notes_for(jid(quiet), root) {
            del n;
        }
        del reply;
        del quiet;
        del answered;
    }
}

test "offers and questions email the poster once; reactions never email" {
    me = f"poster-{uuid.uuid4()}";
    desk = root ++> Post(
        owner_root=me,
        kind="offer",
        category="furniture",
        title="Solid wood desk",
        price=25.0
    );
    box = root ++> Mailbox(owner_root=me, email="jae@umich.edu", enabled=True);
    offer = root ++> Reply(
        post_id=jid(desk),
        author_root="mina",
        to_root=me,
        kind="offer",
        created_at="2099-08-01T10:00:00+00:00",
        offer_price=20.0
    );
    react = root ++> Reply(
        post_id=jid(desk),
        author_root="kai",
        to_root=me,
        kind="interested",
        created_at="2099-08-01T10:05:00+00:00"
    );
    path = os.path.join(tempfile.mkdtemp(), "outbox.jsonl");
    os.environ["UARRIVED_EMAIL_OUTBOX"] = path;
    try {
        reply_sweep(root);
        reply_sweep(root);
        with open(path) as f {
            mails = [
                json.loads(line)
                for line in f
                if line.strip() and "jae@umich.edu" in line
            ];
        }
        assert len(mails) == 1;
        assert "$20 offered on \"Solid wood desk\"" in mails[0]["body"];
        assert "interested" not in mails[0]["body"].lower();
        assert offer.emailed and not react.emailed;
    } finally {
        os.environ.pop("UARRIVED_EMAIL_OUTBOX", None);
        del offer;
        del react;
        del box;
        del desk;
    }
}
