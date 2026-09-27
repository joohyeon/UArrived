---
date: 2026-09-27
topic: arrival-onboarding-wizard
status: ready-for-planning
builds-on: docs/brainstorms/2026-09-26-002-arrival-story-native-language-market-requirements.md
---

# Arrival onboarding wizard: the first screen a new student fills in

## Problem

A design review of the current first-week flow (chat + artifact, 2026-09-27) found that the profile
fields the rest of the app already depends on — `arrival_date`, `housing_status`, `area`,
`preferred_language` on `Profile` — are never collected anywhere in the running app. Nothing calls
`update_my_profile` with them. As a result:

- `Today.jac`'s "Nothing to suggest yet" empty state ("Add your arrival date and whether you need an
  airport ride in Profile") never resolves for a real student.
- The market's arrival-based prefill (R12 in the arrival-story brainstorm) never has data to prefill from.
- A brand-new student verifies their `@umich.edu` email in `Welcome.jac` and lands directly on `/market`
  or `/today` with an empty profile — no welcome moment, no setup step at all.

The Figma mockups show a 4-step wizard (arrival date + flight number, a specific-dorm housing picker,
language, "what have you already finished") ending in a "Landing Plan." No such screen exists in
`journey/screens` today (only `today.jac`, `journey.jac`, `task.jac`, `ask.jac`, `events.jac`,
`common.jac` do), and some of what it asks for doesn't match any real field or task.

## Decision

Build the wizard as a thin front end over what the backend already models — no new subsystem, no schema
beyond three small, additive changes. Where the mockup invented data that has no home in the codebase
(specific dorm names, a flight number, "email activation"/"housing form" as trackable checklist items),
use the real fields and real tasks instead of inventing new ones to match a picture.

## Requirements

- **O-R1 — Onboarding screen.** New `/onboarding` route, one `Onboarding` component
  (`journey/screens/onboarding.jac`), 4 internal steps, each with a "Skip" link that advances without
  writing that step's field(s):
  1. **Arrival** — `arrival_date` (date), `arrival_time` (optional).
  2. **Housing** — `area` (the existing 7 `ANN_ARBOR_AREAS`: Central/North/South Campus, Kerrytown, Old
     West Side, Downtown, Other), `housing_status` (have-housing / looking / temporary).
  3. **Language** — `preferred_language`, one of the 3 pilot languages (`en`/`ko`/`zh`, via
     `LANGUAGE_NAMES`), via `update_my_profile({"preferred_language": lang})`. That endpoint already
     calls `set_language(p, lang, chosen=True)` internally when `preferred_language` is in the changes
     dict, so no new walker is needed here — corrected during planning; the original draft of this
     requirement assumed `set_language` had no reachable endpoint, which was wrong.
  4. **What have you already finished?** — a checklist of the real tasks from
     `journey/umich_ann_arbor_new_student_tasks_2026.json` (MCard, tuition bill, UHS registration, US
     phone number, bank account, immigration check-in, SSN, International Center), using each task's real
     English title from `task_data.jac`'s `BASELINE`. Checking one calls
     `mark_task_done(tid, skip_step_check=True)` (O-R4).
- **O-R2 — Finish.** Reaching the end of the wizard (by filling or skipping every step) sets
  `Profile.onboarding_done = True` via `update_my_profile` and redirects to `/today`.
- **O-R3 — Gating.** `Welcome.jac` sends a freshly verified student to `/onboarding` instead of
  `/today`/`/market` when `onboarding_done` is false. `Today.jac`'s `can with entry` does the same check
  on load, as a backstop for anyone who reaches `/today` directly.
- **O-R4 — Backend additions**, each a small extension of existing code:
  - `Profile.onboarding_done: bool = False`, added to `FLAG_FIELDS` (so `update_my_profile` can set it)
    and to `ProfileView`/`view_of` (so the client can read it for gating, O-R3).
  - `journey.walkers.mark_task_done(tid: str, skip_step_check: bool = False)` — an opt-in bypass of "tick
    every step first," used only by the onboarding checklist's self-report. The default behavior (used by
    the real task screen) is unchanged.

## Out of scope (fast-follows, from the design review's "Option A: One Continuous Quest")

- The "Level 1 unlocked" welcome-bridge screen between onboarding and Today.
- Merging Today's essentials view with a "This week in Ann Arbor" discovery section.
- A flight-number field, or a specific dorm/building picker beyond the existing 7-area list.
- Asking `student_type` in the wizard — `journey.walkers.applies()` already treats an unset student type
  as "show every task," so deferring this doesn't break task filtering.

## Testing

- `journey/onboarding_flow_tests.jac` (served-app test): sign up → verify → redirected to `/onboarding` →
  complete all 4 steps → lands on `/today` with the profile fields set and the checked tasks showing
  `done` in `my_journey()`.
- A second scenario in the same file: skip every step → still reaches `/today`, with only
  `onboarding_done=True` changed and no other profile field touched.
- `core/profile_flow_tests.jac` gets one case confirming `update_my_profile({"preferred_language": ...})`
  still sets `language_chosen`/`language_defaulted` and syncs the `Mailbox` (existing behavior; onboarding
  just becomes its first real caller).
- `journey/walkers.jac`'s existing tests get one case: `mark_task_done(tid, skip_step_check=True)`
  succeeds with no steps ticked; the default call (no flag) still refuses with "Tick every step first."

## Success criteria

- A new signup that verifies lands on `/onboarding`, not `/today` or `/market`.
- Every one of the 4 steps can be filled in or skipped, and the wizard always reaches `/today`.
- `bash scripts/test.sh` and `bash scripts/check_rules.sh` both pass.
