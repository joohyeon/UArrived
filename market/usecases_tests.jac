"""Market use cases end to end in the themed groups (drop → clarify → match → private thread →
progress). One scenario per real-life case students hit; the AI is MockLLM so outcomes are exact.
"""

import os;
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

"""Post `text` as the current student with the AI returning `d`; returns (message id, post id)."""
def drop(
    client: JacTestClient, group_id: str, text: str, d: PostDraft
) -> tuple[str, str] {
    ai_says([d]);
    sent = call(client, "post_in_group", {"group_id": group_id, "text": text});
    assert sent["filed"] , sent;
    t = tag(client, group_id, sent["message_id"]);
    return (sent["message_id"], t["post_id"]);
}

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

def interested(client: JacTestClient, post_id: str, via: str = "") -> str {
    r = call(
        client,
        "start_thread",
        {"post_id": post_id, "via_post_id": via, "group_id": "", "message_id": ""}
    );
    assert r["ok"] , r;
    return r["chat_id"];
}

def item(
    title: str,
    kind: any,
    category: any,
    price: float | None = None,
    item: str = "",
    free: bool = False,
    area: str = "",
    until: str = "",
    arrangement: str = ""
) -> PostDraft {
    return PostDraft(
        kind=kind,
        category=category,
        title=title,
        description=f"{title}.",
        price=price,
        free=free,
        area=area,
        item=item,
        available_until=until,
        arrangement=arrangement
    );
}

def ride(day: str, time: str) -> PostDraft {
    return PostDraft(
        kind=PostKind.REQUEST,
        category=Category.SERVICE,
        title="Ride from DTW",
        description="Sharing a ride from DTW.",
        route_from="DTW",
        route_to="Ann Arbor",
        available_from=day,
        time_from=time
    );
}

test "housing: a sublet request meets a sublet offer, is reserved, then the lease is signed" {
    client = served();
    try {
        student(client, "ana@umich.edu");
        housing = joined(client, "housing");
        (want_msg, want) = drop(
            client,
            housing,
            "Looking for a summer sublet near North Campus under $900",
            item(
                "Summer sublet",
                PostKind.REQUEST,
                Category.HOUSING,
                900.0,
                area="north campus",
                arrangement="sublet"
            )
        );
        assert tag(client, housing, want_msg)["owner_state"].startswith(
            "Finding matches"
        );
        student(client, "ben@umich.edu");
        joined(client, "housing");
        (room_msg, room) = drop(
            client,
            housing,
            "Subletting my room on North Campus May-Aug, $850/mo",
            item(
                "Room sublet",
                PostKind.OFFER,
                Category.HOUSING,
                850.0,
                area="north campus",
                arrangement="sublet"
            )
        );
        act_as(client, "ana@umich.edu");
        mine = tag(client, housing, want_msg);
        assert mine["owner_state"] == "Match found (1)";
        card = mine["matches"][0];
        assert card["title"] == "Room sublet" and card["poster"] == "Ben";
        assert "$850 is within the $900 budget" in card["reasons"];
        chat = interested(client, room, want);
        t = thread(client, chat);
        assert t["group_name"] == "Housing & sublets"
            and t["origin_text"].startswith("Subletting");
        assert t["my_role"] == "buyer" and "found" in t["actions"];
        act_as(client, "ben@umich.edu");
        assert call(client, "thread_action", {"chat_id": chat, "action": "reserve"})[
            "ok"
        ];
        assert tag(client, housing, room_msg)["status_label"] == "Reserved";
        assert call(client, "thread_action", {"chat_id": chat, "action": "sell"})["ok"];
        act_as(client, "ana@umich.edu");
        assert thread(client, chat)["state_label"] == "Completed · you got it";
    } finally {
        client.close();
    }
}

