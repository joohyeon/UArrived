# CLAUDE.md — UMadeIt

**Web app first (mobile-first responsive), built end to end in Jac** — graph, walkers and UI.
Hard rules are in [docs/ENGINEERING_RULES.md](docs/ENGINEERING_RULES.md) and enforced by
`bash scripts/check_rules.sh` (Jac ≥ 40% of source; non-Jac only in `interop/`; `journey/` and
`market/` never import each other; no raw colors outside `ui/tokens.jac`; no AI in rules code).
Read that file before writing code. Run `jac guide jac-essentials` for current syntax.

Layout: `core/` shared model · `journey/` Feature A · `market/` Feature B · `ui/` design system ·
`ai/` explain/translate/draft · `interop/` the only non-Jac code · `data/` reviewable content.

Hackathon team project. **Jac ([jaclang.org](https://jaclang.org/)) is the primary language** — implement
everything in `.jac` by default; use Python only when Jac cannot do the job, and keep it small. Workflow is in [CONTRIBUTING.md](CONTRIBUTING.md). `AGENTS.md` is a symlink to this file.

## Commands

```bash
jac run main.jac                     # run the entry point
jac fmt --check .                    # formatting; fix one file with: jac fmt --lintfix <file>
jac check .                          # type check (also runs in-file tests)
bash scripts/test.sh                 # all tests (jac test -d . with DB pooling off); args = file list, must start with main.jac
bash scripts/check_rules.sh          # repo rules: Jac share, boundaries, design tokens
jac run --dev main.jac               # serve the web app with hot reload (once the web-app shell exists)
jac browse open localhost:8000       # QA the running app in a headless browser (snapshot / click / screenshot)
jac guide                            # current, version-matched Jac reference guides
```

## Jac notes (learned the hard way, jaclang 0.37)

- Blocks use braces and every statement ends in `;`.
- Tests are `test "readable name" { assert ...; }` — the name is a **string**, and the block lives
  in a `.jac` file passed to `jac test` explicitly.
- Entry code goes in `with entry { ... }`.
- **macOS: `jac install` fails with `_posixsubprocess ... symbol not found '_PyExc_MemoryError'`.** The
  bundled Python exports no C-API symbols, so it can't build a venv. `bash scripts/setup.sh` handles it
  (creates `.jac/venv` with Homebrew Python 3.14, then `jac install`). Linux/CI is unaffected.
- **Dates in tests:** server code gets today from `core/clock.jac`; set `UARRIVED_TODAY=YYYY-MM-DD` to move
  time forward (e.g. to expire a post) instead of publishing past dates, which are refused.
- Endpoints: `def:protect` / `walker:protect` = login required, runs on the caller's root; `:pub` = no
  login; `:priv` = not served at all. Only modules imported by `main.jac` are served.
- **Endpoint gotcha: an omitted parameter with a default arrives as the *string* form of that default**
  (`str | None = None` arrives as `"None"`; a `bool = False` arrives as `"False"` — verified directly,
  correcting an earlier note here that said bools were fine). Never trust Python truthiness on a raw
  endpoint parameter that might be omitted (`not "False"` is `False`, since it's a non-empty string) —
  coerce explicitly, e.g. `str(value).strip().lower() == "true"` (see `journey/walkers.jac`'s
  `mark_task_done`). For partial updates take one `changes: dict[str, any]` and whitelist keys (see
  `core/profile.jac`) — that sidesteps the issue entirely, since an absent dict key is unambiguous.
- **Plain graph tests and `root.shared`:** after a served test closes, `root.shared` in the same process can
  point at the dead server's root (serial runs only). Commons helpers take an optional `commons` arg;
  plain tests pass `root`.
- **Client bundle rules:** a client screen that imports a *value* (glob) from a server module pulls that whole
  module into the browser and fails (`E5082`). Put shared constants in import-free modules
  (`core/constants.jac`, `market/constants.jac`). A client helper imported by another client module must be
  `def:pub`. Server endpoints (`def:protect`) and their obj/node types import fine.
- **Client code runs as JavaScript: an empty list is truthy.** In screens write `len(xs) > 0` / `len(xs) == 0`,
  never `if xs` / `not xs` for lists (strings and numbers are fine).
- **Client reads are cached 60s**; any writer call clears the cache. Polling screens call `heartbeat()`
  (a tiny write) before reading so they see other students' changes.
- **Shared local Postgres (256 connections).** Every graph test and served test uses jac's embedded
  Postgres; there is no in-memory backend. Pooling keeps idle connections per test database for 5
  min, so parallel `jac test -d .` runs can fill it and hang every test and `jac run` on the machine.
  Use `bash scripts/test.sh` (pooling off, `[dev] test_jobs = 4`); check with
  `ps -eo command | grep -c '^postgres: jac'`.
- Served-app tests: `JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp())`, call
  `/function/<name>`; never name a file `test_*.jac`.
- **Mocking the AI in served tests:** setting `ai.draft.drafter = MockLLM(...)` only reaches the served app if
  the test file also imports a server module (e.g. `import from market.topics { Invite }`); otherwise the
  app loads its own copy and calls the real model whenever `ANTHROPIC_API_KEY` is set.
- **Each student sees only their own edges.** `[g <-:MemberOf:<-]` from another student's request returns
  just the caller's edge, so anything others must count or check (group members) needs a public node
  (`Membership`, `ReplyTick`).
- `# jac:ignore[CODE]` is ignored inside `.impl.jac` annexes; keep browser-global code (`new(URLSearchParams, ...)`,
  `window.*`) in the main file with the ignore comment.
- Module constants are `glob NAME: type = ...;`; booleans are `True`/`False`.
- Under `jac test`, `int(s, 16)` raises "invalid literal for int()" — parse hex by hand (see
  `ui/tokens.jac`). `jac guide jac-core-cheatsheet --section pitfalls` lists more.
- `jac mcp` starts an MCP server for AI-assisted Jac development — worth wiring up if the syntax
  keeps tripping you.

## Rules

- Branch + PR only; never push to `main`, never force-push a shared branch.
- Don't commit secrets; add variable names (not values) to `.env.example`.
- Use `/ship`, `/verify`, `/review-pr` (see `.claude/skills/`).
