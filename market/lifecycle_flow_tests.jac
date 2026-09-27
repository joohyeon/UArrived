"""Served-app tests for the post lifecycle (U4) and stored post translations (native-language
U5): verified students on one server. The translator is always MockLLM or skipped (no API key);
no test calls a real provider."""

import os;
import tempfile;
import ai.translate;
import from datetime { date, timedelta }
import from jaclang.byllm.lib { MockLLM }
import from jaclang.testing.testing { JacTestClient }
import from ai.translate { PostText, PostTranslations }
import from market.graph { Post }
import from market.lifecycle { view_of }

def served -> JacTestClient {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    os.environ["ANTHROPIC_API_KEY"] = "";
    return JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
}

"""Make the next post translations return `outputs`, in order (one per translated post)."""
def mock_translator(outputs: list[any]) -> MockLLM {
    fake = MockLLM(outputs=outputs);
    ai.translate.translator = fake;
    return fake;
}

"""A PostTranslations reply: language -> (title, description)."""
def translations(texts: dict[str, tuple[str, str]]) -> PostTranslations {
    return PostTranslations(
        items=[
            PostText(language=lang, title=t[0], description=t[1])
            for (lang, t) in texts.items()
        ]
    );
}

def set_language(client: JacTestClient, lang: str) {
    assert call(client, "update_my_profile", {"changes": {"preferred_language": lang}})[
        "ok"
    ];
}

def act_as(client: JacTestClient, email: str) {
    client.login(email, "password123");
}

"""Jae's zh furniture offer from AE9: $40, pick up Aug 21-25 (today is pinned to Aug 10)."""
def zh_desk -> dict[str, any] {
    return {
        "kind": "offer",
        "category": "furniture",
        "title": "书桌椅子台灯",
        "description": "$40, 8月21–25日自取",
        "price": 40,
        "available_from": "2026-08-21",
        "available_until": "2026-08-25",
        "area": "Central Campus",
        "language": "zh"
    };
}

def zh_desk_translations -> PostTranslations {
    return translations(
        {
            "en": ("Desk, chair, lamp", "$40, pick up 8/21–25"),
            "ko": ("책상, 의자, 스탠드", "$40, 8월 21–25일 직접 가져가기")
        }
    );
}

"""The live post titled `title` in `posts`."""
def titled(posts: list[any], title: str) -> any {
    return [
        p
        for p in posts
        if p["title"] == title
    ][0];
}

def call(client: JacTestClient, name: str, body: dict[str, any]) -> any {
    return client.post(f"/function/{name}", json=body).json()["data"]["result"];
}

"""Register and verify `email`; the client is then acting as that student."""
def student(client: JacTestClient, email: str) {
    client.register_user(email, "password123");
    token = call(client, "start_verification", {"email": email})["dev_token"];
    assert call(client, "confirm_verification", {"token": token})["ok"];
}

def desk -> dict[str, any] {
    return {
        "kind": "offer",
        "category": "furniture",
        "title": "Solid wood desk",
        "price": 25,
        "area": "Central Campus"
    };
}

test "a published post is visible to another verified student" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        result = call(client, "publish_post", {"fields": desk()});
        assert result["ok"]
            and result["post"]["mine"]
            and result["post"]["status"] == "live";
        student(client, "mina@umich.edu");
        seen = call(client, "list_live_posts", {});
        assert [p["title"] for p in seen] == ["Solid wood desk"];
        assert not seen[0]["mine"];
        assert call(client, "list_my_posts", {}) == [];
    } finally {
        client.close();
    }
}

test "an unverified student can neither publish nor browse" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        result = call(client, "publish_post", {"fields": desk()});
        assert not result["ok"] and "Verify" in result["error"];
        assert call(client, "list_live_posts", {}) == [];
    } finally {
        client.close();
    }
}