test "ride share: two students both asking for a DTW ride can open a thread and settle it" {
    client = served();
    try {
        student(client, "kai@umich.edu");
        rides = joined(client, "rides");
        (_, kai_ride) = drop(
            client,
            rides,
            "Need a ride from DTW Oct 2 at 3pm",
            ride("2099-10-02", "15:00")
        );
        student(client, "lin@umich.edu");
        joined(client, "rides");
        (lin_msg, lin_ride) = drop(
            client,
            rides,
            "Anyone sharing a ride from DTW Oct 2 around 3:30?",
            ride("2099-10-02", "15:30")
        );
        card = tag(client, rides, lin_msg)["matches"][0];
        assert card["poster"] == "Kai" and card["label"] == "Buying";
        chat = interested(client, kai_ride, lin_ride);
        t = thread(client, chat);
        assert t["ok"] and t["state"] == "new";
        assert "reserve" not in t["actions"] and "sell" not in t["actions"];
        assert "found" in t["actions"];
        assert call(client, "thread_action", {"chat_id": chat, "action": "found"})[
            "ok"
        ];
        assert thread(client, chat)["state"] == "completed";
        act_as(client, "kai@umich.edu");
        kt = thread(client, chat);
        assert kt["state"] == "completed" and kt["can_send"];
    } finally {
        client.close();
    }
}

test "a free giveaway reads as free and offers no counter-offer" {
    client = served();
    try {
        student(client, "mo@umich.edu");
        kitchen = joined(client, "kitchen");
        (lamp_msg, lamp) = drop(
            client,
            kitchen,
            "Giving away my desk lamp, free",
            item("Desk lamp", PostKind.OFFER, Category.ESSENTIALS, None, "lamp", True)
        );
        assert tag(client, kitchen, lamp_msg)["confirmed"].startswith("free");
        student(client, "ivy@umich.edu");
        joined(client, "kitchen");
        (_, want) = drop(
            client,
            kitchen,
            "Looking for a lamp under $15",
            item("Lamp", PostKind.REQUEST, Category.ESSENTIALS, 15.0, "lamp")
        );
        t = thread(client, interested(client, lamp, want));
        assert not any(["Would you take" in s for s in t["suggestions"]]);
        assert "free" in t["offer"]["confirmed"];
    } finally {
        client.close();
    }
}

test "near miss: a budget under the price isn't a match, but the buyer can still ask and counter" {
    client = served();
    try {
        student(client, "sam@umich.edu");
        bikes = joined(client, "vehicles");
        (bike_msg, bike) = drop(
            client,
            bikes,
            "Selling my bike for $80",
            item("Bike", PostKind.OFFER, Category.VEHICLE, 80.0, "bike")
        );
        student(client, "tom@umich.edu");
        joined(client, "vehicles");
        (want_msg, _) = drop(
            client,
            bikes,
            "Looking for a bike, $70 max",
            item("Bike", PostKind.REQUEST, Category.VEHICLE, 70.0, "bike")
        );
        mine = tag(client, bikes, want_msg);
        assert mine["matches"] == []
            and mine["owner_state"].startswith("Finding matches");
        chat = interested(client, bike);
        t = thread(client, chat);
        assert t["request"] is not None and t["request"]["title"] == "Bike";
        assert "Would you take $70?" in t["suggestions"];
    } finally {
        client.close();
    }
}

test "late match: a request waits in Finding matches until an offer arrives" {
    client = served();
    try {
        student(client, "zoe@umich.edu");
        books = joined(client, "textbooks");
        (want_msg, _) = drop(
            client,
            books,
            "Anyone selling EECS 281 textbooks? Up to $30",
            item(
                "EECS 281 textbook",
                PostKind.REQUEST,
                Category.ESSENTIALS,
                30.0,
                "textbook"
            )
        );
        before = call(client, "unread_suggestions", {});
        assert tag(client, books, want_msg)["owner_state"].startswith(
            "Finding matches"
        );
        student(client, "raj@umich.edu");
        joined(client, "textbooks");
        drop(
            client,
            books,
            "Selling my EECS 281 textbook, $25",
            item(
                "EECS 281 textbook",
                PostKind.OFFER,
                Category.ESSENTIALS,
                25.0,
                "textbook"
            )
        );
        act_as(client, "zoe@umich.edu");
        assert call(client, "unread_suggestions", {}) == before + 1;
        assert tag(client, books, want_msg)["owner_state"] == "Match found (1)";
    } finally {
        client.close();
    }
}

