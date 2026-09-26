---
name: verify
description: Verify a Jac change actually works — run the checks, then run the app / exercise the changed behaviour and observe real output. Use before opening a PR, when reviewing one, or when asked "does this work?". Accepts an optional "full" argument for an end-to-end pass.
---

# Verify (Jac)

Passing tests is necessary, not sufficient: **run the thing and read the output.** Do not claim
success without evidence from commands you ran in this session.

## Arguments

- *(none)* — feature-only: the checks plus the one path the change touches.
- `full` — also exercise the neighbouring flows and error cases end to end.
- A PR number (`/verify 12`) — check out its branch first (`gh pr checkout 12`), verify, then say
  which branch you were on. Use a separate `git worktree` if the current checkout has uncommitted work.

## Steps

1. **Know the claim.** Read the PR description / task and write down, in one line each, what should
   now be true. That list is what you verify — not "the diff looks fine".
2. **Static checks**
   ```bash
   bash scripts/check_rules.sh
   jac fmt --check .
   jac check .
   jac test $(git ls-files '*.jac')
   ```
   Note any test that does not assert the behaviour in the claim list (a test whose name promises
   more than its assertions prove is a finding).
3. **Run it for real.**
   - Script / CLI: `jac run <file>.jac` with representative input and read the actual output.
   - Server app: start it (`jac run` / `jac serve <file>.jac` as the project does), hit the endpoint
     or walker with `curl`, and read the response; stop the server afterwards.
   - Web UI (the primary surface): `jac run --dev main.jac`, then drive it with `jac browse open localhost:8000`
     → `snapshot` / `click @eN` / `fill` / `screenshot` (or the `claude-in-chrome` skill). Check a ~360 px
     phone-width viewport first, then desktop.
   - Also try one **bad input / failure path** for each claim.
4. **Report** as a table: claim → command run → observed result → ✅/❌. Include exact failing
   output for any ❌. If something could not be run (missing key, no display), say so — that is
   "unverified", not "passed".

## Never

Edit code while verifying (report, don't fix — or say clearly that you switched to fixing), leave
servers running, or paste secrets from `.env` into the report.
