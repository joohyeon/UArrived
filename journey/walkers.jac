"""First-week journey rules and progress (Feature A). Deterministic: which tasks apply to a
student, their order, and what "done" means live here and in the task file. Never imports ai/
(scripts/check_rules.sh).

A student's progress is one `TaskProgress` node per task on their own root: the steps they have
ticked and whether they marked the task done. XP and level are derived from done tasks, never
stored, so they cannot drift or be awarded twice. "Done" is the student's own claim: screens say
"Marked done by you", never anything that sounds like official completion.
"""

import from core.profile { Profile, my_profile }
import from journey.constants { XP_PER_LEVEL }
import from journey.task_data { JourneyTask, TaskPlace, all_tasks, task_by_id }

# Tasks only international (F-1 / J-1) students need. A student who hasn't said what kind of
# student they are sees everything.
glob INTERNATIONAL_ONLY: list[str] = [
         "mandatory_immigration_checkin",
         "international_center",
         "ssn"
     ],
     # Suggested order within required / optional. Unknown (newly added) tasks go last.
     ORDER: list[str] = [
         "mandatory_immigration_checkin",
         "mcard",
         "mobile",
         "international_center",
         "tuition",
         "medical",
         "banking",
         "campus_tour",
         "ssn"
     ],
     # Do these first: the task asks you to bring or use what they give you (MCard, US phone,
     # the International Center's letter). Advice for the order, not a lock.
     PREREQUISITES: dict[str, list[str]] = {
         "banking": ["mcard", "mobile"],
         "medical": ["mcard"],
         "ssn": ["international_center"]
     };

node TaskProgress {
    has tid: str,
        checked: list[bool] = [],
        done: bool = False;
}

"""A task as one student sees it: content, their status and ticked steps, and what to do first."""
obj TaskView {
    has task: JourneyTask,
        status: str,
        checked: list[bool],
        do_first: list[str];
}

obj JourneySummary {
    has tasks: list[TaskView],
        next_tid: str,
        xp: int,
        level: int,
        xp_into_level: int,
        done: int,
        total: int,
        required_done: int,
        required_total: int,
        verified: str;
}

obj TaskResult {
    has ok: bool,
        error: str = "",
        task: TaskView | None = None;
}

def applies(task: JourneyTask, student_type: str) -> bool {
    return student_type in ["", "international"] or task.tid not in INTERNATIONAL_ONLY;
}

def order_key(task: JourneyTask) -> tuple[int, int] {
    pos = ORDER.index(task.tid) if task.tid in ORDER else len(ORDER);
    return (0 if task.required else 1, pos);
}

"""The tasks that apply to this student, required first, in the suggested order."""
def tasks_for(student_type: str) -> list[JourneyTask] {
    return sorted(
        [
            t
            for t in all_tasks()
            if applies(t, student_type)
        ],
        key=order_key
    );
}

"""Steps ticked so far, reset if the task's step list changed length since they were ticked."""
def checked_for(task: JourneyTask, p: TaskProgress | None) -> list[bool] {
    if p is None or len(p.checked) != len(task.steps) {
        return [False for _ in task.steps];
    }
    return p.checked;
}

def status_of(task: JourneyTask, p: TaskProgress | None) -> str {
    if p is not None and p.done {
        return "done";
    }
    return "started" if any(checked_for(task, p)) else "todo";
}

def progress_map -> dict[str, TaskProgress] {
    return {p.tid: p for p in [root-->][?:TaskProgress]};
}

def progress_for(tid: str) -> TaskProgress {
    for p in [root-->][?:TaskProgress] {
        if p.tid == tid {
            return p;
        }
    }
    return root ++> TaskProgress(tid=tid);
}

"""Prerequisites of `task` (among the student's tasks) not yet marked done, by short name."""
def open_prerequisites(
    task: JourneyTask, shown: list[JourneyTask], done_ids: list[str]
) -> list[str] {
    wanted = PREREQUISITES.get(task.tid, []);
    return [
        t.short
        for t in shown
        if t.tid in wanted and t.tid not in done_ids
    ];
}

def view_of(
    task: JourneyTask,
    p: TaskProgress | None,
    shown: list[JourneyTask],
    done_ids: list[str]
) -> TaskView {
    return TaskView(
        task=task,
        status=status_of(task, p),
        checked=checked_for(task, p),
        do_first=open_prerequisites(task, shown, done_ids)
    );
}

"""The whole journey for a student type and their progress (pure; the endpoint adds the graph)."""
def summarize(student_type: str, progress: dict[str, TaskProgress]) -> JourneySummary {
    shown = tasks_for(student_type);
    done_ids = [
        t.tid
        for t in shown
        if t.tid in progress and progress[t.tid].done
    ];
    views = [view_of(t, progress.get(t.tid), shown, done_ids) for t in shown];
    xp = sum(
        [
            t.xp
            for t in shown
            if t.tid in done_ids
        ]
    );
    required = [
        t
        for t in shown
        if t.required
    ];
    # Next: the first open task whose prerequisites are done; else the first open task.
    open_views = [
        v
        for v in views
        if v.status != "done"
    ];
    ready = [
        v
        for v in open_views
        if len(v.do_first) == 0
    ];
    next_tid = ready[0].task.tid
        if ready
        else (open_views[0].task.tid if open_views else "");
    return JourneySummary(
        tasks=views,
        next_tid=next_tid,
        xp=xp,
        level=xp // XP_PER_LEVEL + 1,
        xp_into_level=xp % XP_PER_LEVEL,
        done=len(done_ids),
        total=len(shown),
        required_done=len(
            [
                t
                for t in required
                if t.tid in done_ids
            ]
        ),
        required_total=len(required),
        verified=shown[0].verified if shown else ""
    );
}

