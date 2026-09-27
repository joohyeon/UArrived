"""AI task guide for the first-week journey: answers a student's follow-up question about one task
("what do I bring?", "how do I get there?"), grounded in that task's official details.

Explains only. It never decides whether a task applies or is done (journey/walkers.jac does), and
every answer is labeled AI-generated in the UI. The model is `guide`, a module glob so tests can
swap in MockLLM, or None to switch it off.
"""

import from jaclang.byllm.lib { Model }
import from ai.models { model_ready }

glob guide: any = Model(
         model_name="claude-haiku-4-5-20251001",
         call_params={"timeout": 20.0, "num_retries": 1}
     );

"""Whether a guide call can be made (see ai/models.jac `model_ready`)."""
def guide_ready -> bool {
    return model_ready(guide);
}

obj GuideAnswer {
    has text: str;
}

sem GuideAnswer.text = "The answer only: plain text, 2-6 short sentences or a short list, no markdown.";

sem answer_task_question = "You are a friendly orientation guide for newly arrived students at the University of Michigan, Ann Arbor. Answer the student's question about the task described in task_info. Ground the answer in task_info first; add general, widely known guidance only when it helps, and say when something should be confirmed with the International Center or the official page listed. Never invent phone numbers, prices, deadlines or office hours that are not in task_info. Use plain, simple wording suitable for non-native speakers.";
sem answer_task_question.task_info = "The task's official details: title, places, addresses, hours, cost, what to bring, steps, notes and official links.";
sem answer_task_question.transcript = "Earlier messages in this chat, oldest first. May be empty.";
sem answer_task_question.question = "The student's new question.";
sem answer_task_question.language = "Language code to answer in, for example 'en', 'zh', 'ko'.";

def answer_task_question(
    task_info: str, transcript: str, question: str, language: str
) -> GuideAnswer by guide();
