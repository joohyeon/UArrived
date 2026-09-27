# Contributing

Simple GitHub flow. `main` is always runnable; all changes arrive through a PR.

**Hackathon speed mode:** CI only runs `scripts/check_rules.sh` (structure/rules), and reviews are
optional. This is a deliberate trade-off for speed, not an oversight — restore the full checks and
required reviews once the hackathon is over.

1. **Branch** off fresh `main`: `git switch -c <you>/<short-topic>`.
2. **Build in small commits.** A test alongside the code is still a good idea when you have time
   (`test "what it proves" { ... }` in the same `.jac` file, or a file next to it), but it's not
   required to merge right now.
3. **Check locally** — `bash scripts/check_rules.sh` must pass (it's the only thing CI enforces).
   `jac fmt --check .`, `jac check .` and `bash scripts/test.sh` (see README.md) are optional but
   recommended if you have a spare minute. Read [docs/ENGINEERING_RULES.md](docs/ENGINEERING_RULES.md)
   once — it's short.
4. **Open a PR** (`/ship` does the push + PR body for you). Fill in the template; keep it small
   enough to review in ~10 minutes.
5. **Review is optional.** Grab one (`/review-pr <number>`) for anything risky or shared; skip it
   otherwise. Run `/verify` yourself before merging if you skip review.
6. **Squash-merge** once CI is green (`/ship` does this for you). Delete the branch.

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
