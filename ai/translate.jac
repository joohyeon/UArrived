"""AI translation for the native-language marketplace (R22, R26, R27).

Knows nothing about the graph or the marketplace; `market/translation.jac` checks every result
with a deterministic number guard and falls back to the original text. The model is
`translator`, a module glob so tests can swap in MockLLM, or None to switch translation off.
"""

import from jaclang.byllm.lib { Model }
import from ai.models { model_ready }

glob translator: any = Model(
         model_name="claude-haiku-4-5-20251001",
         call_params={"timeout": 20.0, "num_retries": 1}
     );

"""Whether a translation call can be made (see ai/models.jac `model_ready`)."""
def translator_ready -> bool {
    return model_ready(translator);
}

obj Translation {
    has text: str;
}

sem Translation.text = "The translated text only, with no notes, quotes or explanations.";

obj PostText {
    has language: str,
        title: str,
        description: str;
}

sem PostText.language = "The target language code this entry is written in, exactly as given in targets.";
sem PostText.title = "The post title translated into that language.";
sem PostText.description = "The post description translated into that language.";

obj PostTranslations {
    has items: list[PostText] = [];
}

sem PostTranslations.items = "One entry per target language, in the order of targets.";

sem translate = "Translate a student's marketplace or chat text faithfully. Keep every numeral as digits exactly as written (never spell numbers out or convert them), keep currency symbols, prices, times and dates exactly as written, keep proper nouns, place names and addresses unchanged, and do not add, remove or soften any information.";
sem translate.text = "The text to translate, exactly as the student wrote it.";
sem translate.source = "Language code of the text, for example 'ko', 'zh', 'en'.";
sem translate.target = "Language code to translate into.";

def translate(text: str, source: str, target: str) -> Translation by translator();

sem translate_post = "Translate a student's marketplace post title and description into each target language. Keep every numeral as digits exactly as written (never spell numbers out or convert them), keep currency symbols, prices, times and dates exactly as written, keep proper nouns, place names and addresses unchanged, and do not add, remove or soften any information.";
sem translate_post.title = "The post title, exactly as the student wrote it.";
sem translate_post.description = "The post description, exactly as the student wrote it.";
sem translate_post.source = "Language code of the title and description.";
sem translate_post.targets = "Language codes to translate into; return one entry for each.";

def translate_post(
    title: str, description: str, source: str, targets: list[str]
) -> PostTranslations by translator();

obj TextList {
    has texts: list[str] = [];
}

sem TextList.texts = "The translations, exactly one per input text, in the same order as the input.";

sem translate_batch = "Translate each of several short texts faithfully, independently of the others. Keep every numeral as digits exactly as written (never spell numbers out or convert them), keep currency symbols, prices, times and dates exactly as written, keep proper nouns, place names and addresses unchanged, and do not add, remove or soften any information.";
sem translate_batch.texts = "The texts to translate, in order.";
sem translate_batch.source = "Language code of the texts, for example 'ko', 'zh', 'en'.";
sem translate_batch.target = "Language code to translate into.";

def translate_batch(texts: list[str], source: str, target: str) -> TextList by translator();
