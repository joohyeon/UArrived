"""Served scenario tests for cohort groups and AI topic groups (plan 004 G7). AI is MockLLM."""

import os;
import json;
import tempfile;
import ai.draft;
import from jaclang.byllm.lib { MockLLM, MockError, AuthenticationError }
import from jaclang.testing.testing { JacTestClient }
import from market.testkit { served }
import from ai.draft { PostDraft, DraftSet, PostKind, Category }
import from market.topics { Invite }
import from core.groups { ChatGroup }
import from core.profile { Mailbox }
import from market.notify { invite_sweep }

def call(client: JacTestClient, name: str, body: dict[str, any]) -> any {
    return client.post(f"/function/{name}", json=body).json()["data"]["result"];
}

"""Register, set the arrival date, verify (which joins the cohort), and return the cohort id."""
def student(client: JacTestClient, email: str, arrival: str = "2026-08-20") -> str {
    client.register_user(email, "password123");
    call(
        client,
        "update_my_profile",
        {
            "changes": {
                "arrival_date": arrival,
                "display_name": email.split("@")[0].capitalize()
            }
        }
    );
    token = call(client, "start_verification", {"email": email})["dev_token"];
    assert call(client, "confirm_verification", {"token": token})["ok"];
    groups = call(client, "my_groups", {});
    return [
        g["id"]
        for g in groups
        if g["kind"] == "cohort"
    ][0];
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

def chat -> PostDraft {
    return PostDraft(
        about_market=False,
        kind=PostKind.REQUEST,
        category=Category.ESSENTIALS,
        title="Hi",
        description="hi"
    );
}

def want_desk -> PostDraft {
    return PostDraft(
        kind=PostKind.REQUEST,
        category=Category.FURNITURE,
        title="Desk",
        description="I need a desk this weekend.",
        price=40.0,
        available_from="2099-09-27",
        available_until="2099-09-28",
        area="central campus"
    );
}

def sell_desk -> PostDraft {
    return PostDraft(
        kind=PostKind.OFFER,
        category=Category.FURNITURE,
        title="Wooden desk",
        description="Selling my desk.",
        price=30.0,
        available_until="2099-10-03",
        area="central campus"
    );
}

test "students arriving the same month share a cohort group and see each other's chat" {
    client = served();
    try {
        mina_cohort = student(client, "mina@umich.edu", "2026-08-20");
        jae_cohort = student(client, "jae@umich.edu", "2026-08-05");
        assert mina_cohort == jae_cohort;
        assert call(client, "my_groups", {})[0]["name"] == "Arriving Aug 2026";
        ai_says([chat()]);
        result = call(
            client,
            "post_in_group",
            {"group_id": jae_cohort, "text": "Hi everyone, anyone landing on the 20th?"}
        );
        assert result["ok"] and not result["filed"];
        act_as(client, "mina@umich.edu");
        msgs = call(client, "group_view", {"group_id": mina_cohort})["messages"];
        assert [(m["author"], m["text"], m["ai"]) for m in msgs]
            == [("Jae", "Hi everyone, anyone landing on the 20th?", False)];
        kai_cohort = student(client, "kai@umich.edu", "2026-01-10");
        assert kai_cohort != mina_cohort;
        assert not call(client, "group_view", {"group_id": mina_cohort})["ok"];
    } finally {
        client.close();
    }
}

test "a market message becomes a topic group, and a matching seller is filed into the same one" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        ai_says([want_desk()]);
        first = call(
            client,
            "post_in_group",
            {
                "group_id": cohort,
                "text": "Need a desk near campus this weekend, around $40"
            }
        );
        assert first["filed"] and first["invited"] == 0;
        topic = first["topic_group_id"];
        replies = [
            m["text"]
            for m in call(client, "group_view", {"group_id": cohort})["messages"]
            if m["ai"]
        ];
        assert replies
            == [
                "I started a group for this, \"Desks near campus\". Nobody else's posts fit yet; I'll invite people as matching posts come in."
            ];
        student(client, "jae@umich.edu", "2026-08-01");
        ai_says([sell_desk()]);
        second = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling my wooden desk, $30, until Oct 3"}
        );
        assert second["filed"] and second["topic_group_id"] == topic;
        assert second["invited"] == 0;
        view = call(client, "group_view", {"group_id": topic});
        assert view["member"] and view["members"] == 2;
        assert sorted([p["title"] for p in view["posts"]]) == ["Desk", "Wooden desk"];
    } finally {
        client.close();
    }
}

