# ai/ — explain / summarize / translate / draft helpers

Used only to explain, summarize, translate and draft listings. Output is always labeled "AI-generated"
in the UI and never feeds eligibility, prerequisites or requirement decisions. Rules live in
`journey/` and `data/`, not here.

| Module | Model glob | What it does |
|---|---|---|
| `draft.jac` | `drafter` | one message -> structured post draft |
| `decide.jac` | `advisor` | Help me decide notes from rule-built facts |
| `translate.jac` | `translator` | text and post title/description translation, numerals kept as digits |

Each model is a module glob so tests swap in `MockLLM`. Feature code calls these through its own
wrapper (for example `market/translation.jac`, which adds the number guard and fallbacks).
