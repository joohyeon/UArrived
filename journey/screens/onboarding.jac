"""Arrival onboarding: a 4-step wizard collecting arrival date, housing, language and which
first-week tasks a student already finished before arriving. Each step's "Skip" advances without
writing that step's field(s). Welcome and Today redirect here until `onboarding_done` is set."""

import from ui.tokens { color, space }
import from ui.components.base { Button, Field }
import from ui.components.blocks {
    QuestionBlock,
    SectionLabel,
    ProgressDots,
    SelectableCard,
    OptionTile,
    ChecklistRow
}
import from core.constants { ANN_ARBOR_AREAS, PILOT_LANGUAGES, LANGUAGE_NAMES }
import from core.profile { update_my_profile, ProfileUpdateResult }
import from journey.walkers {
    my_journey,
    mark_task_done,
    reopen_task,
    JourneySummary,
    TaskView
}
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

    def skipStep(e: MouseEvent) {
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
            <div
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("4")
                }}
            >
                <QuestionBlock
                    eyebrow="Step 1 of 4"
                    title="When do you arrive in Ann Arbor?"
                />
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
                <Button
                    label="Skip"
                    onClick={skipStep}
                    variant="text"
                    disabled={saving}
                />
            </div>
        )
            if step == 0
            else None}
        {(
            <div
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("4")
                }}
            >
                <QuestionBlock eyebrow="Step 2 of 4" title="Where will you live?"/>
                <div
                    style={{
                        "display": "flex",
                        "flexDirection": "column",
                        "gap": space("2")
                    }}
                >
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
                <div
                    style={{
                        "display": "flex",
                        "flexDirection": "column",
                        "gap": space("2")
                    }}
                >
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
                <Button
                    label="Skip"
                    onClick={skipStep}
                    variant="text"
                    disabled={saving}
                />
            </div>
        )
            if step == 1
            else None}
        {(
            <div
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("4")
                }}
            >
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
                <Button
                    label="Skip"
                    onClick={skipStep}
                    variant="text"
                    disabled={saving}
                />
            </div>
        )
            if step == 2
            else None}
        {(
            <div
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("3")
                }}
            >
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
                        onToggle={lambda { toggleTask(
                            v.task.tid, v.status == "done"
                        ); }}
                        reward={("+" + str(v.task.xp) + " XP")
                            if v.task.required
                            else ""}
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
