"""Served-app tests for UMich verification (U1): real sessions, two users, dev-mode tokens."""

import os;
import tempfile;
import from jaclang.testing.testing { JacTestClient }

def served -> JacTestClient {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    return JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
}

def call(client: JacTestClient, name: str, body: dict[str, str]) -> dict[str, any] {
    return client.post(f"/function/{name}", json=body).json()["data"]["result"];
}

test "an anonymous caller cannot start verification" {
    client = served();
    try {
        resp = client.post(
            "/function/start_verification", json={"email": "mina@umich.edu"}
        );
        assert resp.status_code == 401;
    } finally {
        client.close();
    }
}

test "a non-UMich address is rejected and the student stays unverified" {
    client = served();
    try {
        client.register_user("mina@gmail.com", "password123");
        result = call(client, "start_verification", {"email": "mina@gmail.com"});
        assert not result["ok"];
        assert "umich.edu" in result["error"];
        assert not call(client, "my_verification", {})["verified"];
    } finally {
        client.close();
    }
}

test "the emailed token verifies the student exactly once" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        started = call(client, "start_verification", {"email": "Mina@UMICH.edu"});
        assert started["ok"] and started["dev_token"];
        done = call(client, "confirm_verification", {"token": started["dev_token"]});
        assert done["ok"] and done["email"] == "mina@umich.edu";
        assert call(client, "my_verification", {})["verified"];
        again = call(client, "confirm_verification", {"token": started["dev_token"]});
        assert not again["ok"];
    } finally {
        client.close();
    }
}

test "one student cannot verify with another student's token" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        token = call(client, "start_verification", {"email": "mina@umich.edu"})[
            "dev_token"
        ];
        client.register_user("jae@umich.edu", "password123");
        call(client, "start_verification", {"email": "jae@umich.edu"});
        stolen = call(client, "confirm_verification", {"token": token});
        assert not stolen["ok"];
        assert not call(client, "my_verification", {})["verified"];
    } finally {
        client.close();
    }
}

test "a made-up token is rejected" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        call(client, "start_verification", {"email": "mina@umich.edu"});
        assert not call(client, "confirm_verification", {"token": "not-a-real-token"})[
            "ok"
        ];
    } finally {
        client.close();
    }
}

test "without dev mode and without SMTP the server says email is not configured" {
    client = served();
    os.environ["UARRIVED_DEV_MODE"] = "0";
    os.environ.pop("SMTP_HOST", None);
    try {
        client.register_user("mina@umich.edu", "password123");
        result = call(client, "start_verification", {"email": "mina@umich.edu"});
        assert not result["ok"];
        assert result["dev_token"] == "";
    } finally {
        client.close();
    }
}
