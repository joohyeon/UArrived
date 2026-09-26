"""Tests for match notifications (U7).

The sweep tests build a small graph directly (outside a server there is one root, so the commons
is the test's own root) and send to a temporary outbox file. Each test uses fresh ids and
removes what it made, because plain tests share a persisted graph.
"""

import os;
import json;
import tempfile;
import uuid;
import from jaclang.testing.testing { JacTestClient }
import from core.profile { Mailbox, Profile, sync_mailbox }
import from market.graph { Post, Suggestion }
import from market.notify { sweep, pending_by_student, digest_body }

glob TODAY: str = "2026-08-01";

obj World {
    has mina: str,
        jae: str,
        made: list[any];
}

"""Two students, a desk offer from Jae, two open suggestions to Mina's requests, and mailboxes."""
def world(mina_email_on: bool = True) -> World {
    (mina, jae) = (f"mina-{uuid.uuid4()}", f"jae-{uuid.uuid4()}");
    offer = root ++> Post(
        owner_root=jae,
        kind="offer",
        category="furniture",
        title="Solid wood desk",
        price=25.0
    );
    lamp = root ++> Post(
        owner_root=jae,
        kind="offer",
        category="essentials",
        title="Desk lamp",
        price=5.0
    );
    want_desk = root ++> Post(
        owner_root=mina,
        kind="request",
        category="furniture",
        title="Need a desk",
        price=50.0
    );
    want_lamp = root ++> Post(
        owner_root=mina, kind="request", category="essentials", title="Need a lamp"
    );
    s1 = root ++> Suggestion(
        post_a=jid(offer),
        post_b=jid(want_desk),
        root_a=jae,
        root_b=mina,
        score=80,
        reasons=["$25 is within the $50 budget"],
        created_on=TODAY,
        emailed_a=True,
        seen_a=True
    );
    s2 = root ++> Suggestion(
        post_a=jid(lamp),
        post_b=jid(want_lamp),
        root_a=jae,
        root_b=mina,
        score=60,
        reasons=[],
        created_on=TODAY,
        emailed_a=True,
        seen_a=True
    );
    m1 = root ++> Mailbox(
        owner_root=mina, email="mina@umich.edu", enabled=mina_email_on
    );
    m2 = root ++> Mailbox(owner_root=jae, email="jae@umich.edu", enabled=True);
    return World(
        mina=mina, jae=jae, made=[offer, lamp, want_desk, want_lamp, s1, s2, m1, m2]
    );
}

def cleanup(w: World) {
    for n in w.made {
        del n;
    }
}

def outbox -> str {
    path = os.path.join(tempfile.mkdtemp(), "outbox.jsonl");
    os.environ["UARRIVED_EMAIL_OUTBOX"] = path;
    return path;
}

def emails(path: str) -> list[dict[str, str]] {
    if not os.path.exists(path) {
        return [];
    }
    with open(path) as f {
        return [
            json.loads(line)
            for line in f
            if line.strip()
        ];
    }
}

test "two new matches for one student arrive as one email, sent once (AE7)" {
    w = world();
    path = outbox();
    try {
        mine = pending_by_student(TODAY, root).get(w.mina, []);
        assert len(mine) == 2;
        assert w.jae not in pending_by_student(TODAY, root);
        sweep(TODAY, root);
        to_mina = [
            e
            for e in emails(path)
            if e["to"] == "mina@umich.edu"
        ];
        assert len(to_mina) == 1;
        assert "2 new matches" in to_mina[0]["subject"];
        assert "Solid wood desk" in to_mina[0]["body"]
            and "$25 is within the $50 budget" in to_mina[0]["body"];
        assert not [
            e
            for e in emails(path)
            if e["to"] == "jae@umich.edu"
        ];
        assert w.mina not in pending_by_student(TODAY, root);
        sweep(TODAY, root);
        assert len(
            [
                e
                for e in emails(path)
                if e["to"] == "mina@umich.edu"
            ]
        )
            == 1;
    } finally {
        cleanup(w);
    }
}

test "a student with email off gets nothing now and no backlog later" {
    w = world(mina_email_on=False);
    path = outbox();
    try {
        sweep(TODAY, root);
        assert not [
            e
            for e in emails(path)
            if e["to"] == "mina@umich.edu"
        ];
        assert w.mina not in pending_by_student(TODAY, root);
    } finally {
        cleanup(w);
    }
}

test "a failed send leaves the matches for the next sweep" {
    w = world();
    os.environ["UARRIVED_EMAIL_OUTBOX"] = tempfile.mkdtemp();
    try {
        sweep(TODAY, root);
        assert len(pending_by_student(TODAY, root).get(w.mina, [])) == 2;
    } finally {
        cleanup(w);
    }
}

test "matches already seen in the app, or on a done post, are not emailed" {
    w = world();
    path = outbox();
    try {
        s1 = w.made[4];
        s1.seen_b = True;
        w.made[3].done = True;
        assert pending_by_student(TODAY, root).get(w.mina, []) == [];
        sweep(TODAY, root);
        assert not [
            e
            for e in emails(path)
            if e["to"] == "mina@umich.edu"
        ];
    } finally {
        cleanup(w);
    }
}

test "the email never includes chat text and says how to turn it off" {
    w = world();
    try {
        body = digest_body(pending_by_student(TODAY, root)[w.mina]);
        assert "Turn these emails off in Profile" in body;
        assert "Need a desk" in body;
    } finally {
        cleanup(w);
    }
}

test "a verified profile gets a mailbox that follows its email setting" {
    p = Profile(umich_email=f"x-{uuid.uuid4()}@umich.edu", verified=True);
    sync_mailbox(p, root);
    mine = [
        m
        for m in [root-->][?:Mailbox]
        if m.email == p.umich_email
    ];
    assert len(mine) == 1 and mine[0].enabled;
    p.email_notifications = False;
    sync_mailbox(p, root);
    mine = [
        m
        for m in [root-->][?:Mailbox]
        if m.email == p.umich_email
    ];
    assert len(mine) == 1 and not mine[0].enabled;
    unverified = Profile(umich_email=f"y-{uuid.uuid4()}@umich.edu");
    sync_mailbox(unverified, root);
    assert not [
        m
        for m in [root-->][?:Mailbox]
        if m.email == unverified.umich_email
    ];
    del mine[0];
}

def call(client: JacTestClient, name: str, body: dict[str, any]) -> any {
    return client.post(f"/function/{name}", json=body).json()["data"]["result"];
}

def student(client: JacTestClient, email: str) {
    client.register_user(email, "password123");
    token = call(client, "start_verification", {"email": email})["dev_token"];
    assert call(client, "confirm_verification", {"token": token})["ok"];
}

test "the inbox badge counts only matches the student hasn't opened" {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    client = JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
    try {
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
        call(
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
        );
        assert call(client, "unread_suggestions", {}) == 0;
        client.login("mina@umich.edu", "password123");
        assert call(client, "unread_suggestions", {}) == 1;
        sid = call(client, "list_my_suggestions", {})[0]["id"];
        assert call(
            client, "mark_suggestions_seen", {"suggestion_ids": [sid, "not-a-real-id"]}
        )
            == 1;
        assert call(client, "unread_suggestions", {}) == 0;
    } finally {
        client.close();
    }
}
