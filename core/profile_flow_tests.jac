"""Served-app tests for the shared student profile (U2)."""

import os;
import tempfile;
import from jaclang.testing.testing { JacTestClient }

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
