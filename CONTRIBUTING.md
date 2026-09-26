# Contributing

Simple GitHub flow. `main` is always runnable; all changes arrive through a PR.

1. **Branch** off fresh `main`: `git switch -c <you>/<short-topic>`.
2. **Build in small commits.** Write a test alongside the code (`test "what it proves" { ... }`
   in the same `.jac` file, or a file next to it).
3. **Check locally** — `bash scripts/check_rules.sh` plus the three commands in the README must pass.
   Read [docs/ENGINEERING_RULES.md](docs/ENGINEERING_RULES.md) once: it is short and enforced by CI.
4. **Open a PR** (`/ship` does the push + PR body for you). Fill in the template; keep it small
   enough to review in ~10 minutes.
5. **Get one review** (`/review-pr <number>`) and **verify** the change actually works
   (`/verify`). Fix or explicitly reject every finding.
6. **Squash-merge** once CI is green (`/ship` does this for you). Get a teammate's review first for
   changes to `core/`, `ui/` or `data/`. Delete the
   branch.

Rules of thumb for a hackathon team: don't rewrite someone else's open branch, rebase on `main`
instead of merging it into your branch, and never commit secrets (`.env` is gitignored — share
keys out of band; add new variable names to `.env.example`).

## Claude Code skills

Shared skills live in `.claude/skills/`:

| Skill | Use it to |
|---|---|
| `/ship` | Check, push, open the PR, wait for green CI, squash-merge, return to `main` |
| `/verify` | Run the app / tests and observe the change actually working |
| `/review-pr <n>` | Review a PR (yours or a teammate's) and post one summary comment |

## Splitting work between Feature A and Feature B

- **A** owns `journey/` (+ `data/tasks`, `data/resources`); **B** owns `market/`. Each feature is a
  vertical slice: graph → walkers → screens → tests. Label issues `feature-a` / `feature-b`.
- **Shared changes go first and alone.** `core/` (graph model) and `ui/` (tokens and components)
  need both leads' approval, in a small PR that lands *before* feature code depends on it.
- **Features never import each other.** If A needs something from B, promote it to `core/`.
- **One design system.** Screens use `ui/components` and `ui/tokens`; no one-off styles.
