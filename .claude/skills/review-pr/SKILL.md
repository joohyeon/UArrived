---
name: review-pr
description: Review a GitHub PR in this repo (a teammate's or your own) for correctness, Jac/Python pitfalls, tests and secrets, then post one summary comment. Use when the user gives a PR number/URL or says "review this PR".
---

# Review PR

Argument: PR number or URL (default: the PR for the current branch, `gh pr view`).

## Steps

1. **Gather.** `gh pr view <n> --json title,body,author,baseRefName,headRefName,files,statusCheckRollup`
   and `gh pr diff <n>`. Read the changed files in full where the diff lacks context. Check
   `gh pr checks <n>` — red CI is a blocking finding on its own.
2. **Review for, in priority order:**
   1. **Correctness** — logic errors, unhandled `None`/empty cases, wrong walker/edge/node traversal,
      off-by-one, misuse of async or state shared across requests.
   2. **Security** — secrets or tokens in the diff or history, unvalidated input reaching shell / SQL /
      file paths, endpoints or walkers exposed without auth that should have it.
   3. **Tests** — new behaviour has a test; each `test "name"` asserts what its name claims; failure
      paths covered.
   4. **Scope and clarity** — unrelated changes, dead code, names that obscure intent, PR too large
      to review (suggest splitting).
   5. **Jac-specific** — `jac fmt --check .` / `jac check .` clean, no leftover debug `print`s.
3. **Verify claims that matter.** For anything you'd flag as a bug, confirm it against the code (or
   run it — see `/verify`) before reporting; drop findings you cannot substantiate.
4. **Report** findings ranked Blocking / Should fix / Nit, each with `file:line`, what is wrong,
   and a concrete failure scenario or suggested fix. Say plainly if there are none.
5. **Post one summary comment**, only after showing the user the text if they are the author's
   teammate reviewing on their behalf:
   `gh pr comment <n> --body-file <file>` — or, to formally approve / request changes,
   `gh pr review <n> --approve|--request-changes --body-file <file>`. Never approve your own PR.

## Never

Merge, push to the PR branch, or resolve someone else's threads. Review is read-only.