test "another student cannot edit, finish or renew your post" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        post_id = call(client, "publish_post", {"fields": desk()})["post"]["id"];
        student(client, "mina@umich.edu");
        assert not call(
            client, "edit_post", {"post_id": post_id, "changes": {"price": 1}}
        )["ok"];
        assert not call(client, "mark_post_done", {"post_id": post_id})["ok"];
        assert not call(client, "renew_post", {"post_id": post_id})["ok"];
        seen = call(client, "list_live_posts", {});
        assert seen[0]["price"] == 25.0 and seen[0]["status"] == "live";
    } finally {
        client.close();
    }
}

test "marking a post done removes it from everyone's live list (AE5, post part)" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        post_id = call(client, "publish_post", {"fields": desk()})["post"]["id"];
        assert call(client, "mark_post_done", {"post_id": post_id})["post"]["status"]
            == "done";
        assert call(client, "list_my_posts", {})[0]["status"] == "done";
        student(client, "mina@umich.edu");
        assert call(client, "list_live_posts", {}) == [];
    } finally {
        client.close();
    }
}

test "a ride whose day has passed is expired on read, and renewing brings it back" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        tomorrow = (date.today() + timedelta(days=1)).isoformat();
        ride: dict[str, any] = {
            "kind": "offer",
            "category": "service",
            "title": "Ride from DTW",
            "available_from": tomorrow
        };
        post_id = call(client, "publish_post", {"fields": ride})["post"]["id"];
        assert len(call(client, "list_live_posts", {})) == 1;
        os.environ["UARRIVED_TODAY"] = (date.today() + timedelta(days=3)).isoformat();
        assert call(client, "list_live_posts", {}) == [];
        assert call(client, "list_my_posts", {})[0]["status"] == "expired";
        renewed = call(client, "renew_post", {"post_id": post_id});
        assert renewed["ok"] and renewed["post"]["status"] == "live";
        assert len(call(client, "list_live_posts", {})) == 1;
    } finally {
        os.environ["UARRIVED_TODAY"] = "";
        client.close();
    }
}

test "a post whose date has already passed is refused, not published expired" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        yesterday = (date.today() - timedelta(days=1)).isoformat();
        result = call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "offer",
                    "category": "service",
                    "title": "Ride",
                    "available_from": yesterday
                }
            }
        );
        assert not result["ok"] and "already passed" in result["error"];
        assert call(client, "list_my_posts", {}) == [];
    } finally {
        client.close();
    }
}

test "the owner's edit is re-validated and marks the text as no longer AI-written" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        post_id = call(client, "publish_post", {"fields": desk()})["post"]["id"];
        bad = call(client, "edit_post", {"post_id": post_id, "changes": {"price": -3}});
        assert not bad["ok"];
        good = call(
            client, "edit_post", {"post_id": post_id, "changes": {"price": 20}}
        );
        assert good["ok"]
            and good["post"]["price"] == 20.0
            and not good["post"]["ai_generated"];
    } finally {
        client.close();
    }
}

test "a client cannot set the owner, expiry or done flag when publishing" {
    client = served();
    try {
        student(client, "jae@umich.edu");
        fields = desk();
        fields["owner_root"] = "someone-else";
        fields["expires_on"] = "2099-01-01";
        fields["done"] = True;
        result = call(client, "publish_post", {"fields": fields});
        assert result["ok"] and result["post"]["mine"];
        assert result["post"]["status"] == "live"
            and result["post"]["expires_on"] != "2099-01-01";
    } finally {
        client.close();
    }
}