def task_view(tid: str) -> TaskView | None {
    summary = summarize(my_profile().student_type, progress_map());
    for v in summary.tasks {
        if v.task.tid == tid {
            return v;
        }
    }
    return None;
}

"""The caller's first-week journey: their tasks in order, progress, XP and level."""
def:protect my_journey -> JourneySummary {
    return summarize(my_profile().student_type, progress_map());
}

"""Tick or untick step `index` of a task. Ticking a step of a done task reopens it."""
def:protect toggle_task_step(tid: str, index: int) -> TaskResult {
    task = task_by_id(tid);
    if task is None or not applies(task, my_profile().student_type) {
        return TaskResult(ok=False, error="No such task.");
    }
    if index < 0 or index >= len(task.steps) {
        return TaskResult(ok=False, error="No such step.");
    }
    p = progress_for(tid);
    flags = checked_for(task, p);
    flags[index] = not flags[index];
    p.checked = flags;
    if not flags[index] {
        p.done = False;
    }
    return TaskResult(ok=True, task=task_view(tid));
}

"""Mark a task done. Every step must be ticked first, unless `skip_step_check` — used only by the
arrival wizard's self-report of a task finished before the student arrived."""
def:protect mark_task_done(tid: str, skip_step_check: bool = False) -> TaskResult {
    task = task_by_id(tid);
    if task is None or not applies(task, my_profile().student_type) {
        return TaskResult(ok=False, error="No such task.");
    }
    p = progress_for(tid);
    # An omitted bool parameter arrives as the string "False" (the same jaclang 0.37 quirk
    # CLAUDE.md documents for `str | None = None`, generalized): coerce instead of trusting
    # Python truthiness, which treats the non-empty string "False" as truthy.
    bypass = str(skip_step_check).strip().lower() == "true";
    if not bypass and not all(checked_for(task, p)) {
        return TaskResult(ok=False, error="Tick every step first.");
    }
    p.checked = [True for _ in task.steps];
    p.done = True;
    return TaskResult(ok=True, task=task_view(tid));
}

"""Undo "mark done"; the ticked steps stay."""
def:protect reopen_task(tid: str) -> TaskResult {
    task = task_by_id(tid);
    if task is None {
        return TaskResult(ok=False, error="No such task.");
    }
    p = progress_for(tid);
    p.done = False;
    return TaskResult(ok=True, task=task_view(tid));
}

test "task applicability: domestic students don't get international-only tasks" {
    all_ids = [t.tid for t in tasks_for("")];
    intl_ids = [t.tid for t in tasks_for("international")];
    domestic = [t.tid for t in tasks_for("in-state")];
    assert all_ids == intl_ids;
    for tid in INTERNATIONAL_ONLY {
        assert tid in intl_ids and tid not in domestic , tid;
    }
    assert "mcard" in domestic and "tuition" in domestic;
}

test "prerequisite order: required first, prerequisites before the tasks that need them" {
    ids = [t.tid for t in tasks_for("international")];
    tasks = tasks_for("international");
    first_optional = [
        i
        for (i, t) in enumerate(tasks)
        if not t.required
    ][0];
    assert all([t.required for t in tasks[:first_optional]]);
    for (tid, needs) in PREREQUISITES.items() {
        for need in needs {
            assert ids.index(need) < ids.index(tid) , f"{need} before {tid}";
        }
    }
}

test "next task skips a task whose prerequisites are open" {
    s = summarize("international", {});
    assert s.next_tid == "mandatory_immigration_checkin";
    bank = [
        v
        for v in s.tasks
        if v.task.tid == "banking"
    ][0];
    assert bank.do_first == ["MCard", "Phone"];
    done = {
        tid: TaskProgress(tid=tid, done=True)
        for tid in [
            "mandatory_immigration_checkin",
            "mcard",
            "mobile",
            "international_center",
            "tuition",
            "medical"
        ]
    };
    s2 = summarize("international", done);
    assert s2.next_tid == "banking";
    assert [
        v
        for v in s2.tasks
        if v.task.tid == "banking"
    ][0].do_first
        == [];
}

test "user progress is not official completion: XP comes only from tasks marked done" {
    mcard = task_by_id("mcard");
    assert mcard is not None;
    ticked = TaskProgress(tid="mcard", checked=[True for _ in mcard.steps]);
    s = summarize("international", {"mcard": ticked});
    view = [
        v
        for v in s.tasks
        if v.task.tid == "mcard"
    ][0];
    assert view.status == "started" and s.xp == 0 and s.done == 0;
    ticked.done = True;
    s2 = summarize("international", {"mcard": ticked});
    assert s2.xp == mcard.xp and s2.done == 1 and s2.level == 1;
    assert s2.xp_into_level == mcard.xp;
}

test "a changed step list resets the ticks instead of misaligning them" {
    mcard = task_by_id("mcard");
    assert mcard is not None;
    stale = TaskProgress(tid="mcard", checked=[True]);
    assert checked_for(mcard, stale) == [False for _ in mcard.steps];
}