test "one buyer, two sellers: finding it in one thread tells the other seller" {
    client = served();
    try {
        student(client, "ella@umich.edu");
        desks = joined(client, "furniture");
        (want_msg, want) = drop(
            client,
            desks,
            "Looking for a desk under $50",
            item("Desk", PostKind.REQUEST, Category.FURNITURE, 50.0, "desk")
        );
        offers: dict[str, str] = {};
        for name in ["finn", "gus"] {
            student(client, f"{name}@umich.edu");
            joined(client, "furniture");
            (_, offers[name]) = drop(
                client,
                desks,
                "Selling a desk for $40",
                item("Desk", PostKind.OFFER, Category.FURNITURE, 40.0, "desk")
            );
        }
        act_as(client, "ella@umich.edu");
        assert tag(client, desks, want_msg)["owner_state"] == "Match found (2)";
        finn_chat = interested(client, offers["finn"], want);
        gus_chat = interested(client, offers["gus"], want);
        assert finn_chat != gus_chat;
        assert call(client, "thread_action", {"chat_id": finn_chat, "action": "found"})[
            "ok"
        ];
        assert thread(client, gus_chat)["state_label"] == "You found one elsewhere";
        act_as(client, "gus@umich.edu");
        gt = thread(client, gus_chat);
        assert gt["state_label"] == "They found one elsewhere" and not gt["can_send"];
        act_as(client, "finn@umich.edu");
        assert thread(client, finn_chat)["state"] == "completed";
    } finally {
        client.close();
    }
}

test "a seller withdrawing or a post expiring closes the open threads" {
    client = served();
    try {
        student(client, "hal@umich.edu");
        moveout = joined(client, "moveout");
        (_, sofa) = drop(
            client,
            moveout,
            "Selling my sofa for $60",
            item("Sofa", PostKind.OFFER, Category.FURNITURE, 60.0, "sofa")
        );
        (_, chair) = drop(
            client,
            moveout,
            "Selling a chair for $10 until Oct 1",
            item(
                "Chair",
                PostKind.OFFER,
                Category.FURNITURE,
                10.0,
                "chair",
                until="2099-10-01"
            )
        );
        student(client, "ida@umich.edu");
        sofa_chat = interested(client, sofa);
        chair_chat = interested(client, chair);
        act_as(client, "hal@umich.edu");
        call(client, "close_group_post", {"post_id": sofa, "reason": "withdrawn"});
        act_as(client, "ida@umich.edu");
        st = thread(client, sofa_chat);
        assert st["state_label"] == "No longer available" and not st["can_send"];
        assert not call(client, "thread_send", {"chat_id": sofa_chat, "text": "still?"})[
            "ok"
        ];
        os.environ["UARRIVED_TODAY"] = "2099-12-31";
        try {
            assert thread(client, chair_chat)["state_label"] == "No longer available";
        } finally {
            os.environ.pop("UARRIVED_TODAY", None);
        }
    } finally {
        client.close();
    }
}

test "blocking from inside a thread closes it for both and hides each other in the group" {
    client = served();
    try {
        student(client, "jon@umich.edu");
        moveout = joined(client, "moveout");
        (_, lamp) = drop(
            client,
            moveout,
            "Selling a lamp for $10",
            item("Lamp", PostKind.OFFER, Category.ESSENTIALS, 10.0, "lamp")
        );
        student(client, "kim@umich.edu");
        joined(client, "moveout");
        chat = interested(client, lamp);
        assert call(client, "block_in_chat", {"chat_id": chat});
        assert call(client, "list_threads", {}) == [];
        authors = [
            m["author"]
            for m in call(client, "group_view", {"group_id": moveout})["messages"]
        ];
        assert "Jon" not in authors;
        act_as(client, "jon@umich.edu");
        assert call(client, "list_threads", {}) == [];
    } finally {
        client.close();
    }
}

test "a thread started from the Matches tab still links back to the group message" {
    client = served();
    try {
        student(client, "leo@umich.edu");
        bikes = joined(client, "vehicles");
        drop(
            client,
            bikes,
            "Selling my bike for $80",
            item("Bike", PostKind.OFFER, Category.VEHICLE, 80.0, "bike")
        );
        student(client, "max@umich.edu");
        joined(client, "vehicles");
        drop(
            client,
            bikes,
            "Looking for a bike under $100",
            item("Bike", PostKind.REQUEST, Category.VEHICLE, 100.0, "bike")
        );
        s = call(client, "list_my_suggestions", {})[0];
        chat = interested(client, s["other_post"]["id"], s["my_post"]["id"]);
        t = thread(client, chat);
        assert t["group_name"] == "Bikes & vehicles"
            and t["origin_text"] == "Selling my bike for $80";
    } finally {
        client.close();
    }
}