test "a seller's new message invites the buyer, who joins by choice" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "request",
                    "category": "furniture",
                    "title": "Desk",
                    "price": 40,
                    "area": "Central Campus"
                }
            }
        );
        student(client, "jae@umich.edu");
        ai_says([sell_desk()]);
        sent = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling my wooden desk $30"}
        );
        assert sent["filed"] and sent["invited"] == 1;
        cohort_reply = [
            m["text"]
            for m in call(client, "group_view", {"group_id": cohort})["messages"]
            if m["ai"]
        ][0];
        assert "invited 1 student whose posts fit" in cohort_reply;
        act_as(client, "mina@umich.edu");
        invites = call(client, "my_group_invites", {});
        assert len(invites) == 1 and invites[0]["group_name"] == "Desks near campus";
        assert "$30 is within the $40 budget" in invites[0]["reason"];
        peek = call(client, "group_view", {"group_id": sent["topic_group_id"]});
        assert peek["ok"]
            and not peek["member"]
            and peek["messages"] == []
            and peek["invite_id"];
        assert call(client, "join_topic_group", {"invite_id": invites[0]["id"]})["ok"];
        inside = call(client, "group_view", {"group_id": sent["topic_group_id"]});
        assert inside["member"]
            and "Wooden desk" in [p["title"] for p in inside["posts"]];
        assert call(client, "my_group_invites", {}) == [];
        assert call(
            client,
            "post_in_group",
            {"group_id": sent["topic_group_id"], "text": "Can I pick it up Saturday?"}
        )["ok"];
        act_as(client, "jae@umich.edu");
        texts = [
            m["text"]
            for m in call(client, "group_view", {"group_id": sent["topic_group_id"]})[
                "messages"
            ]
        ];
        assert "Can I pick it up Saturday?" in texts;
    } finally {
        client.close();
    }
}

test "a student who isn't invited can't read a topic group" {
    client = served();
    try {
        cohort = student(client, "jae@umich.edu");
        ai_says([sell_desk()]);
        topic = call(
            client, "post_in_group", {"group_id": cohort, "text": "Selling my desk"}
        )["topic_group_id"];
        student(client, "kai@umich.edu");
        assert not call(client, "group_view", {"group_id": topic})["ok"];
        assert not call(client, "post_in_group", {"group_id": topic, "text": "hi"})[
            "ok"
        ];
    } finally {
        client.close();
    }
}

test "an unclear message gets one question, and the answer files it" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        ai_says(
            [
                PostDraft(
                    kind=PostKind.REQUEST,
                    category=Category.FURNITURE,
                    title="Desk",
                    description="desk",
                    guessed=["kind"]
                )
            ]
        );
        first = call(client, "post_in_group", {"group_id": cohort, "text": "desk"});
        assert not first["filed"]
            and "selling something" in first["follow_up"]["question"];
        ai_says(
            [
                PostDraft(
                    kind=PostKind.REQUEST,
                    category=Category.FURNITURE,
                    title="Desk",
                    description="desk",
                    guessed=["kind"]
                )
            ]
        );
        answered = call(
            client,
            "answer_group_followup",
            {"message_id": first["message_id"], "answers": "kind:offer"}
        );
        assert answered["filed"];
        assert call(client, "list_my_posts", {})[0]["kind"] == "offer";
    } finally {
        client.close();
    }
}

test "without AI, market-looking messages still get filed after the questions" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        ai_says([MockError(error=AuthenticationError("no key"))]);
        q = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling my bike before I move"}
        );
        assert "selling something" in q["follow_up"]["question"];
        ai_says([MockError(error=AuthenticationError("no key"))]);
        done = call(
            client,
            "answer_group_followup",
            {"message_id": q["message_id"], "answers": "kind:offer|category:vehicle"}
        );
        assert done["filed"];
        ai_says([MockError(error=AuthenticationError("no key"))]);
        plain = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "What's the best coffee on campus?"}
        );
        assert plain["ok"] and not plain["filed"] and plain["follow_up"] is None;
    } finally {
        client.close();
    }
}

