"""AI help on the journey screens: "Ask about this task" and translating task and event text into
the student's language. Everything returned here is shown with an AI-generated / Translated by AI
label, and none of it feeds the rules in journey/walkers.jac.

When the model is unavailable (no API key, AI switched off, or an error) the guide says so and
translation returns the English originals, so the journey always works without AI.
"""

import from ai.guide { answer_task_question, guide_ready }
import from ai.translate { translate_batch, translator_ready }
import from core.profile { my_profile }
import from core.constants { PILOT_LANGUAGES }
import from journey.task_data { JourneyTask, task_by_id }
import from journey.walkers { applies }

glob MAX_QUESTION: int = 500,
     MAX_TRANSLATE: int = 120,
     UNAVAILABLE: str = "The AI guide isn't available right now. The official page and the International Center can answer this.",
     # (target language, English text) -> translation. Task and event text is the same for everyone.
     _translations: dict[str, str] = {};

obj GuideReply {
    has ok: bool,
        text: str;
}

"""The task's official details, as the model's only source."""
def task_info(t: JourneyTask) -> str {
    lines = [
        "Task: " + t.title + (" (required)" if t.required else " (optional)"),
        "Overview: " + t.description,
        "What to bring: " + "; ".join(t.bring),
        "Steps: " + "; ".join(t.steps),
        "Notes: " + "; ".join(t.notes),
        "Cost: " + (t.cost or "not listed"),
        "Official links: " + " ".join(t.links)
    ];
    for p in t.places {
        lines.append(
            "Place: "
                + p.name
                + ", "
                + p.address
                + ", hours: "
                + (p.hours or "not listed")
        );
        if p.bring {
            lines.append("  Bring here: " + "; ".join(p.bring));
        }
        if p.notes {
            lines.append("  Notes here: " + "; ".join(p.notes));
        }
    }
    return "\n".join(lines);
}

"""Ask the AI guide about one of the caller's tasks. `history` is the chat so far, oldest first,
as {"role": "user" | "guide", "text": ...}."""
def:protect ask_about_task(
    tid: str, question: str, history: list[dict[str, str]]
) -> GuideReply {
    t = task_by_id(tid);
    profile = my_profile();
    q = question.strip()[:MAX_QUESTION];
    if t is None or not applies(t, profile.student_type) or not q {
        return GuideReply(ok=False, text="Ask a question about one of your tasks.");
    }
    if not guide_ready() {
        return GuideReply(ok=False, text=UNAVAILABLE);
    }
    transcript = "\n".join(
        [
            ("Student: " if turn.get("role") == "user" else "Guide: ")
                + str(turn.get("text", ""))[:MAX_QUESTION] for turn in history[-10:]
        ]
    );
    try {
        answer = answer_task_question(
            task_info(t), transcript, q, profile.preferred_language or "en"
        );
        return GuideReply(ok=True, text=answer.text);
    } except Exception as err {
        print("ask_about_task failed: " + str(err));
        return GuideReply(ok=False, text=UNAVAILABLE);
    }
}

"""Translate English journey text into the caller's language, in order. Untranslated items (English
readers, AI unavailable, a failed or mis-sized batch) come back unchanged."""
def:protect translate_journey_texts(texts: list[str]) -> list[str] {
    lang = my_profile().preferred_language or "en";
    items = [str(x) for x in texts[:MAX_TRANSLATE]];
    if lang == "en" or lang not in PILOT_LANGUAGES or not translator_ready() {
        return items;
    }
    todo: list[str] = [];
    for x in items {
        if x.strip() and (lang + "|" + x) not in _translations and x not in todo {
            todo.append(x);
        }
    }
    for start in range(0, len(todo), 40) {
        chunk = todo[start:start + 40];
        try {
            got = translate_batch(chunk, "en", lang).texts;
        } except Exception as err {
            print("translate_journey_texts failed: " + str(err));
            break;
        }
        if len(got) != len(chunk) {
            continue;
        }
        for (src, out) in zip(chunk, got) {
            _translations[lang + "|" + src] = str(out);
        }
    }
    return [_translations.get(lang + "|" + x, x) for x in items];
}
