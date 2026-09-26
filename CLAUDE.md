# CLAUDE.md — Uarrived

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
jac test -d .                        # all tests; bare `jac test` collects nothing, and a file list must start with main.jac
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
  bundled Python exports no C-API symbols, so it can't build a venv. Create it first with
  `python3.14 -m venv .jac/venv` (Homebrew), then `jac install` works. Linux/CI is unaffected.
- Endpoints: `def:protect` / `walker:protect` = login required, runs on the caller's root; `:pub` = no
  login; `:priv` = not served at all. Only modules imported by `main.jac` are served.
- **Endpoint gotcha: an omitted `str | None = None` parameter arrives as the string `"None"`** (bools are
  fine). For partial updates take one `changes: dict[str, any]` and whitelist keys (see `core/profile.jac`).
- **Plain graph tests and `root.shared`:** after a served test closes, `root.shared` in the same process can
  point at the dead server's root (serial runs only). Commons helpers take an optional `commons` arg;
  plain tests pass `root`.
- Served-app tests: `JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp())`, call
  `/function/<name>`; never name a file `test_*.jac`.
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
