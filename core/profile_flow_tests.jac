"""Served-app tests for the shared student profile (U2)."""

import os;
import tempfile;
import uuid;
import from jaclang.testing.testing { JacTestClient }
import from core.profile {
    Mailbox,
    Profile,
    default_language_from,
    set_language,
    sync_mailbox
}

def served -> JacTestClient {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    return JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
}

def call(client: JacTestClient, name: str, body: dict[str, any]) -> dict[str, any] {
    return client.post(f"/function/{name}", json=body).json()["data"]["result"];
}

def verify(client: JacTestClient, email: str) {
    token = call(client, "start_verification", {"email": email})["dev_token"];
    call(client, "confirm_verification", {"token": token});
}

test "journey fields round-trip through update and read" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        result = call(
            client,
            "update_my_profile",
            {
                "changes": {
                    "arrival_date": "2026-08-20",
                    "arrival_time": "15:00",
                    "housing_status": "have-housing",
                    "area": "North Campus",
                    "needs_airport_ride": True
                }
            }
        );
        assert result["ok"];
        mine = call(client, "get_my_profile", {});
        assert mine["arrival_date"] == "2026-08-20" and mine["arrival_time"] == "15:00";
        assert mine["area"] == "North Campus" and mine["needs_airport_ride"];
        assert mine["move_in_date"] == "" and mine["student_type"] == "";
    } finally {
        client.close();
    }
}

test "an invalid value is rejected and nothing is changed" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        call(client, "update_my_profile", {"changes": {"area": "Kerrytown"}});
        bad = call(
            client,
            "update_my_profile",
            {"changes": {"area": "Detroit", "display_name": "Mina"}}
        );
        assert not bad["ok"] and "Area" in bad["error"];
        mine = call(client, "get_my_profile", {});
        assert mine["area"] == "Kerrytown" and mine["display_name"] == "";
    } finally {
        client.close();
    }
}

test "a student cannot make themselves verified or a moderator" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        resp = client.post(
            "/function/update_my_profile",
            json={
                "changes": {
                    "verified": True,
                    "is_moderator": True,
                    "umich_email": "x@umich.edu"
                }
            }
        );
        mine = call(client, "get_my_profile", {});
        assert not mine["verified"]
            and not mine["is_moderator"]
            and mine["umich_email"] == "";
    } finally {
        client.close();
    }
}

test "a wrongly typed value is rejected" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        assert not call(client, "update_my_profile", {"changes": {"area": 5}})["ok"];
        assert not call(
            client, "update_my_profile", {"changes": {"has_us_bank": "yes"}}
        )["ok"];
    } finally {
        client.close();
    }
}

test "one student's profile is invisible to another" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        call(
            client,
            "update_my_profile",
            {"changes": {"display_name": "Mina", "area": "Kerrytown"}}
        );
        client.register_user("jae@umich.edu", "password123");
        theirs = call(client, "get_my_profile", {});
        assert theirs["display_name"] == "" and theirs["area"] == "";
    } finally {
        client.close();
    }
}

test "only a verified student listed in UARRIVED_MODERATORS is a moderator" {
    client = served();
    os.environ["UARRIVED_MODERATORS"] = "Mod@umich.edu, other@umich.edu";
    try {
        client.register_user("mod@umich.edu", "password123");
        assert not call(client, "get_my_profile", {})["is_moderator"];
        verify(client, "mod@umich.edu");
        assert call(client, "get_my_profile", {})["is_moderator"];
        client.register_user("mina@umich.edu", "password123");
        verify(client, "mina@umich.edu");
        assert not call(client, "get_my_profile", {})["is_moderator"];
    } finally {
        os.environ["UARRIVED_MODERATORS"] = "";
        client.close();
    }
}

test "only a pilot language can be chosen, and choosing one marks it chosen (R29)" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        fresh = call(client, "get_my_profile", {});
        assert fresh["preferred_language"] == "en" and not fresh["language_chosen"];
        bad = call(
            client, "update_my_profile", {"changes": {"preferred_language": "xx"}}
        );
        assert not bad["ok"] and "Language" in bad["error"];
        mine = call(client, "get_my_profile", {});
        assert mine["preferred_language"] == "en" and not mine["language_chosen"];
        good = call(
            client, "update_my_profile", {"changes": {"preferred_language": "zh"}}
        );
        assert good["ok"];
        assert good["profile"]["preferred_language"] == "zh"
            and good["profile"]["language_chosen"];
    } finally {
        client.close();
    }
}

"""The Mailbox for `p` on the test root (plain tests: the commons is the test's own root)."""
def box_of(p: Profile) -> Mailbox {
    found = [
        m
        for m in [root-->][?:Mailbox]
        if m.email == p.umich_email
    ];
    assert len(found) == 1;
    return found[0];
}

test "a first message's language becomes the default only until the student chooses one" {
    p = Profile();
    assert default_language_from("ko", p, root);
    assert p.preferred_language == "ko" and not p.language_chosen;
    assert not default_language_from("fr", p, root);
    assert p.preferred_language == "ko";
    chose = Profile(preferred_language="en", language_chosen=True);
    assert not default_language_from("ko", chose, root);
    assert chose.preferred_language == "en";
}

test "the first-message default applies once, even when the first message needs no change" {
    p = Profile();
    assert default_language_from("ko", p, root) and p.language_defaulted;
    assert not default_language_from("zh", p, root);
    assert p.preferred_language == "ko";
    same = Profile();
    assert not default_language_from("en", same, root) and same.language_defaulted;
    assert not default_language_from("ko", same, root);
    assert same.preferred_language == "en";
    chose = Profile();
    set_language(chose, "zh", True, root);
    assert chose.language_defaulted;
}

test "the mailbox language follows every language change" {
    p = Profile(umich_email=f"lang-{uuid.uuid4()}@umich.edu", verified=True);
    sync_mailbox(p, root);
    assert box_of(p).language == "en";
    default_language_from("ko", p, root);
    assert box_of(p).language == "ko";
    set_language(p, "zh", True, root);
    assert box_of(p).language == "zh" and p.language_chosen;
    default_language_from("en", p, root);
    assert box_of(p).language == "zh";
}
