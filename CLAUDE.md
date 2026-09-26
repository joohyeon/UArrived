# CLAUDE.md — Uarrived

Hackathon team project written mostly in **Jac** ([jaclang.org](https://jaclang.org/)), with Python
where needed. Workflow is in [CONTRIBUTING.md](CONTRIBUTING.md). `AGENTS.md` is a symlink to this file.

## Commands

```bash
jac run main.jac                     # run the entry point
jac fmt --check .                    # formatting; fix one file with: jac fmt --lintfix <file>
jac check .                          # type check (also runs in-file tests)
jac test $(git ls-files '*.jac')     # tests — pass files explicitly; bare `jac test` collects nothing
jac --help                           # jac x / serve / mcp etc.
```

## Jac notes (learned the hard way, jaclang 0.37)

- Blocks use braces and every statement ends in `;`.
- Tests are `test "readable name" { assert ...; }` — the name is a **string**, and the block lives
  in a `.jac` file passed to `jac test` explicitly.
- Entry code goes in `with entry { ... }`.
- `jac mcp` starts an MCP server for AI-assisted Jac development — worth wiring up if the syntax
  keeps tripping you.

## Rules

- Branch + PR only; never push to `main`, never force-push a shared branch.
- Don't commit secrets; add variable names (not values) to `.env.example`.
- Use `/ship`, `/verify`, `/review-pr` (see `.claude/skills/`).
