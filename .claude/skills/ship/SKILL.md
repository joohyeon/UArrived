---
name: ship
description: Finish the current branch and open a GitHub PR — run the Jac checks, commit, push the branch, and create the PR with a filled-in description. Use when the user says "ship", "open a PR", "create a PR", or is done with a task. Never pushes to main and never merges.
---

# Ship (branch → PR)

Simple GitHub flow: one task branch, one PR, squash-merged after review (`CONTRIBUTING.md`).

## Steps

1. **Branch check.** `git branch --show-current`. If on `main`, create a branch first
   (`git switch -c <user>/<short-topic>`) — never commit to or push `main`.
2. **Sync.** `git fetch origin && git rebase origin/main`. Resolve conflicts here, then continue.
3. **Check** — all three must pass; fix failures rather than skipping them:
   ```bash
   bash scripts/check_rules.sh  # Jac share, feature boundaries, design tokens
   jac fmt --check .            # fix with: jac fmt --lintfix <file>
   jac check .
   jac test $(git ls-files '*.jac')
   ```
4. **Commit** everything intended, in small logical commits (imperative subject, why in the body).
   `git status` must be clean afterwards; no `.env` or secrets in `git diff origin/main`.
5. **Push** the branch: `git push -u origin HEAD` (never `--force` on a shared branch; use
   `--force-with-lease` only for your own branch after a rebase).
6. **Open the PR** with `gh pr create --base main --title "<title>" --body-file <file>`. Fill in
   `.github/PULL_REQUEST_TEMPLATE.md` from the actual diff (`git log origin/main..HEAD`,
   `git diff origin/main...HEAD`): What, Why, **How to verify** (concrete commands/steps), and tick
   only the checks you really ran.
7. **Report** the PR URL and CI status (`gh pr checks`). Suggest `/verify` and `/review-pr <n>`.

## Never

Push to `main`, merge the PR yourself (a teammate approves; squash-merge after CI is green), use
`--admin`, or claim a check passed without running it.
