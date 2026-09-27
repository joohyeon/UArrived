---
name: ship
description: Finish the current branch end to end — run the Jac checks, commit, push, open a GitHub PR with a filled-in description, wait for CI, then squash-merge it and return to an up-to-date main. Also merges an already-open PR for the branch. Use when the user says "ship", "ship it", "open a PR and merge", or is done with a task. Never pushes to main directly and never merges on red CI.
---

# Ship (branch → PR → merge)

Simple GitHub flow: one task branch, one PR, squash-merged once CI is green (`CONTRIBUTING.md`).
Invoking `/ship` IS the author's decision to merge; a teammate's `/review-pr` before it is
recommended for anything touching `core/`, `ui/` or `data/`, but not required.

## Steps

1. **Branch check.** `git branch --show-current`. If on `main`, create a branch first
   (`git switch -c <user>/<short-topic>`) — never commit to or push `main`.
   If the branch already has an open PR (`gh pr view --json number,state`), skip to step 7 after
   pushing any new commits.
2. **Sync.** `git fetch origin && git rebase origin/main`. Resolve conflicts here, then continue.
3. **Check** — all must pass; fix failures rather than skipping them:
   ```bash
   bash scripts/check_rules.sh  # Jac share, feature boundaries, design tokens
   jac fmt --check .            # fix with: jac fmt --lintfix <file>
   jac check .
   jac test -d .
   ```
4. **Commit** everything intended, in small logical commits (imperative subject, why in the body).
   `git status` must be clean afterwards; no `.env` or secrets in `git diff origin/main`.
5. **Push** the branch: `git push -u origin HEAD` (never `--force` on a shared branch; use
   `--force-with-lease` only for your own branch after a rebase).
6. **Open the PR** with `gh pr create --base main --title "<title>" --body-file <file>`. Fill in
   `.github/PULL_REQUEST_TEMPLATE.md` from the actual diff (`git log origin/main..HEAD`,
   `git diff origin/main...HEAD`): What, Why, **How to verify** (concrete commands/steps), and tick
   only the checks you really ran.
7. **Wait for CI.** `gh pr checks <n> --watch` (or poll until no check is `pending`).
   - **Red:** read the failing log (`gh run view <run> --log-failed`), fix the cause on this branch,
     push, and wait again. Do not merge; never re-run hoping for green.
   - **Green:** confirm the log shows the tests actually ran (e.g. `N passed`), not skipped.
8. **Merge.** `gh pr merge <n> --squash --delete-branch`. If it is refused (conflicts, a required
   review, branch protection), stop and report why — do not retry with `--admin` or `--auto`.
9. **Return to main.** `git switch main && git pull --ff-only`, then delete the local branch
   (`git branch -d <branch>`).
10. **Report** the PR URL, the merge commit, and the CI result you checked.

## Never

Push to `main` directly, merge with a failing or pending check, use `--admin`, force-push `main`,
or claim a check passed without reading its result.