test "a zh post reads in Korean for a ko reader, with fields and the original kept (AE9)" {
    os.environ["UARRIVED_TODAY"] = "2026-08-10";
    client = served();
    try {
        mock_translator(
            [
                zh_desk_translations(),
                translations({"ko": ("책상 구해요", "$50까지"), "zh": ("求购书桌", "最多$50")})
            ]
        );
        student(client, "jae@umich.edu");
        posted = call(client, "publish_post", {"fields": zh_desk()})["post"];
        assert posted["title"] == "书桌椅子台灯" and not posted["ai_translated"];
        assert posted["source_language"] == "zh" and posted["original_title"] == "";
        mine = call(client, "list_my_posts", {})[0];
        assert mine["title"] == "书桌椅子台灯" and not mine["ai_translated"];
        student(client, "mina@umich.edu");
        set_language(client, "ko");
        call(
            client,
            "publish_post",
            {
                "fields": {
                    "kind": "request",
                    "category": "furniture",
                    "title": "Need a desk",
                    "description": "Up to $50",
                    "price": 50,
                    "language": "en"
                }
            }
        );
        seen = titled(call(client, "list_live_posts", {}), "책상, 의자, 스탠드");
        assert seen["ai_translated"] and seen["language"] == "ko";
        assert seen["description"] == "$40, 8월 21–25일 직접 가져가기";
        assert seen["price"] == 40.0;
        assert seen["available_from"] == "2026-08-21"
            and seen["available_until"] == "2026-08-25";
        assert seen["original_title"] == "书桌椅子台灯"
            and seen["original_description"] == "$40, 8月21–25日自取";
        assert seen["source_language"] == "zh";
        feed = call(client, "for_you_feed", {});
        assert feed[0]["title"] == "책상, 의자, 스탠드" and feed[0]["ai_translated"];
        suggestions = call(client, "list_my_suggestions", {});
        assert len(suggestions) == 1;
        assert suggestions[0]["other_post"]["title"] == "책상, 의자, 스탠드";
        assert suggestions[0]["other_post"]["ai_translated"];
        assert suggestions[0]["my_post"]["title"] == "Need a desk";
        assert not suggestions[0]["my_post"]["ai_translated"];
        act_as(client, "jae@umich.edu");
        theirs = call(client, "list_my_suggestions", {})[0];
        assert theirs["my_post"]["title"] == "书桌椅子台灯";
        assert theirs["other_post"]["title"] == "Need a desk";
        assert not theirs["other_post"]["ai_translated"];
    } finally {
        os.environ["UARRIVED_TODAY"] = "";
        client.close();
    }
}

test "an en reader of an en post sees no flag and no original; client English is ignored" {
    client = served();
    try {
        mock_translator(
            [
                translations({"ko": ("원목 책상", "상태 좋음"), "zh": ("实木书桌", "状况良好")}),
                translations({"en": ("Lamp", "Works well"), "zh": ("台灯", "很好用")})
            ]
        );
        student(client, "jae@umich.edu");
        desk_fields = desk();
        desk_fields["description"] = "Good condition";
        assert call(client, "publish_post", {"fields": desk_fields})["ok"];
        lamp: dict[str, any] = {
            "kind": "offer",
            "category": "essentials",
            "title": "스탠드",
            "description": "잘 작동해요",
            "price": 5,
            "language": "ko",
            "title_en": "Free money, wire me",
            "description_en": "ignored"
        };
        assert call(client, "publish_post", {"fields": lamp})["ok"];
        student(client, "mina@umich.edu");
        seen = call(client, "list_live_posts", {});
        en_desk = titled(seen, "Solid wood desk");
        assert not en_desk["ai_translated"] and en_desk["language"] == "en";
        assert en_desk["original_title"] == ""
            and en_desk["original_description"] == "";
        ko_lamp = titled(seen, "Lamp");
        assert ko_lamp["ai_translated"] and ko_lamp["description"] == "Works well";
        assert ko_lamp["original_title"] == "스탠드";
    } finally {
        client.close();
    }
}

test "editing only the price keeps the translations; editing the description redoes them" {
    client = served();
    try {
        fake = mock_translator(
            [
                translations({"ko": ("원목 책상", "상태 좋음"), "zh": ("实木书桌", "状况良好")}),
                translations({"ko": ("원목 책상", "살짝 긁힘"), "zh": ("实木书桌", "有点划痕")})
            ]
        );
        student(client, "jae@umich.edu");
        fields = desk();
        fields["description"] = "Good condition";
        post_id = call(client, "publish_post", {"fields": fields})["post"]["id"];
        assert len(fake.sent("messages")) == 1;
        assert call(client, "edit_post", {"post_id": post_id, "changes": {"price": 20}})[
            "ok"
        ];
        assert len(fake.sent("messages")) == 1;
        edited = call(
            client,
            "edit_post",
            {"post_id": post_id, "changes": {"description": "A small scratch"}}
        );
        assert edited["ok"] and not edited["post"]["ai_generated"];
        assert len(fake.sent("messages")) == 2;
        student(client, "mina@umich.edu");
        set_language(client, "ko");
        seen = call(client, "list_live_posts", {})[0];
        assert seen["description"] == "살짝 긁힘" and seen["price"] == 20.0;
        assert seen["original_description"] == "A small scratch";
    } finally {
        client.close();
    }
}