test "a sold item leaves the topic group's summary" {
    client = served();
    try {
        cohort = student(client, "jae@umich.edu");
        ai_says([sell_desk()]);
        sent = call(
            client, "post_in_group", {"group_id": cohort, "text": "Selling my desk"}
        );
        post_id = call(client, "list_my_posts", {})[0]["id"];
        assert call(client, "close_group_post", {"post_id": post_id, "reason": "sold"})[
            "ok"
        ];
        assert call(client, "group_view", {"group_id": sent["topic_group_id"]})["posts"]
            == [];
    } finally {
        client.close();
    }
}

test "a blocked buyer isn't invited, and their messages are hidden" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
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
        ai_says([sell_desk()]);
        sent = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling my wooden desk $30"}
        );
        assert sent["invited"] == 0;
        act_as(client, "mina@umich.edu");
        assert call(client, "my_group_invites", {}) == [];
        ai_says([chat()]);
        call(client, "post_in_group", {"group_id": cohort, "text": "hello"});
        act_as(client, "jae@umich.edu");
        authors = [
            m["author"]
            for m in call(client, "group_view", {"group_id": cohort})["messages"]
            if not m["ai"]
        ];
        assert "Mina" not in authors;
    } finally {
        client.close();
    }
}

test "an invite shows in the badge until answered" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
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
        ai_says([sell_desk()]);
        call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling my wooden desk $30"}
        );
        act_as(client, "mina@umich.edu");
        before = call(client, "unread_suggestions", {});
        invite = call(client, "my_group_invites", {})[0]["id"];
        assert call(client, "dismiss_topic_invite", {"invite_id": invite})["ok"];
        assert call(client, "unread_suggestions", {}) == before - 1;
        assert call(client, "my_group_invites", {}) == [];
    } finally {
        client.close();
    }
}

test "invites are emailed once, with the group name and reason" {
    g = root ++> ChatGroup(
        kind="topic",
        key="furniture:desk",
        name="Desks near campus",
        created_at="2099-08-01T10:00:00+00:00"
    );
    box = root ++> Mailbox(owner_root="mina", email="mina@umich.edu", enabled=True);
    inv = root ++> Invite(
        group_id=jid(g),
        invitee_root="mina",
        post_id="p1",
        reason="Your post \"Desk\" fits: $30 is within the $40 budget",
        created_at="2099-08-01T10:00:00+00:00"
    );
    done = root ++> Invite(
        group_id=jid(g),
        invitee_root="mina",
        post_id="p2",
        reason="old",
        created_at="2099-08-01T10:00:00+00:00",
        status="joined"
    );
    path = os.path.join(tempfile.mkdtemp(), "outbox.jsonl");
    os.environ["UARRIVED_EMAIL_OUTBOX"] = path;
    try {
        assert invite_sweep(root) == 1;
        assert invite_sweep(root) == 0;
        with open(path) as f {
            mails = [
                json.loads(line)
                for line in f
                if line.strip()
            ];
        }
        assert len(mails) == 1 and mails[0]["to"] == "mina@umich.edu";
        assert "\"Desks near campus\"" in mails[0]["body"]
            and "$40 budget" in mails[0]["body"];
        assert "old" not in mails[0]["body"];
        assert inv.emailed and not done.emailed;
    } finally {
        os.environ.pop("UARRIVED_EMAIL_OUTBOX", None);
        del inv;
        del done;
        del box;
        del g;
    }
}

test "a buyer is invited to a topic group once, however many sellers file into it" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
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
        ai_says([sell_desk()]);
        first = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling my wooden desk $30"}
        );
        assert first["invited"] == 1;
        student(client, "kai@umich.edu");
        ai_says(
            [
                PostDraft(
                    kind=PostKind.OFFER,
                    category=Category.FURNITURE,
                    title="Oak desk",
                    description="Selling.",
                    price=35.0
                )
            ]
        );
        second = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling an oak desk $35"}
        );
        assert second["topic_group_id"] == first["topic_group_id"]
            and second["invited"] == 0;
        replies = [
            m["text"]
            for m in call(client, "group_view", {"group_id": cohort})["messages"]
            if m["ai"]
        ];
        assert replies[-1].startswith("I added this to \"Desks near campus\"");
        act_as(client, "mina@umich.edu");
        assert len(call(client, "my_group_invites", {})) == 1;
    } finally {
        client.close();
    }
}

