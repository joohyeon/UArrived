"""AI phrasing for "Help me decide" (U10, R14, F3).

The facts, missing information and risk flags are computed by rules in market/decide.jac; the
model only turns them into short plain-language notes and questions to ask. It never judges
whether a post is safe or legitimate, and market/decide.jac filters any output that tries.
The model is `advisor`, a module glob so tests can swap in MockLLM, or None to switch it off.
"""

import from jaclang.byllm.lib { Model }
import from ai.models { model_ready }

glob advisor: any = Model(model_name="claude-haiku-4-5-20251001");

"""Whether an advisor call can be made (see ai/models.jac `model_ready`)."""
def advisor_ready -> bool {
    return model_ready(advisor);
}

obj DecideNotes {
    has questions: list[str] = [],
        risk_notes: list[str] = [];
}

sem DecideNotes.questions = "Up to 5 short, specific questions the student should ask the posters before meeting or paying, based only on the missing information and flags given.";
sem DecideNotes.risk_notes = "Up to 3 short sentences explaining the given risk flags in plain language. Never say a post is safe, legitimate, verified or trustworthy.";

sem advise = "Help an international student compare marketplace posts. Use only the facts, missing information and risk flags provided. Do not invent facts about the posts.";
sem advise.summary = "The posts' facts, what each is missing, and the rule-based risk flags.";

def advise(summary: str) -> DecideNotes by advisor();