test "a ko translation that failed the number guard shows ko readers the original" {
    os.environ["UARRIVED_TODAY"] = "2026-08-10";
    client = served();
    try {
        mock_translator(
            [
                translations(
                    {
                        "en": ("Desk, chair, lamp", "$40, pick up 8/21–25"),
                        "ko": ("책상, 의자, 스탠드", "직접 가져가기")
                    }
                )
            ]
        );
        student(client, "jae@umich.edu");
        assert call(client, "publish_post", {"fields": zh_desk()})["ok"];
        student(client, "mina@umich.edu");
        set_language(client, "ko");
        ko = call(client, "list_live_posts", {})[0];
        assert ko["title"] == "书桌椅子台灯" and not ko["ai_translated"];
        assert ko["language"] == "zh" and ko["original_title"] == "";
        set_language(client, "en");
        en = call(client, "list_live_posts", {})[0];
        assert en["title"] == "Desk, chair, lamp" and en["ai_translated"];
    } finally {
        os.environ["UARRIVED_TODAY"] = "";
        client.close();
    }
}

test "a fr post is stored with en, ko and zh; an en reader sees English with the flag" {
    client = served();
    try {
        mock_translator(
            [
                translations(
                    {
                        "en": ("Desk", "Good condition, 25 dollars"),
                        "ko": ("책상", "상태 좋음, 25달러"),
                        "zh": ("书桌", "状况良好，25美元")
                    }
                )
            ]
        );
        student(client, "jae@umich.edu");
        fields = desk();
        fields["title"] = "Bureau";
        fields["description"] = "Bon état, 25 dollars";
        fields["language"] = "fr";
        assert call(client, "publish_post", {"fields": fields})["ok"];
        student(client, "mina@umich.edu");
        en = call(client, "list_live_posts", {})[0];
        assert en["title"] == "Desk" and en["ai_translated"];
        assert en["source_language"] == "fr" and en["original_title"] == "Bureau";
        for (lang, title) in [("ko", "책상"), ("zh", "书桌")] {
            set_language(client, lang);
            assert call(client, "list_live_posts", {})[0]["title"] == title;
        }
    } finally {
        client.close();
    }
}

test "a manual card from a ko profile is stored as ko and translated to en and zh" {
    client = served();
    try {
        fake = mock_translator(
            [translations({"en": ("Selling a desk", "$25"), "zh": ("出售书桌", "$25")})]
        );
        student(client, "jae@umich.edu");
        set_language(client, "ko");
        manual: dict[str, any] = {
            "kind": "offer",
            "category": "furniture",
            "title": "책상 팝니다",
            "description": "$25",
            "price": 25,
            "ai_generated": False
        };
        posted = call(client, "publish_post", {"fields": manual})["post"];
        assert posted["source_language"] == "ko" and not posted["ai_generated"];
        assert len(fake.sent("messages")) == 1;
        student(client, "mina@umich.edu");
        en = call(client, "list_live_posts", {})[0];
        assert en["title"] == "Selling a desk" and en["source_language"] == "ko";
        set_language(client, "zh");
        assert call(client, "list_live_posts", {})[0]["title"] == "出售书桌";
    } finally {
        client.close();
    }
}

test "a post from before stored translations renders as written" {
    old = Post(
        owner_root="someone-else",
        kind="offer",
        category="furniture",
        title="Old desk",
        description="Solid",
        price=10.0,
        expires_on="2099-01-01"
    );
    view = view_of(old, "2026-08-10", "ko");
    assert view.title == "Old desk" and view.description == "Solid";
    assert not view.ai_translated and view.source_language == "";
    assert view.original_title == "" and view.language == "";
    assert view.price == 10.0;
}