test "a greeting the model can't place stays chat, and a post that can't be filed says why" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        ai_says(
            [
                PostDraft(
                    kind=PostKind.REQUEST,
                    category=Category.SERVICE,
                    title="Ride",
                    description="ride",
                    guessed=["kind", "category"]
                )
            ]
        );
        hi = call(
            client,
            "post_in_group",
            {
                "group_id": cohort,
                "text": "Hi all! Anyone else on the Detroit flight on Aug 20?"
            }
        );
        assert hi["ok"] and not hi["filed"] and hi["follow_up"] is None;
        ai_says(
            [
                PostDraft(
                    kind=PostKind.REQUEST,
                    category=Category.FURNITURE,
                    title="Desk",
                    description="desk",
                    available_from="2000-01-01"
                )
            ]
        );
        late = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Need a desk on Jan 1 2000"}
        );
        assert late["ok"]
            and not late["filed"]
            and "couldn't file it" in late["notice"];
        assert len(call(client, "group_view", {"group_id": cohort})["messages"]) == 2;
    } finally {
        client.close();
    }
}

test "a student who corrects the assistant's guess keeps their own words" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        ai_says(
            [
                PostDraft(
                    kind=PostKind.OFFER,
                    category=Category.ESSENTIALS,
                    title="Mini fridge",
                    description="I have a mini fridge to sell.",
                    guessed=["kind"]
                )
            ]
        );
        q = call(client, "post_in_group", {"group_id": cohort, "text": "mini fridge"});
        ai_says(
            [
                PostDraft(
                    kind=PostKind.OFFER,
                    category=Category.ESSENTIALS,
                    title="Mini fridge",
                    description="I have a mini fridge to sell.",
                    guessed=["kind"]
                )
            ]
        );
        assert call(
            client,
            "answer_group_followup",
            {"message_id": q["message_id"], "answers": "kind:request"}
        )["filed"];
        mine = call(client, "list_my_posts", {})[0];
        assert mine["kind"] == "request" and mine["description"] == "mini fridge";
    } finally {
        client.close();
    }
}

test "a seller of other furniture isn't invited just because dates overlap" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
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
        student(client, "kai@umich.edu");
        ai_says(
            [
                PostDraft(
                    kind=PostKind.OFFER,
                    category=Category.FURNITURE,
                    title="Twin mattress",
                    description="Selling.",
                    price=20.0
                )
            ]
        );
        sent = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling a twin mattress $20"}
        );
        assert sent["filed"] and sent["invited"] == 0;
    } finally {
        client.close();
    }
}

test "different words for the same item meet in one topic group" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        ai_says(
            [
                PostDraft(
                    kind=PostKind.REQUEST,
                    category=Category.FURNITURE,
                    title="Study table",
                    description="I need a study table.",
                    price=40.0,
                    item="desk"
                )
            ]
        );
        first = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Need a study table, up to $40"}
        );
        student(client, "jae@umich.edu");
        ai_says(
            [
                PostDraft(
                    kind=PostKind.OFFER,
                    category=Category.FURNITURE,
                    title="Wooden desk",
                    description="Selling.",
                    price=30.0,
                    item="desk"
                )
            ]
        );
        second = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling a wooden desk $30"}
        );
        assert first["topic_group_id"] == second["topic_group_id"];
        assert call(client, "group_view", {"group_id": first["topic_group_id"]})["name"]
            == "Desks near campus";
    } finally {
        client.close();
    }
}

