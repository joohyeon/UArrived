# Arrival Onboarding Wizard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 4-step `/onboarding` wizard (arrival, housing, language, "what's already finished") that
collects the profile fields the rest of the app already depends on, and gate a new student into it right
after email verification.

**Architecture:** A single new client screen (`journey/screens/onboarding.jac`) that calls only endpoints
that already exist (`update_my_profile`, `my_journey`, `mark_task_done`, `reopen_task`), plus two small,
additive backend changes (`Profile.onboarding_done`, `mark_task_done`'s `skip_step_check`). Gating is two
client-side redirects (`Welcome.jac` after verification, `Today.jac` as a backstop) — no new access control,
since `onboarding_done` only steers navigation, never what a walker will accept.

**Tech Stack:** Jac (server walkers + client JSX screens), the existing `ui/tokens.jac` design system and
`ui/components/base.jac` / `ui/components/blocks.jac` components, `jaclang.testing.testing.JacTestClient`
for served-app tests.

**Spec:** `docs/brainstorms/2026-09-27-004-arrival-onboarding-wizard-requirements.md`

## Global Constraints

- Every color/spacing/radius/type value in new UI comes from `ui/tokens.jac` via `color()`/`space()`/
  `text_style()` — `scripts/check_rules.sh` fails on a raw color anywhere outside that file.
- `journey/` and `market/` never import each other (`ENGINEERING_RULES.md`); a `go(path)` navigation
  helper lives locally in `journey/screens/common.jac`, not imported from `market/screens/common.jac`.
- A client screen that imports a *glob* (module-level constant value) from a server module with real
  imports pulls that whole module into the browser bundle and fails with `E5082`. `ANN_ARBOR_AREAS` /
  `PILOT_LANGUAGES` / `LANGUAGE_NAMES` are safe (they live in the import-free `core/constants.jac`);
  `HOUSING_STATUSES` is NOT safe (it's a glob inside `core/profile.jac`, a server module with `os`/
  `pgwire` imports) — the housing options are a small literal list defined directly in
  `journey/screens/onboarding.jac` instead of imported. Endpoints (`def:protect` functions) and their
  `obj`/`node` types always import fine into client code — that's how `update_my_profile`,
  `ProfileUpdateResult`, `my_journey`, `TaskView` etc. are used below.
- Client calls to a walker pass its parameters as a normal function call (`update_my_profile({"area": ...})`),
  not the `{"changes": {...}}` shape — that shape only exists in served-test HTTP bodies, which post JSON
  that becomes the walker's keyword arguments.
- Run the whole suite with `bash scripts/test.sh` (DB pooling off); a file-scoped run is
  `bash scripts/test.sh main.jac <file>` (the file list must start with `main.jac`). Run
  `bash scripts/check_rules.sh` before considering any task done.
- Never name a test file `test_*.jac`.

## Review Focus

- **Skip every step.** The wizard must still reach `/today` with `onboarding_done=True` and every other
  profile field left at its default (`""`/`False`) — nothing silently written on a skip. (Task 4)
- **Un-checking a self-reported task.** Toggling a `ChecklistRow` off after toggling it on must call
  `reopen_task`, not error or leave `done=True` behind — after `mark_task_done(tid,
  skip_step_check=True)` then `reopen_task(tid)`, status reads `"started"` (steps stay ticked, per
  `reopen_task`'s existing "the ticked steps stay" contract), never `"done"`. (Task 2)
- **Applicability isn't bypassed.** `mark_task_done(tid, skip_step_check=True)` on a task that doesn't
  apply to the caller's `student_type` (e.g. an international-only task for an in-state student) must
  still fail with "No such task.", the same as today. (Task 2)
- **Server error surfaces, not silently swallowed.** If `update_my_profile` rejects a value (shouldn't
  happen with the fixed option lists here, but the client must not assume `ok=True`), the wizard shows
  `result.error` and does not advance to the next step. (Task 4)
- **Revisiting `/onboarding` after finishing doesn't loop.** `Onboarding` itself never redirects based on
  `onboarding_done` — only `Welcome` and `Today` do, and only *away from* `/onboarding`, so a student who
  reopens the link after finishing just sees the wizard again, not a redirect loop. (Task 5, by
  construction — no test needed beyond confirming `Onboarding.jac` has no such check)

---

### Task 1: `Profile.onboarding_done` — field, whitelist, view

**Files:**
- Modify: `core/profile.jac:36-37` (the `Profile` node), `core/profile.jac:353-358` (`FLAG_FIELDS`),
  `core/profile.jac:182-183` (`ProfileView`), `core/profile.jac:278-279` (`view_of`),
  `core/profile.jac:430-433` (`update_my_profile`'s flag-set block)
- Test: `core/profile_flow_tests.jac`

**Interfaces:**
- Produces: `ProfileView.onboarding_done: bool` (readable from `get_my_profile()`); settable via
  `update_my_profile({"onboarding_done": True})`. Task 4 and Task 5 depend on both.

- [ ] **Step 1: Write the failing test**

Add to `core/profile_flow_tests.jac` (after the last test in the file):

```jac
test "onboarding_done is off by default and settable through update_my_profile" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        fresh = call(client, "get_my_profile", {});
        assert not fresh["onboarding_done"];
        result = call(
            client, "update_my_profile", {"changes": {"onboarding_done": True}}
        );
        assert result["ok"] and result["profile"]["onboarding_done"];
        mine = call(client, "get_my_profile", {});
        assert mine["onboarding_done"];
    } finally {
        client.close();
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scripts/test.sh main.jac core/profile_flow_tests.jac`
Expected: FAIL — `onboarding_done` is not a key of the returned profile dict (`KeyError`-shaped
assertion failure), since the field doesn't exist yet.

- [ ] **Step 3: Add the field, whitelist entry, view field and setter**

In `core/profile.jac`, change the `Profile` node (lines 19-38) so it ends:

```jac
node Profile {
    has display_name: str = "",
        umich_email: str = "",
        pending_email: str = "",
        verified: bool = False,
        student_type: str = "",
        preferred_language: str = "en",
        language_chosen: bool = False,
        language_defaulted: bool = False,
        arrival_date: str = "",
        arrival_time: str = "",
        housing_status: str = "",
        move_in_date: str = "",
        area: str = "",
        needs_airport_ride: bool = False,
        has_us_phone: bool = False,
        has_us_bank: bool = False,
        email_notifications: bool = True,
        onboarding_done: bool = False,
        last_seen: str = "";
}
```

Change `FLAG_FIELDS` (around line 353) to:

```jac
     FLAG_FIELDS: list[str] = [
         "needs_airport_ride",
         "has_us_phone",
         "has_us_bank",
         "email_notifications",
         "onboarding_done"
     ];
```

Change `ProfileView` (around line 167) so it ends:

```jac
obj ProfileView {
    has display_name: str,
        umich_email: str,
        verified: bool,
        student_type: str,
        preferred_language: str,
        language_chosen: bool,
        arrival_date: str,
        arrival_time: str,
        housing_status: str,
        move_in_date: str,
        area: str,
        needs_airport_ride: bool,
        has_us_phone: bool,
        has_us_bank: bool,
        email_notifications: bool,
        onboarding_done: bool,
        is_moderator: bool;
}
```

Change `view_of` (around line 262) so the constructor call includes it:

```jac
def view_of(profile: Profile) -> ProfileView {
    return ProfileView(
        display_name=profile.display_name,
        umich_email=profile.umich_email,
        verified=profile.verified,
        student_type=profile.student_type,
        preferred_language=profile.preferred_language,
        language_chosen=profile.language_chosen,
        arrival_date=profile.arrival_date,
        arrival_time=profile.arrival_time,
        housing_status=profile.housing_status,
        move_in_date=profile.move_in_date,
        area=profile.area,
        needs_airport_ride=profile.needs_airport_ride,
        has_us_phone=profile.has_us_phone,
        has_us_bank=profile.has_us_bank,
        email_notifications=profile.email_notifications,
        onboarding_done=profile.onboarding_done,
        is_moderator=is_moderator(profile)
    );
}
```

In `update_my_profile`, right after the existing `"email_notifications"` block (around line 430-432),
add:

```jac
    if "onboarding_done" in changes {
        p.onboarding_done = changes["onboarding_done"];
    }
```

(This goes in the same `if "X" in changes { p.X = changes["X"]; }` sequence as `needs_airport_ride` /
`has_us_phone` / `has_us_bank` / `email_notifications` — right before the `synced = ...` line.)

- [ ] **Step 4: Run test to verify it passes**

Run: `bash scripts/test.sh main.jac core/profile_flow_tests.jac`
Expected: PASS, and every pre-existing test in that file still passes (the new field defaults to `False`
and is additive, so nothing else should change).

- [ ] **Step 5: Commit**

```bash
git add core/profile.jac core/profile_flow_tests.jac
git commit -m "feat(core): add Profile.onboarding_done for the arrival wizard gate"
```

---

### Task 2: `mark_task_done`'s `skip_step_check`

**Files:**
- Modify: `journey/walkers.jac:239-252`
- Test: `journey/journey_flow_tests.jac`

**Interfaces:**
- Consumes: `task_by_id`, `applies`, `progress_for`, `checked_for`, `task_view` (all already in
  `journey/walkers.jac`/`journey/task_data.jac`, unchanged).
- Produces: `mark_task_done(tid: str, skip_step_check: bool = False) -> TaskResult`. Task 4's onboarding
  checklist calls this with `skip_step_check=True`; every existing caller (task detail screen) keeps
  calling it with one argument and unchanged behavior.

- [ ] **Step 1: Write the failing tests**

Add to `journey/journey_flow_tests.jac` (after the last test in the file):

```jac
test "onboarding can self-report a task already finished, bypassing the step check" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        blocked = call(client, "mark_task_done", {"tid": "banking"});
        assert not blocked["ok"] and "step" in blocked["error"];
        early = call(
            client, "mark_task_done", {"tid": "banking", "skip_step_check": True}
        );
        assert early["ok"] and early["task"]["status"] == "done";
        after = call(client, "my_journey", {});
        assert task_of(after, "banking")["status"] == "done";
        undone = call(client, "reopen_task", {"tid": "banking"});
        assert undone["ok"] and undone["task"]["status"] == "started";
    } finally {
        client.close();
    }
}

test "skip_step_check never bypasses task applicability" {
    client = served();
    try {
        client.register_user("sam@umich.edu", "password123");
        call(client, "update_my_profile", {"changes": {"student_type": "in-state"}});
        blocked = call(
            client,
            "mark_task_done",
            {"tid": "international_center", "skip_step_check": True}
        );
        assert not blocked["ok"];
    } finally {
        client.close();
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scripts/test.sh main.jac journey/journey_flow_tests.jac`
Expected: FAIL on the first new test — the server rejects the `skip_step_check` key (or the call still
requires every step ticked), since the parameter doesn't exist yet.

- [ ] **Step 3: Add the parameter**

Replace `mark_task_done` in `journey/walkers.jac` (lines 239-252) with:

```jac
"""Mark a task done. Every step must be ticked first, unless `skip_step_check` — used only by the
arrival wizard's self-report of a task finished before the student arrived."""
def:protect mark_task_done(tid: str, skip_step_check: bool = False) -> TaskResult {
    task = task_by_id(tid);
    if task is None or not applies(task, my_profile().student_type) {
        return TaskResult(ok=False, error="No such task.");
    }
    p = progress_for(tid);
    if not skip_step_check and not all(checked_for(task, p)) {
        return TaskResult(ok=False, error="Tick every step first.");
    }
    p.checked = [True for _ in task.steps];
    p.done = True;
    return TaskResult(ok=True, task=task_view(tid));
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scripts/test.sh main.jac journey/journey_flow_tests.jac`
Expected: PASS, including every pre-existing test in the file (in particular "a student ticks every
step..." still gets `early["error"]` containing "step" from the default, non-bypassed call).

- [ ] **Step 5: Commit**

```bash
git add journey/walkers.jac journey/journey_flow_tests.jac
git commit -m "feat(journey): let mark_task_done skip the step check for self-reported tasks"
```

---

### Task 3: `journey/screens/common.jac` — a local `go()` navigation helper

**Files:**
- Modify: `journey/screens/common.jac`

**Interfaces:**
- Produces: `def:pub go(path: str)`. Task 4 (`Onboarding`'s "Finish" button) and Task 5 (`Today`'s gating
  backstop) both import this from `journey.screens.common`.

This one has no server-callable behavior to unit test (it's a one-line browser navigation call); its
correctness is exercised visually in Task 4's and Task 5's manual QA steps, matching how
`journey/screens/common.jac`'s existing `query_param` has no test of its own either.

- [ ] **Step 1: Add the helper**

In `journey/screens/common.jac`, add right after the `query_param` function (after line 19, before
`def:pub JourneyTabs`):

```jac
"""Full-page client navigation (a hard redirect, not a client-side route change)."""
def:pub go(path: str) {
    window.location.assign(path);  # jac:ignore[E1032,W2001]
}
```

- [ ] **Step 2: Confirm the module still type-checks**

Run: `jac check journey/screens/common.jac`
Expected: no new errors (the `# jac:ignore[E1032,W2001]` suppresses the same two codes
`market/screens/common.jac`'s identical `go` already suppresses for the same call).

- [ ] **Step 3: Commit**

```bash
git add journey/screens/common.jac
git commit -m "feat(journey): add a go() navigation helper for onboarding and its gate"
```

---

### Task 4: The onboarding screen and its route

**Files:**
- Create: `journey/screens/onboarding.jac`
- Modify: `main.jac` (import block around line 86, routing block around lines 97-103)
- Test: `journey/journey_flow_tests.jac` (the walker call sequence the screen makes; the JSX itself is
  verified by manual QA per this repo's existing pattern — no screen file anywhere has a render test)

**Interfaces:**
- Consumes: `update_my_profile(dict) -> ProfileUpdateResult` (Task 1), `mark_task_done(tid, skip_step_check)`
  (Task 2), `go(path)` (Task 3), `my_journey() -> JourneySummary`, `reopen_task(tid) -> TaskResult`
  (both pre-existing, unchanged), `ANN_ARBOR_AREAS: list[str]` / `PILOT_LANGUAGES: list[str]` /
  `LANGUAGE_NAMES: dict[str,str]` (pre-existing, `core/constants.jac`).
- Produces: `Onboarding -> JsxElement` (`def:pub`), routed at `/onboarding`. Task 5 links to it.

- [ ] **Step 1: Write the failing test (server-side call sequence)**

Add to `journey/journey_flow_tests.jac`:

```jac
test "the arrival wizard's calls round-trip: fill some steps, self-report a task, finish" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        step1 = call(
            client,
            "update_my_profile",
            {"changes": {"arrival_date": "2026-08-28", "arrival_time": "15:00"}}
        );
        assert step1["ok"];
        step2 = call(
            client,
            "update_my_profile",
            {"changes": {"area": "Central Campus", "housing_status": "have-housing"}}
        );
        assert step2["ok"];
        step3 = call(
            client, "update_my_profile", {"changes": {"preferred_language": "zh"}}
        );
        assert step3["ok"] and step3["profile"]["language_chosen"];
        step4 = call(
            client, "mark_task_done", {"tid": "mcard", "skip_step_check": True}
        );
        assert step4["ok"];
        finish = call(
            client, "update_my_profile", {"changes": {"onboarding_done": True}}
        );
        assert finish["ok"] and finish["profile"]["onboarding_done"];
        mine = call(client, "get_my_profile", {});
        assert mine["arrival_date"] == "2026-08-28" and mine["area"] == "Central Campus";
        after = call(client, "my_journey", {});
        assert task_of(after, "mcard")["status"] == "done";
    } finally {
        client.close();
    }
}

test "skipping every step still reaches onboarding_done with nothing else changed" {
    client = served();
    try {
        client.register_user("mina@umich.edu", "password123");
        before = call(client, "get_my_profile", {});
        finish = call(
            client, "update_my_profile", {"changes": {"onboarding_done": True}}
        );
        assert finish["ok"];
        after = call(client, "get_my_profile", {});
        assert after["onboarding_done"];
        assert after["arrival_date"] == before["arrival_date"] == "";
        assert after["area"] == before["area"] == "";
        assert after["preferred_language"] == before["preferred_language"] == "en";
    } finally {
        client.close();
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scripts/test.sh main.jac journey/journey_flow_tests.jac`
Expected: FAIL on `mark_task_done` with `skip_step_check` if Task 2 isn't committed yet, or on
`onboarding_done` if Task 1 isn't — both should already be green if Tasks 1-2 ran first; this test is
here to lock in the exact sequence `Onboarding` will call, not to prove new server behavior.

- [ ] **Step 3: Write `journey/screens/onboarding.jac`**

```jac
"""Arrival onboarding: a 4-step wizard collecting arrival date, housing, language and which
first-week tasks a student already finished before arriving. Each step's "Skip" advances without
writing that step's field(s). Welcome and Today redirect here until `onboarding_done` is set."""

import from ui.tokens { color, space }
import from ui.components.base { Button, Field }
import from ui.components.blocks { QuestionBlock, SectionLabel, ProgressDots, SelectableCard, OptionTile, ChecklistRow }
import from core.constants { ANN_ARBOR_AREAS, PILOT_LANGUAGES, LANGUAGE_NAMES }
import from core.profile { update_my_profile, ProfileUpdateResult }
import from journey.walkers { my_journey, mark_task_done, reopen_task, JourneySummary, TaskView }
import from journey.screens.common { go }

glob HOUSING_OPTIONS: list[tuple[str, str]] = [
         ("have-housing", "I already have housing"),
         ("looking", "Still looking"),
         ("temporary", "Somewhere temporary for now")
     ];

def:pub Onboarding -> JsxElement {
    has step: int = 0,
        loaded: bool = False,
        saving: bool = False,
        error: str = "",
        arrival_date: str = "",
        arrival_time: str = "",
        area: str = "",
        housing_status: str = "",
        preferred_language: str = "",
        tasks: list[TaskView] = [];

    async def load -> None;
    async def saveArrival -> None;
    async def saveHousing -> None;
    async def saveLanguage -> None;
    async def toggleTask(tid: str, done: bool) -> None;
    async def finish -> None;

    can with entry {
        load();
    }

    def skip(e: MouseEvent) {
        error = "";
        step = step + 1;
    }

    <main
        style={{
            "maxWidth": "480px",
            "margin": "0 auto",
            "padding": space("4"),
            "minHeight": "100vh",
            "boxSizing": "border-box",
            "background": color("ground"),
            "display": "flex",
            "flexDirection": "column",
            "gap": space("6")
        }}
    >
        <ProgressDots steps={4} current={step}/>
        {<p role="alert" style={{"color": color("danger"), "margin": "0"}}>{error}</p>
            if error
            else None}
        {(
            <div style={{"display": "flex", "flexDirection": "column", "gap": space("4")}}>
                <QuestionBlock eyebrow="Step 1 of 4" title="When do you arrive in Ann Arbor?"/>
                <Field
                    label="Arrival date"
                    value={arrival_date}
                    onChange={lambda (v: str) { arrival_date = v; }}
                    input_type="date"
                />
                <Field
                    label="Arrival time (optional)"
                    value={arrival_time}
                    onChange={lambda (v: str) { arrival_time = v; }}
                    input_type="time"
                    hint="24-hour, e.g. 15:00"
                />
                <Button
                    label="Continue"
                    onClick={lambda (e: MouseEvent) { saveArrival(); }}
                    disabled={saving}
                    full={True}
                />
                <Button label="Skip" onClick={skip} variant="text" disabled={saving}/>
            </div>
        )
            if step == 0
            else None}
        {(
            <div style={{"display": "flex", "flexDirection": "column", "gap": space("4")}}>
                <QuestionBlock eyebrow="Step 2 of 4" title="Where will you live?"/>
                <div style={{"display": "flex", "flexDirection": "column", "gap": space("2")}}>
                    {[
                        <SelectableCard
                            key={a}
                            title={a}
                            selected={area == a}
                            onSelect={lambda { area = a; }}
                        /> for a in ANN_ARBOR_AREAS
                    ]}
                </div>
                <SectionLabel label="Housing status"/>
                <div style={{"display": "flex", "flexDirection": "column", "gap": space("2")}}>
                    {[
                        <SelectableCard
                            key={value}
                            title={label}
                            selected={housing_status == value}
                            onSelect={lambda { housing_status = value; }}
                        /> for (value, label) in HOUSING_OPTIONS
                    ]}
                </div>
                <Button
                    label="Continue"
                    onClick={lambda (e: MouseEvent) { saveHousing(); }}
                    disabled={saving or area == "" or housing_status == ""}
                    full={True}
                />
                <Button label="Skip" onClick={skip} variant="text" disabled={saving}/>
            </div>
        )
            if step == 1
            else None}
        {(
            <div style={{"display": "flex", "flexDirection": "column", "gap": space("4")}}>
                <QuestionBlock
                    eyebrow="Step 3 of 4"
                    title="Which language do you want first?"
                    subtitle="You can switch anytime from any screen."
                />
                <div style={{"display": "flex", "gap": space("3")}}>
                    {[
                        <OptionTile
                            key={code}
                            glyph={code.upper()}
                            title={LANGUAGE_NAMES[code]}
                            selected={preferred_language == code}
                            onSelect={lambda { preferred_language = code; }}
                        /> for code in PILOT_LANGUAGES
                    ]}
                </div>
                <Button
                    label="Continue"
                    onClick={lambda (e: MouseEvent) { saveLanguage(); }}
                    disabled={saving or preferred_language == ""}
                    full={True}
                />
                <Button label="Skip" onClick={skip} variant="text" disabled={saving}/>
            </div>
        )
            if step == 2
            else None}
        {(
            <div style={{"display": "flex", "flexDirection": "column", "gap": space("3")}}>
                <QuestionBlock
                    eyebrow="Final step"
                    title="What have you already finished?"
                    subtitle="Check anything you took care of before you got here."
                />
                {[
                    <ChecklistRow
                        key={v.task.tid}
                        label={v.task.title}
                        checked={v.status == "done"}
                        onToggle={lambda { toggleTask(v.task.tid, v.status == "done"); }}
                        reward={("+" + str(v.task.xp) + " XP") if v.task.required else ""}
                    /> for v in tasks
                ]
                    if loaded
                    else []}
                <Button
                    label="Finish"
                    onClick={lambda (e: MouseEvent) { finish(); }}
                    disabled={saving}
                    full={True}
                />
            </div>
        )
            if step == 3
            else None}
    </main>
}

impl Onboarding.load -> None {
    summary: JourneySummary | None = None;
    summary = await my_journey();
    tasks = summary.tasks;
    loaded = True;
}

impl Onboarding.saveArrival -> None {
    result: ProfileUpdateResult | None = None;
    saving = True;
    result = await update_my_profile(
        {"arrival_date": arrival_date, "arrival_time": arrival_time}
    );
    saving = False;
    if result.ok {
        error = "";
        step = step + 1;
    } else {
        error = result.error;
    }
}

impl Onboarding.saveHousing -> None {
    result: ProfileUpdateResult | None = None;
    saving = True;
    result = await update_my_profile({"area": area, "housing_status": housing_status});
    saving = False;
    if result.ok {
        error = "";
        step = step + 1;
    } else {
        error = result.error;
    }
}

impl Onboarding.saveLanguage -> None {
    result: ProfileUpdateResult | None = None;
    saving = True;
    result = await update_my_profile({"preferred_language": preferred_language});
    saving = False;
    if result.ok {
        error = "";
        step = step + 1;
    } else {
        error = result.error;
    }
}

impl Onboarding.toggleTask(tid: str, done: bool) -> None {
    if done {
        await reopen_task(tid);
    } else {
        await mark_task_done(tid, skip_step_check=True);
    }
    await load();
}

impl Onboarding.finish -> None {
    saving = True;
    await update_my_profile({"onboarding_done": True});
    saving = False;
    go("/today");
}
```

- [ ] **Step 4: Wire the route in `main.jac`**

Add the import after `import from journey.screens.events { Events }` (line 86):

```jac
import from journey.screens.onboarding { Onboarding }
```

Change the login-required check (around line 97) to also cover the wizard:

```jac
    if (
        path.startswith("/market")
        or path.startswith("/journey")
        or path == "/today"
        or path == "/onboarding"
    )
        and not jacIsLoggedIn() {
        return <Welcome/>;
    }
```

Add the route itself (next to the other journey routes, e.g. right after the `/today` block):

```jac
    if path == "/onboarding" {
        return <Onboarding/>;
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash scripts/test.sh main.jac journey/journey_flow_tests.jac`
Expected: PASS, including both new tests from Step 1.

Run: `jac check .`
Expected: no new type errors from `journey/screens/onboarding.jac` or `main.jac`.

Run: `jac fmt --check journey/screens/onboarding.jac main.jac`
Expected: clean, or fix with `jac fmt --lintfix journey/screens/onboarding.jac`.

- [ ] **Step 6: Manual QA (screen rendering has no automated test in this codebase)**

Run: `UARRIVED_DEV_MODE=1 jac run --dev main.jac`, then `jac browse open localhost:8000/onboarding`
(after registering/logging in a dev user). Click through all 4 steps once filling fields, and once via
"Skip" only, and confirm "Finish" lands on `/today`.

- [ ] **Step 7: Commit**

```bash
git add journey/screens/onboarding.jac main.jac journey/journey_flow_tests.jac
git commit -m "feat(journey): add the arrival onboarding wizard at /onboarding"
```

---

### Task 5: Gate Welcome and Today until onboarding is done

**Files:**
- Modify: `core/screens/welcome.jac`, `core/screens/welcome.impl.jac`, `journey/screens/today.jac`

**Interfaces:**
- Consumes: `get_my_profile() -> ProfileView` (pre-existing), `Onboarding`'s route `/onboarding` (Task 4),
  `go(path)` (Task 3, journey side only — `welcome.jac` gets its own one-line local version since
  `core/screens` doesn't import from `journey/screens` anywhere today and shouldn't start here).

No new server behavior, so no served-test task for this one; it's exercised by the same manual QA flow
as Task 4 (a fresh signup should now land on `/onboarding`, not `/today`/`/market`).

- [ ] **Step 1: Add profile check + a local redirect helper to `welcome.jac`**

In `core/screens/welcome.jac`, add to the imports (after the `core.auth` import block, before
`import from ui.tokens`):

```jac
import from core.profile { get_my_profile, ProfileView }
```

Add a local redirect helper right after `link_token` (after its closing `}`, before `def:pub Welcome`):

```jac
def go(path: str) {
    window.location.assign(path);  # jac:ignore[E1032,W2001]
}
```

- [ ] **Step 2: Redirect on verify in `welcome.impl.jac`**

Replace `impl Welcome.refresh -> None` with:

```jac
impl Welcome.refresh -> None {
    state: VerificationState | None = None;
    profile: ProfileView | None = None;
    state = await my_verification();
    verified = state.verified;
    verified_email = state.email;
    if verified {
        profile = await get_my_profile();
        if not profile.onboarding_done {
            go("/onboarding");
        }
    }
}
```

- [ ] **Step 3: Backstop redirect in `Today.load`**

In `journey/screens/today.jac`, add to the imports:

```jac
import from core.profile { get_my_profile, ProfileView }
import from journey.screens.common { go }
```

Replace `impl Today.load -> None` with:

```jac
impl Today.load -> None {
    profile: ProfileView | None = None;
    profile = await get_my_profile();
    if not profile.onboarding_done {
        go("/onboarding");
        return;
    }
    fresh: list[JourneyPrompt] = [];
    fresh = await my_journey_prompts();
    prompts = fresh;
    journey: JourneySummary | None = None;
    journey = await my_journey();
    summary = journey;
    loaded = True;
}
```

- [ ] **Step 4: Type-check and format**

Run: `jac check .`
Expected: no new errors.

Run: `jac fmt --check core/screens/welcome.jac core/screens/welcome.impl.jac journey/screens/today.jac`
Expected: clean, or fix with `jac fmt --lintfix <file>`.

- [ ] **Step 5: Manual QA**

Run: `UARRIVED_DEV_MODE=1 jac run --dev main.jac`. Sign up a brand-new `@umich.edu` address (dev mode
gives an inline verification token per `CONTRIBUTING.md`/existing test helper `verify()`), confirm
verification, and observe the app lands on `/onboarding`, not `/market` or `/today`. Finish or skip
through the wizard, confirm it lands on `/today`. Reload `/today` directly and confirm no redirect
loop. Manually visit `/onboarding` again afterward and confirm it just shows the wizard (no forced
redirect back to `/today`), per the Review Focus item on revisiting after finishing.

- [ ] **Step 6: Commit**

```bash
git add core/screens/welcome.jac core/screens/welcome.impl.jac journey/screens/today.jac
git commit -m "feat(journey): gate Welcome and Today behind the arrival onboarding wizard"
```

---

### Task 6: Whole-branch verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full suite**

Run: `bash scripts/test.sh`
Expected: PASS, no regressions anywhere (marketplace tests included).

- [ ] **Step 2: Run the repo rules check**

Run: `bash scripts/check_rules.sh`
Expected: PASS (Jac share, `journey/`/`market/` boundary, no raw colors outside `ui/tokens.jac`).

- [ ] **Step 3: Run formatting check across everything touched**

Run: `jac fmt --check .`
Expected: PASS, or fix per-file with `jac fmt --lintfix <file>` and re-run.

- [ ] **Step 4: Final manual QA pass**

Repeat Task 4 Step 6 and Task 5 Step 5's manual walkthroughs once more end to end on the final state of
the branch (signup → verify → onboarding, all 4 steps, both filled and skipped paths → `/today`).

No commit here — this task only confirms the five commits from Tasks 1-5 are collectively green. Once
confirmed, use `/ship` (or ask to open the PR) when ready to push and open the pull request; this plan
does not push or open a PR on its own.
