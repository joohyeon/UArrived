"""Tests for the market translation wrapper (U3). The model is always MockLLM; no test calls a
real provider."""

import os;
import time;
import ai.translate;
import from jaclang.byllm.lib { MockLLM, MockError, AuthenticationError, Model }
import from ai.translate { Translation, PostText, PostTranslations, TextList }
import from market.testkit { ai_off }
import from ai.models { model_ready }
import from market.translation {
    digits_preserved,
    digit_groups,
    acceptable,
    translate_text,
    translate_texts,
    translate_post_texts,
    reader_language
}

"""Make the next translator calls return `outputs`, in order."""
def mock(outputs: list[any]) -> MockLLM {
    fake = MockLLM(outputs=outputs);
    ai.translate.translator = fake;
    return fake;
}

test "ko to en returns the mocked English, flagged AI-translated" {
    fake = mock([Translation(text="Deposit after signing, 900 dollars.")]);
    r = translate_text("보증금은 서명 후에, 900달러.", "ko", "en");
    assert r.ok and r.ai_translated;
    assert r.text == "Deposit after signing, 900 dollars." and r.language == "en";
    assert len(fake.sent("messages")) == 1;
}

test "same language and empty text make no model call and return the original" {
    fake = mock([]);
    same = translate_text("Desk $25", "en", "EN");
    assert same.ok and not same.ai_translated and same.text == "Desk $25";
    blank = translate_text("  ", "ko", "en");
    assert blank.ok and not blank.ai_translated and blank.text == "  ";
    assert len(fake.sent("messages")) == 0;
}

test "a translation that changes a number fails the guard and returns the original (AE9)" {
    source = "책상 $40, 8월 21–25일";
    mock([Translation(text="Desk $40, Sep 21–25")]);
    assert not digits_preserved(source, "Desk $40, Sep 21–25");
    r = translate_text(source, "ko", "en");
    assert not r.ok and not r.ai_translated;
    assert r.text == source and r.language == "ko";
}

test "a translation that keeps every number passes the guard" {
    assert digits_preserved("900불 이하, 8월 20일", "under $900, 8/20");
    mock([Translation(text="under $900, 8/20")]);
    r = translate_text("900불 이하, 8월 20일", "ko", "en");
    assert r.ok and r.ai_translated and r.text == "under $900, 8/20";
}

test "the guard ignores thousands commas, full-width digits and leading zeros" {
    assert digits_preserved("$1,200 월세", "$1200 rent");
    assert digits_preserved("８月 ０８:30", "Aug 8, 8:30");
    assert not digits_preserved("18시", "8 pm");
    assert digits_preserved("no numbers", "");
}

test "an English month name counts as its number" {
    assert digits_preserved("10월 25일 오후 3시", "October 25 at 3 PM");
    assert digits_preserved("8月21–25日自取", "Pick up Aug 21–25");
    assert digits_preserved("책상 $40, 8월 21–25일", "Desk $40, Aug 21–25");
    assert not digits_preserved("10월 25일", "November 25");
    assert not digits_preserved("10월 25일", "the 25th");
    assert digits_preserved("8月 20日", "20 Aug")
        and digits_preserved("10월 25일", "October 25");
}

test "a month word counts only next to a day number, never as an ordinary word" {
    assert acceptable("You may pick it up at 3pm", "오후 3시에 가져가셔도 돼요");
    assert digit_groups("You may pick it up at 3pm") == {"3"};
    assert digit_groups("march") == set() and digit_groups("may") == set();
    assert digit_groups("We may march on Monday") == set();
    assert digit_groups("Pick up Aug 21–25") == {"8", "21", "25"};
    assert "5" in digit_groups("May 5") and "12" in digit_groups("pick up 12 dec");
}

test "an AI outage returns the original with ok false, without raising" {
    ai.translate.translator = MockLLM(
        outputs=[MockError(error=AuthenticationError("no API key"))]
    );
    r = translate_text("방 구해요", "ko", "en");
    assert not r.ok and not r.ai_translated and r.text == "방 구해요";
}

test "unreadable model output returns the original with ok false" {
    mock(["not a translation", "still not", "nope", "no"]);
    r = translate_text("方 找室友", "zh", "en");
    assert not r.ok and not r.ai_translated and r.text == "方 找室友";
}

test "an empty translation of non-empty text is rejected" {
    mock([Translation(text="  ")]);
    r = translate_text("방 구해요", "ko", "en");
    assert not r.ok and r.text == "방 구해요";
}