test "an unlisted item files under Other, and the compose form gets items from the title" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        ai_says(
            [
                PostDraft(
                    kind=PostKind.OFFER,
                    category=Category.FURNITURE,
                    title="Kayak rack",
                    description="Selling.",
                    price=15.0,
                    item="gizmo"
                )
            ]
        );
        odd = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling a kayak rack $15"}
        );
        assert call(client, "group_view", {"group_id": odd["topic_group_id"]})["name"]
            == "Other furniture";
        made = call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "offer",
                    "category": "furniture",
                    "title": "Desk chair",
                    "price": 20
                }
            }
        );
        assert made["ok"] and made["post"]["item"] == "chair";
        edited = call(
            client,
            "edit_post",
            {
                "post_id": made["post"]["id"],
                "changes": {"title": "Floor lamp", "category": "essentials"}
            }
        );
        assert edited["ok"] and edited["post"]["item"] == "lamp";
        kept = call(
            client,
            "edit_post",
            {"post_id": made["post"]["id"], "changes": {"price": 25}}
        );
        assert kept["post"]["item"] == "lamp";
    } finally {
        client.close();
    }
}

test "without AI, a study table still files with desks" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        ai_says([MockError(error=AuthenticationError("no key"))]);
        q = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling my study table"}
        );
        ai_says([MockError(error=AuthenticationError("no key"))]);
        done = call(
            client,
            "answer_group_followup",
            {"message_id": q["message_id"], "answers": "kind:offer|category:furniture"}
        );
        assert done["filed"];
        assert call(client, "group_view", {"group_id": done["topic_group_id"]})["name"]
            == "Desks near campus";
    } finally {
        client.close();
    }
}

test "DTW riders two days apart share a ride group, listed soonest first" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        ai_says(
            [
                PostDraft(
                    kind=PostKind.REQUEST,
                    category=Category.SERVICE,
                    title="Ride from DTW",
                    description="Need a ride.",
                    route_from="DTW",
                    route_to="Ann Arbor",
                    available_from="2099-10-03",
                    time_from="15:00"
                )
            ]
        );
        late = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Need a ride from DTW Oct 3 at 3pm"}
        );
        student(client, "jae@umich.edu");
        ai_says(
            [
                PostDraft(
                    kind=PostKind.REQUEST,
                    category=Category.SERVICE,
                    title="Ride from DTW",
                    description="Need a ride.",
                    route_from="DTW",
                    route_to="Ann Arbor",
                    available_from="2099-10-01",
                    time_from="09:00"
                )
            ]
        );
        early = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Need a ride from DTW Oct 1 at 9am"}
        );
        assert late["filed"] and early["topic_group_id"] == late["topic_group_id"];
        view = call(client, "group_view", {"group_id": early["topic_group_id"]});
        assert view["name"] == "Rides from DTW to Ann Arbor · week of Sep 28";
        assert [p["available_from"] for p in view["posts"]]
            == ["2099-10-01", "2099-10-03"];
    } finally {
        client.close();
    }
}

test "the group list shows the cohort first, then the most recently active topic group" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        ai_says([sell_desk()]);
        desks = call(
            client, "post_in_group", {"group_id": cohort, "text": "Selling my desk"}
        )["topic_group_id"];
        ai_says(
            [
                PostDraft(
                    kind=PostKind.OFFER,
                    category=Category.ESSENTIALS,
                    title="Floor lamp",
                    description="Selling.",
                    price=10.0,
                    item="lamp"
                )
            ]
        );
        lamps = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling a floor lamp $10"}
        )["topic_group_id"];
        assert [g["id"] for g in call(client, "my_groups", {})]
            == [cohort, lamps, desks];
        call(client, "post_in_group", {"group_id": desks, "text": "Still available"});
        assert [g["id"] for g in call(client, "my_groups", {})]
            == [cohort, desks, lamps];
    } finally {
        client.close();
    }
}

test "a student can leave a topic group but not their cohort" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        ai_says([sell_desk()]);
        desks = call(
            client, "post_in_group", {"group_id": cohort, "text": "Selling my desk"}
        )["topic_group_id"];
        student(client, "jae@umich.edu");
        assert not call(client, "leave_topic_group", {"group_id": desks})["ok"];
        act_as(client, "mina@umich.edu");
        assert not call(client, "leave_topic_group", {"group_id": cohort})["ok"];
        assert call(client, "leave_topic_group", {"group_id": desks})["ok"];
        assert desks not in [g["id"] for g in call(client, "my_groups", {})];
        assert not call(client, "group_view", {"group_id": desks})["ok"];
    } finally {
        client.close();
    }
}

