# Contributing

Simple GitHub flow. `main` is always runnable; all changes arrive through a PR.

1. **Branch** off fresh `main`: `git switch -c <you>/<short-topic>`.
2. **Build in small commits.** Write a test alongside the code (`test "what it proves" { ... }`
   in the same `.jac` file, or a file next to it).
3. **Check locally** — the three commands in the README must pass.
4. **Open a PR** (`/ship` does the push + PR body for you). Fill in the template; keep it small
   enough to review in ~10 minutes.
5. **Get one review** (`/review-pr <number>`) and **verify** the change actually works
   (`/verify`). Fix or explicitly reject every finding.
6. **Squash-merge** once CI is green and someone other than the author has approved. Delete the
   branch.

Rules of thumb for a hackathon team: don't rewrite someone else's open branch, rebase on `main`
instead of merging it into your branch, and never commit secrets (`.env` is gitignored — share
keys out of band; add new variable names to `.env.example`).

## Claude Code skills

Shared skills live in `.claude/skills/`:

| Skill | Use it to |
|---|---|
| `/ship` | Check, push the branch, open the PR with a filled-in description |
| `/verify` | Run the app / tests and observe the change actually working |
| `/review-pr <n>` | Review a PR (yours or a teammate's) and post one summary comment |