test "a zh post is stored in zh, en and ko" {
    fake = mock(
        [
            PostTranslations(
                items=[
                    PostText(
                        language="en",
                        title="Desk, chair, lamp",
                        description="$40, pick up 8/21-8/25"
                    ),
                    PostText(
                        language="ko",
                        title="책상, 의자, 스탠드",
                        description="$40, 8월 21–25일 직접 가져가기"
                    )
                ]
            )
        ]
    );
    texts = translate_post_texts("书桌椅子台灯", "$40, 8月21–25日自取", "zh");
    assert sorted(texts.keys()) == ["en", "ko", "zh"];
    assert texts["zh"] == {"title": "书桌椅子台灯", "description": "$40, 8月21–25日自取"};
    assert texts["en"]["title"] == "Desk, chair, lamp";
    assert texts["ko"]["description"] == "$40, 8월 21–25일 직접 가져가기";
    assert len(fake.sent("messages")) == 1;
}

test "a post target that fails the guard is left out" {
    mock(
        [
            PostTranslations(
                items=[
                    PostText(
                        language="en",
                        title="Desk, chair, lamp",
                        description="$40, pick up Sep 21-25"
                    ),
                    PostText(
                        language="ko",
                        title="책상, 의자, 스탠드",
                        description="$40, 8월 21–25일 직접 가져가기"
                    )
                ]
            )
        ]
    );
    texts = translate_post_texts("书桌椅子台灯", "$40, 8月21–25日自取", "zh");
    assert sorted(texts.keys()) == ["ko", "zh"];
}

test "a post in a non-pilot language keeps its original and gains all three pilot languages" {
    mock(
        [
            PostTranslations(
                items=[
                    PostText(language="en", title="Desk", description="$20"),
                    PostText(language="ko", title="책상", description="$20"),
                    PostText(language="zh", title="书桌", description="$20"),
                    PostText(language="ja", title="机", description="$20")
                ]
            )
        ]
    );
    texts = translate_post_texts("Bureau", "20 $", "fr");
    assert sorted(texts.keys()) == ["en", "fr", "ko", "zh"];
    assert texts["fr"]["title"] == "Bureau";
}

test "a post translation outage keeps only the original" {
    ai.translate.translator = MockLLM(
        outputs=[MockError(error=AuthenticationError("no API key"))]
    );
    texts = translate_post_texts("Desk", "$25", "en");
    assert texts == {"en": {"title": "Desk", "description": "$25"}};
}

test "reader language maps anything outside the pilot set to English" {
    assert reader_language("fr") == "en";
    assert reader_language("ko") == "ko";
    assert reader_language(" ZH ") == "zh";
    assert reader_language("") == "en";
    assert reader_language(None) == "en";
}

test "the real model is ready only with an API key and AI not switched off" {
    saved = (
        os.environ.get("ANTHROPIC_API_KEY", ""),
        os.environ.get("UARRIVED_AI_OFF", "")
    );
    real = Model(model_name="claude-haiku-4-5-20251001");
    try {
        os.environ["UARRIVED_AI_OFF"] = "";
        os.environ["ANTHROPIC_API_KEY"] = "";
        assert not model_ready(real);
        os.environ["ANTHROPIC_API_KEY"] = "test-key";
        assert model_ready(real);
        os.environ["UARRIVED_AI_OFF"] = "1";
        assert not model_ready(real);
        assert not model_ready(None) and model_ready(MockLLM(outputs=[]));
    } finally {
        (os.environ["ANTHROPIC_API_KEY"], os.environ["UARRIVED_AI_OFF"]) = saved;
    }
}

test "with the real model switched off, translation keeps the original at once" {
    ai_off();
    ai.translate.translator = Model(model_name="claude-haiku-4-5-20251001");
    try {
        started = time.monotonic();
        texts = translate_post_texts("책상", "$25", "ko");
        one = translate_text("책상", "ko", "en");
        assert texts == {"ko": {"title": "책상", "description": "$25"}};
        assert not one.ok and one.text == "책상" and not one.ai_translated;
        assert time.monotonic() - started < 1.0;
    } finally {
        ai_off();
    }
}

test "a switched-off translator keeps the original without a call" {
    ai_off();
    assert translate_post_texts("Desk", "$25", "en")
        == {"en": {"title": "Desk", "description": "$25"}};
    assert not translate_text("Desk", "en", "ko").ok;
    assert [t.text for t in translate_texts(["Desk $25"], "en", "ko")] == ["Desk $25"];
}

test "a batch is one call, and each item is guarded on its own" {
    fake = mock([TextList(texts=["책상 $25", "의자 $30", ""])]);
    out = translate_texts(["Desk $25", "Chair $10", "Lamp"], "en", "ko");
    assert [t.text for t in out] == ["책상 $25", "Chair $10", "Lamp"];
    assert [t.ai_translated for t in out] == [True, False, False];
    assert len(fake.sent("messages")) == 1;
    same = translate_texts(["Desk"], "en", "en");
    assert same[0].ok and same[0].text == "Desk" and not same[0].ai_translated;
}