test "after leaving, the next matching post invites the student back once" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
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
        ai_says([sell_desk()]);
        desks = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling my wooden desk $30"}
        )["topic_group_id"];
        act_as(client, "mina@umich.edu");
        invite = call(client, "my_group_invites", {})[0]["id"];
        assert call(client, "join_topic_group", {"invite_id": invite})["ok"];
        assert call(client, "leave_topic_group", {"group_id": desks})["ok"];
        student(client, "kai@umich.edu");
        ai_says(
            [
                PostDraft(
                    kind=PostKind.OFFER,
                    category=Category.FURNITURE,
                    title="Oak desk",
                    description="Selling.",
                    price=35.0,
                    item="desk"
                )
            ]
        );
        assert call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling an oak desk $35"}
        )["invited"]
            == 1;
        student(client, "lee@umich.edu");
        ai_says(
            [
                PostDraft(
                    kind=PostKind.OFFER,
                    category=Category.FURNITURE,
                    title="Pine desk",
                    description="Selling.",
                    price=25.0,
                    item="desk"
                )
            ]
        );
        assert call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling a pine desk $25"}
        )["invited"]
            == 0;
        act_as(client, "mina@umich.edu");
        assert len(call(client, "my_group_invites", {})) == 1;
    } finally {
        client.close();
    }
}

def item_draft(
    title: str,
    category: any,
    item: str,
    price: float | None = None,
    kind: any = PostKind.OFFER
) -> PostDraft {
    return PostDraft(
        kind=kind,
        category=category,
        title=title,
        description=f"{title}.",
        price=price,
        area="kerrytown",
        item=item
    );
}

def moving_sale(more: list[PostDraft]) -> DraftSet {
    return DraftSet(
        language="en",
        drafts=[item_draft("Bike", Category.VEHICLE, "bike", 50.0)] + more
    );
}

test "a moving-out sale becomes one post per item, each in its own group" {
    client = served();
    try {
        cohort = student(client, "kai@umich.edu");
        ai_says(
            [
                moving_sale(
                    [
                        item_draft("Floor lamp", Category.ESSENTIALS, "lamp", 10.0),
                        item_draft("Twin mattress", Category.FURNITURE, "mattress")
                    ]
                )
            ]
        );
        sent = call(
            client,
            "post_in_group",
            {
                "group_id": cohort,
                "text": "Moving out - bike $50, lamp $10 and a twin mattress, Kerrytown"
            }
        );
        assert sent["filed"] and sent["filed_count"] == 3 and sent["notice"] == "";
        mine = {p["title"]: p for p in call(client, "list_my_posts", {})};
        assert sorted(mine.keys()) == ["Bike", "Floor lamp", "Twin mattress"];
        assert mine["Bike"]["price"] == 50.0 and mine["Floor lamp"]["price"] == 10.0;
        assert mine["Twin mattress"]["price"] is None;
        assert mine["Floor lamp"]["category"] == "essentials"
            and mine["Floor lamp"]["item"] == "lamp";
        reply = [
            m
            for m in call(client, "group_view", {"group_id": cohort})["messages"]
            if m["ai"]
        ];
        assert len(reply) == 1
            and reply[0]["text"].startswith(
                "I filed 3 items: Bike → \"Bikes near campus\""
            );
        assert [l["name"] for l in reply[0]["links"]]
            == ["Bikes near campus", "Lamps near campus", "Mattresses near campus"];
        student(client, "mina@umich.edu");
        other = [
            m
            for m in call(client, "group_view", {"group_id": cohort})["messages"]
            if m["ai"]
        ][0];
        assert other["links"] == [];
    } finally {
        client.close();
    }
}

test "one message can sell one thing and ask for another" {
    client = served();
    try {
        cohort = student(client, "kai@umich.edu");
        ai_says(
            [
                moving_sale(
                    [
                        item_draft(
                            "Desk", Category.FURNITURE, "desk", 40.0, PostKind.REQUEST
                        )
                    ]
                )
            ]
        );
        sent = call(
            client,
            "post_in_group",
            {
                "group_id": cohort,
                "text": "Selling my bike $50, and I need a desk under $40"
            }
        );
        assert sent["filed_count"] == 2;
        kinds = {p["title"]: p["kind"] for p in call(client, "list_my_posts", {})};
        assert kinds == {"Bike": "offer", "Desk": "request"};
    } finally {
        client.close();
    }
}

