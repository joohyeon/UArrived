"""Served-app tests for the first-week journey: task list, ticking steps, marking done, XP, the AI
guide's fallback and upcoming events."""

import os;
import tempfile;
import ai.guide;
import ai.translate;
import from jaclang.testing.testing { JacTestClient }
import from journey.walkers { TaskProgress }

"""A fresh served app in dev mode with real AI off (journey/ never imports market/testkit)."""
def served -> JacTestClient {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    os.environ["UARRIVED_AI_OFF"] = "1";
    ai.guide.guide = None;
    ai.translate.translator = None;
    return JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
}

def call(client: JacTestClient, name: str, body: dict[str, any]) -> any {
    return client.post(f"/function/{name}", json=body).json()["data"]["result"];
}

def task_of(summary: dict[str, any], tid: str) -> dict[str, any] {
    return [
        v
        for v in summary["tasks"]
        if v["task"]["tid"] == tid
    ][0];
}

test "a student ticks every step, marks a task done and earns its XP" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        start = call(client, "my_journey", {});
        assert start["xp"] == 0 and start["done"] == 0 and start["total"] >= 9;
        mcard = task_of(start, "mcard");
        assert mcard["status"] == "todo";
        early = call(client, "mark_task_done", {"tid": "mcard"});
        assert not early["ok"] and "step" in early["error"];
        for i in range(len(mcard["task"]["steps"])) {
            ticked = call(client, "toggle_task_step", {"tid": "mcard", "index": i});
            assert ticked["ok"];
        }
        assert ticked["task"]["status"] == "started";
        done = call(client, "mark_task_done", {"tid": "mcard"});
        assert done["ok"] and done["task"]["status"] == "done";
        after = call(client, "my_journey", {});
        assert after["xp"] == mcard["task"]["xp"] and after["done"] == 1;
        call(client, "reopen_task", {"tid": "mcard"});
        assert call(client, "my_journey", {})["xp"] == 0;
    } finally {
        client.close();
    }
}

test "progress is per student" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        call(client, "toggle_task_step", {"tid": "tuition", "index": 0});
        client.register_user("jun@umich.edu", "password123");
        other = call(client, "my_journey", {});
        assert task_of(other, "tuition")["status"] == "todo";
    } finally {
        client.close();
    }
}

test "a domestic student doesn't get international-only tasks or their steps" {
    client = served();
    try {
        client.register_user("sam@umich.edu", "password123");
        call(client, "update_my_profile", {"changes": {"student_type": "in-state"}});
        mine = call(client, "my_journey", {});
        ids = [v["task"]["tid"] for v in mine["tasks"]];
        assert "mcard" in ids and "international_center" not in ids;
        bad = call(
            client, "toggle_task_step", {"tid": "international_center", "index": 0}
        );
        assert not bad["ok"];
        assert not call(client, "toggle_task_step", {"tid": "mcard", "index": 99})[
            "ok"
        ];
    } finally {
        client.close();
    }
}

test "without AI the guide says so and translation returns the original text" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        reply = call(
            client,
            "ask_about_task",
            {"tid": "mcard", "question": "What do I bring?", "history": []}
        );
        assert not reply["ok"] and "isn't available" in reply["text"];
        call(client, "update_my_profile", {"changes": {"preferred_language": "zh"}});
        texts = call(client, "translate_journey_texts", {"texts": ["Get your MCard"]});
        assert texts == ["Get your MCard"];
    } finally {
        client.close();
    }
}

test "upcoming events hide past events and filter by category and cost" {
    os.environ["UARRIVED_TODAY"] = "2026-10-05";
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        every = call(client, "upcoming_events", {});
        assert len(every) > 0;
        assert all([e["date_end"] >= "2026-10-05" for e in every]);
        arts = call(client, "upcoming_events", {"category": "Arts", "free_only": True});
        assert all([e["category"] == "Arts" and e["free"] for e in arts]);
    } finally {
        client.close();
        del os.environ["UARRIVED_TODAY"];
    }
}

test "onboarding can self-report a task already finished, bypassing the step check" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        blocked = call(client, "mark_task_done", {"tid": "banking"});
        assert not blocked["ok"] and "step" in blocked["error"];
        early = call(
            client, "mark_task_done", {"tid": "banking", "skip_step_check": True}
        );
        assert early["ok"] and early["task"]["status"] == "done";
        after = call(client, "my_journey", {});
        assert task_of(after, "banking")["status"] == "done";
        undone = call(client, "reopen_task", {"tid": "banking"});
        assert undone["ok"] and undone["task"]["status"] == "started";
    } finally {
        client.close();
    }
}

test "skip_step_check never bypasses task applicability" {
    client = served();
    try {
        client.register_user("sam@umich.edu", "password123");
        call(client, "update_my_profile", {"changes": {"student_type": "in-state"}});
        blocked = call(
            client,
            "mark_task_done",
            {"tid": "international_center", "skip_step_check": True}
        );
        assert not blocked["ok"];
    } finally {
        client.close();
    }
}

test "the arrival wizard's calls round-trip: fill some steps, self-report a task, finish" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        step1 = call(
            client,
            "update_my_profile",
            {"changes": {"arrival_date": "2026-08-28", "arrival_time": "15:00"}}
        );
        assert step1["ok"];
        step2 = call(
            client,
            "update_my_profile",
            {"changes": {"area": "Central Campus", "housing_status": "have-housing"}}
        );
        assert step2["ok"];
        step3 = call(
            client, "update_my_profile", {"changes": {"preferred_language": "zh"}}
        );
        assert step3["ok"] and step3["profile"]["language_chosen"];
        step4 = call(
            client, "mark_task_done", {"tid": "mcard", "skip_step_check": True}
        );
        assert step4["ok"];
        finish = call(
            client, "update_my_profile", {"changes": {"onboarding_done": True}}
        );
        assert finish["ok"] and finish["profile"]["onboarding_done"];
        mine = call(client, "get_my_profile", {});
        assert mine["arrival_date"] == "2026-08-28"
            and mine["area"] == "Central Campus";
        after = call(client, "my_journey", {});
        assert task_of(after, "mcard")["status"] == "done";
    } finally {
        client.close();
    }
}

test "skipping every step still reaches onboarding_done with nothing else changed" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        before = call(client, "get_my_profile", {});
        finish = call(
            client, "update_my_profile", {"changes": {"onboarding_done": True}}
        );
        assert finish["ok"];
        after = call(client, "get_my_profile", {});
        assert after["onboarding_done"];
        assert after["arrival_date"] == before["arrival_date"] == "";
        assert after["area"] == before["area"] == "";
        assert after["preferred_language"] == before["preferred_language"] == "en";
    } finally {
        client.close();
    }
}

test "a new student has no interests until they pick some, and a second pick overwrites the first" {
    client = served();
    try {
        client.register_user("noor@umich.edu", "password123");
        assert call(client, "has_interests", {}) is False;
        assert call(client, "my_interests", {}) == [];
        saved = call(
            client,
            "set_interests",
            {"categories": ["Arts", "Social", "Not-A-Real-Category"]}
        );
        assert saved == ["Arts", "Social"];
        assert call(client, "has_interests", {});
        assert call(client, "my_interests", {}) == ["Arts", "Social"];
        call(client, "set_interests", {"categories": ["Sports"]});
        assert call(client, "my_interests", {}) == ["Sports"];
    } finally {
        client.close();
    }
}
