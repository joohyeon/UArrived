## What

<!-- The change, in one or two sentences. Link the issue. -->

## Area

- [ ] Feature A (`journey/`)  - [ ] Feature B (`market/`)  - [ ] Shared (`core/` `ui/` `ai/`)  - [ ] Docs/CI

## How to verify

<!-- Commands or clicks so a reviewer can see it work (screenshots for UI). -->

## Checks

- [ ] `bash scripts/check_rules.sh` passes (Jac share ≥ 40%, no cross-feature imports, no raw colors)
- [ ] `jac fmt --check .`, `jac check .` and `jac test` pass
- [ ] UI uses `ui/components` + `ui/tokens` only (screenshot attached for UI changes)
- [ ] New behaviour has a test named for what it proves
- [ ] Rules/eligibility logic is deterministic — no LLM decides requirements
- [ ] No secrets, credentials or `.env` contents in the diff