test "a buyer is invited only to the group of the item they want" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "request",
                    "category": "essentials",
                    "title": "Lamp",
                    "price": 20
                }
            }
        );
        student(client, "kai@umich.edu");
        ai_says(
            [moving_sale([item_draft("Floor lamp", Category.ESSENTIALS, "lamp", 10.0)])]
        );
        sent = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Selling bike $50 and floor lamp $10"}
        );
        assert sent["invited"] == 1;
        reply = [
            m
            for m in call(client, "group_view", {"group_id": cohort})["messages"]
            if m["ai"]
        ][0];
        assert "Floor lamp → \"Lamps near campus\" (invited 1)" in reply["text"];
        act_as(client, "mina@umich.edu");
        assert [i["group_name"] for i in call(client, "my_group_invites", {})]
            == ["Lamps near campus"];
    } finally {
        client.close();
    }
}

test "only five items file from one message, and the sender is told about the rest" {
    client = served();
    try {
        cohort = student(client, "kai@umich.edu");
        ai_says(
            [
                moving_sale(
                    [
                        item_draft(t, Category.FURNITURE, "")
                        for t in [
                            "Desk",
                            "Chair",
                            "Sofa",
                            "Dresser",
                            "Bookshelf",
                            "Bed"
                        ]
                    ]
                )
            ]
        );
        sent = call(
            client,
            "post_in_group",
            {
                "group_id": cohort,
                "text": "Moving sale: bike, desk, chair, sofa, dresser, bookshelf, bed"
            }
        );
        assert sent["filed_count"] == 5 and "post the other 2" in sent["notice"];
        assert len(call(client, "list_my_posts", {})) == 5;
    } finally {
        client.close();
    }
}

test "one item that can't be filed doesn't stop the others, and only the sender hears why" {
    client = served();
    try {
        cohort = student(client, "kai@umich.edu");
        ai_says(
            [
                moving_sale(
                    [
                        item_draft("Floor lamp", Category.ESSENTIALS, "lamp"),
                        item_draft("Car", Category.VEHICLE, "car", 900000.0)
                    ]
                )
            ]
        );
        sent = call(
            client, "post_in_group", {"group_id": cohort, "text": "bike $50, lamp, car"}
        );
        assert sent["filed_count"] == 2 and "\"Car\"" in sent["notice"];
        reply = [
            m
            for m in call(client, "group_view", {"group_id": cohort})["messages"]
            if m["ai"]
        ][0];
        assert "Car" not in reply["text"];
    } finally {
        client.close();
    }
}

test "clear market words beat the model's no" {
    client = served();
    try {
        cohort = student(client, "mina@umich.edu");
        ai_says(
            [
                PostDraft(
                    about_market=False,
                    kind=PostKind.REQUEST,
                    category=Category.FURNITURE,
                    title="Study table",
                    description="I need a study table.",
                    price=40.0,
                    item="desk"
                )
            ]
        );
        assert call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Looking for a study table, budget $40"}
        )["filed"];
    } finally {
        client.close();
    }
}

test "a drafted item in the wrong goods category files where the list knows it, and ride questions count" {
    client = served();
    try {
        cohort = student(client, "kai@umich.edu");
        ai_says([moving_sale([item_draft("Twin mattress", Category.ESSENTIALS, "")])]);
        call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "selling bike $50 and a twin mattress"}
        );
        mattress = [
            p
            for p in call(client, "list_my_posts", {})
            if p["title"] == "Twin mattress"
        ][0];
        assert mattress["category"] == "furniture" and mattress["item"] == "mattress";
        ai_says(
            [
                PostDraft(
                    kind=PostKind.REQUEST,
                    category=Category.SERVICE,
                    title="Ride from DTW",
                    description="Sharing a ride.",
                    route_from="DTW",
                    route_to="Ann Arbor",
                    available_from="2099-10-03",
                    guessed=["kind", "category"]
                )
            ]
        );
        ride = call(
            client,
            "post_in_group",
            {"group_id": cohort, "text": "Anyone sharing an uber from DTW Oct 3?"}
        );
        assert "offering this (a ride or help)" in ride["follow_up"]["question"];
    } finally {
        client.close();
    }
}
