"""The one place the marketplace translates text (R24, R26, R27).

Every AI translation passes a deterministic guard, in both directions: each digit group in the
source must appear in the translation, and the translation must not add digit groups, URLs,
emails or @handles the source didn't have. A failed guard, an unreadable reply or an AI outage
all return the original text with `ok` false, so readers see what the student wrote, never a
wrong number or an injected contact. No model is called when the translator is off or can't run
(no API key), and any translator failure (provider timeout, 5xx, connection error, bad output)
degrades to the original and is logged once by type: no endpoint fails because the AI is down.
"""

import re;
import sys;
import from ai.translate {
    translate,
    translate_post,
    translate_batch,
    translator_ready
}
import from core.constants { PILOT_LANGUAGES, DEFAULT_LANGUAGE }
import from core.profile { Profile }

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

"""The language a student reads posts in: their profile language if it is a pilot language,
else English."""
def reader_of(profile: Profile | None) -> str {
    return reader_language(profile.preferred_language if profile is not None else None);
}

"""A well-formed language code (2-3 letters, lower-cased), or `fallback`."""
def language_code(value: str, fallback: str) -> str {
    code = value.strip().lower();
    return code if re.fullmatch(r"[a-z]{2,3}", code) else fallback;
}

"""The language a student writes in (non-AI draft cards, posts without a draft language): their
profile language if well-formed, else English."""
def profile_language(profile: Profile | None) -> str {
    if profile is None {
        return DEFAULT_LANGUAGE;
    }
    return language_code(profile.preferred_language, DEFAULT_LANGUAGE);
}

"""English month words, by month number: an English month name counts as its number in
`digit_groups`, so a date written "Aug 20" matches "8월 20일"."""
glob MONTH_NUMBERS: dict[str, int] = {
         "jan": 1,
         "january": 1,
         "feb": 2,
         "february": 2,
         "mar": 3,
         "march": 3,
         "apr": 4,
         "april": 4,
         "may": 5,
         "jun": 6,
         "june": 6,
         "jul": 7,
         "july": 7,
         "aug": 8,
         "august": 8,
         "sep": 9,
         "sept": 9,
         "september": 9,
         "oct": 10,
         "october": 10,
         "nov": 11,
         "november": 11,
         "dec": 12,
         "december": 12
     };

"""Digit groups in `text` as plain numbers: thousands commas are dropped ("1,200" -> "1200"),
full-width digits and leading zeros normalise ("８" and "08" -> "8"). An English month name
counts as its number only next to a 1-2 digit day ("Aug 20", "20 Aug"), so "10월 25일" is preserved by "October 25"."""
def digit_groups(text: str) -> set[str] {
    joined = re.sub(r"(?<=\d),(?=\d{3}(?!\d))", "", text);
    groups = {str(int(g)) for g in re.findall(r"\d+", joined)};
    names = "|".join(sorted(MONTH_NUMBERS.keys(), key=len, reverse=True));
    before = rf"(?<![A-Za-z])({names})\.?\s*(?<!\d)\d{{1,2}}(?!\d)";
    after = rf"(?<!\d)\d{{1,2}}(?:st|nd|rd|th)?\s+({names})(?![A-Za-z])";
    for pattern in [before, after] {
        for hit in re.finditer(pattern, text, re.IGNORECASE) {
            groups.add(str(MONTH_NUMBERS[hit.group(1).lower()]));
        }
    }
    return groups;
}

"""Whether every digit group in `source` also appears in `translated`. No AI."""
def digits_preserved(source: str, translated: str) -> bool {
    return digit_groups(source).issubset(digit_groups(translated));
}

"""Whether `translated` adds no digit group the `source` lacks. A lone "0" is ignored so a
translation may write minutes ("3:00 PM" for "오후 3시"). No AI."""
def no_new_digits(source: str, translated: str) -> bool {
    return (digit_groups(translated) - digit_groups(source) - {"0"}) == set();
}

glob CONTACT_PATTERN: str = r"https?://\S+|www\.\S+|[\w.+-]+@[\w-]+(?:\.[\w-]+)+|(?<![\w.@])@\w{2,}|\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:com|net|org|io|co|edu|kr|cn|me|ly|app|xyz|info|us)\b";

"""URLs, emails and @handles in `text`, lower-cased, without trailing punctuation."""
def contact_tokens(text: str) -> set[str] {
    return {
        h.group(0).lower().rstrip(".,;:!?)]}'\"")
        for h in re.finditer(CONTACT_PATTERN, text, re.IGNORECASE)
    };
}

"""Whether `translated` introduces no URL, email or @handle absent from `source`. No AI."""
def no_new_contacts(source: str, translated: str) -> bool {
    return contact_tokens(translated).issubset(contact_tokens(source));
}

"""Whether `translated` is an acceptable translation of `source`: not empty, every source number
kept, and no number, URL, email or @handle added."""
def acceptable(source: str, translated: str) -> bool {
    if source.strip() and not translated.strip() {
        return False;
    }
    return digits_preserved(source, translated)
        and no_new_digits(source, translated)
        and no_new_contacts(source, translated);
}

"""Log that an AI call failed, by exception type only (never the student's text or a key); the
caller then falls back to the original."""
def note_ai_failure(where: str, err: Exception) {
    print(f"AI call failed in {where}: {type(err).__name__}", file=sys.stderr);
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
    } except Exception as err {
        note_ai_failure("translate_text", err);
        return failed;
    }
    if not acceptable(text, out) {
        return failed;
    }
    return TranslatedText(text=out, ok=True, ai_translated=True, language=tgt);
}

"""Several `texts` (in `source`) for a `target` reader, in one model call. Each item is guarded
on its own, exactly like `translate_text`: an item whose translation is missing, empty or fails
the number guard keeps its original text with `ok` false."""
def translate_texts(
    texts: list[str], source: str, target: str
) -> list[TranslatedText] {
    src = source.strip().lower();
    tgt = target.strip().lower();
    if src == tgt or all([t.strip() == "" for t in texts]) {
        return [TranslatedText(text=t, ok=True, language=src) for t in texts];
    }
    failed = [TranslatedText(text=t, ok=t.strip() == "", language=src) for t in texts];
    if not translator_ready() {
        return failed;
    }
    try {
        got = translate_batch(texts, src, tgt).texts;
    } except Exception as err {
        note_ai_failure("translate_texts", err);
        return failed;
    }
    out: list[TranslatedText] = [];
    for (i, text) in enumerate(texts) {
        candidate = got[i].strip() if i < len(got) else "";
        if text.strip() and acceptable(text, candidate) {
            out.append(
                TranslatedText(
                    text=candidate, ok=True, ai_translated=True, language=tgt
                )
            );
        } else {
            out.append(failed[i]);
        }
    }
    return out;
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
    } except Exception as err {
        note_ai_failure("translate_post_texts", err);
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
