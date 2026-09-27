"""The one place the marketplace translates text (R24, R26, R27).

Every AI translation passes a deterministic number guard: each digit group in the source must
appear in the translation. A failed guard, an unreadable reply or an AI outage all return the
original text with `ok` false, so readers see what the student wrote, never a wrong number.
No model is called when the translator can't run (no API key), and any translator failure
(ByLLMError or otherwise) degrades to the original: no endpoint fails because the AI is down.
"""

import re;
import from ai.translate { translate, translate_post, translator_ready }
import from core.constants { PILOT_LANGUAGES, DEFAULT_LANGUAGE }

"""A text for one reader. `ai_translated` is true only when `text` is an AI translation;
`language` is the language `text` is written in."""
obj TranslatedText {
    has text: str,
        ok: bool,
        ai_translated: bool = False,
        language: str = "";
}

"""The pilot language a reader sees: `lang` if it is in the pilot set, else English."""
def reader_language(lang: str | None) -> str {
    code = (lang or "").strip().lower();
    return code if code in PILOT_LANGUAGES else DEFAULT_LANGUAGE;
}

glob MONTHS: list[str] = [
         "jan",
         "feb",
         "mar",
         "apr",
         "may",
         "jun",
         "jul",
         "aug",
         "sep",
         "oct",
         "nov",
         "dec"
     ],
     MONTH_WORDS: set[str] = {
         "jan",
         "january",
         "feb",
         "february",
         "mar",
         "march",
         "apr",
         "april",
         "may",
         "jun",
         "june",
         "jul",
         "july",
         "aug",
         "august",
         "sep",
         "sept",
         "september",
         "oct",
         "october",
         "nov",
         "november",
         "dec",
         "december"
     };

"""Digit groups in `text` as plain numbers: thousands commas are dropped ("1,200" -> "1200"),
full-width digits and leading zeros normalise ("８" and "08" -> "8"). An English month name
counts as its number, so "10월 25일" is preserved by "October 25"."""
def digit_groups(text: str) -> set[str] {
    joined = re.sub(r"(?<=\d),(?=\d{3}(?!\d))", "", text);
    groups = {str(int(g)) for g in re.findall(r"\d+", joined)};
    for word in re.findall(r"[A-Za-z]+", text) {
        w = word.lower();
        if w in MONTH_WORDS {
            groups.add(str(MONTHS.index(w[:3]) + 1));
        }
    }
    return groups;
}

"""Whether every digit group in `source` also appears in `translated`. No AI."""
def digits_preserved(source: str, translated: str) -> bool {
    return digit_groups(source).issubset(digit_groups(translated));
}

"""Whether `translated` is an acceptable translation of `source`."""
def acceptable(source: str, translated: str) -> bool {
    if source.strip() and not translated.strip() {
        return False;
    }
    return digits_preserved(source, translated);
}

"""`text` (in `source`) for a `target` reader. Same language or empty text is returned as-is
with no model call; otherwise the AI translation if it passes the guard, else the original."""
def translate_text(text: str, source: str, target: str) -> TranslatedText {
    src = source.strip().lower();
    tgt = target.strip().lower();
    original = TranslatedText(text=text, ok=True, language=src);
    if text.strip() == "" or src == tgt {
        return original;
    }
    failed = TranslatedText(text=text, ok=False, language=src);
    if not translator_ready() {
        return failed;
    }
    try {
        out = translate(text, src, tgt).text.strip();
    } except Exception {
        return failed;
    }
    if not acceptable(text, out) {
        return failed;
    }
    return TranslatedText(text=out, ok=True, ai_translated=True, language=tgt);
}

"""A post's title and description in every pilot language: language -> {"title",
"description"}. The original is stored under `source` (even outside the pilot set); a target
whose translation fails or fails the guard is left out, so its readers see the original."""
def translate_post_texts(
    title: str, description: str, source: str
) -> dict[str, dict[str, str]] {
    src = source.strip().lower();
    texts: dict[str, dict[str, str]] = {
        src: {"title": title, "description": description}
    };
    targets = [
        lang
        for lang in PILOT_LANGUAGES
        if lang != src
    ];
    if not targets
        or (title.strip() == "" and description.strip() == "")
        or not translator_ready() {
        return texts;
    }
    try {
        got = translate_post(title, description, src, targets);
    } except Exception {
        return texts;
    }
    for item in got.items {
        lang = item.language.strip().lower();
        if lang in targets
            and lang not in texts
            and acceptable(title, item.title)
            and acceptable(description, item.description) {
            texts[lang] = {
                "title": item.title.strip(),
                "description": item.description.strip()
            };
        }
    }
    return texts;
}
