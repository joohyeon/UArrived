"""/journey/task?id=…: one first-week task. Steps to tick, then "Mark as done" (the student's own
claim, shown as "Marked done by you"); what to bring, every place it can be done with hours, notes
and official links, a small map, and the way into the AI guide. Official content is labeled
Official; translated text is labeled Translated by AI."""

import from ui.tokens { color, space, text_style }
import from ui.components.base { AppShell, Button, Card, Badge }
import from ui.components.blocks {
    SectionLabel,
    ChecklistRow,
    ProgressBar,
    RewardPill,
    InfoCard,
    KeyValueRow,
    TopBar
}
import from journey.walkers {
    my_journey,
    toggle_task_step,
    mark_task_done,
    reopen_task,
    JourneySummary,
    TaskView,
    TaskResult
}
import from journey.task_data { TaskPlace }
import from journey.guide { translate_journey_texts }
import from journey.screens.common { StatusBadge, SourceNote, TaskMap, query_param }

def:pub Bullets(items: list[str], tx: Callable[[str], str]) -> JsxElement {
    <ul
        style={{
            ** text_style("small"),
            "margin": "0",
            "paddingLeft": "20px",
            "color": color("text-2"),
            "display": "flex",
            "flexDirection": "column",
            "gap": space("1")
        }}
    >
        {[<li key={str(i)}>{tx(x)}</li> for (i, x) in enumerate(items)]}
    </ul>
}

def:pub LinkList(links: list[str]) -> JsxElement {
    <ul style={{"margin": "0", "paddingLeft": "20px", "overflowWrap": "anywhere"}}>
        {[
            <li key={u}>
                <a
                    href={u}
                    target="_blank"
                    rel="noopener noreferrer"
                    style={text_style("small")}
                >
                    {u.replace("https://", "").replace("http://", "")}
                </a>
            </li> for u in links
        ]}
    </ul>
}

"""One place the task can be done: name, address, hours, and what's specific to it."""
def:pub PlaceCard(p: TaskPlace, tx: Callable[[str], str]) -> JsxElement {
    <Card>
        <strong style={text_style("card-title")}>{p.name}</strong>
        {<KeyValueRow label="Address" value={p.address}/> if p.address else None}
        {<KeyValueRow label="Hours" value={tx(p.hours)}/> if p.hours else None}
        {(
            <details>
                <summary
                    style={{
                        ** text_style("meta"),
                        "cursor": "pointer",
                        "minHeight": "44px"
                    }}
                >
                    More about this place
                </summary>
                {<SectionLabel label="What to bring here"/>
                    if len(p.bring) > 0
                    else None}
                {<Bullets items={p.bring} tx={tx}/> if len(p.bring) > 0 else None}
                {<SectionLabel label="Good to know"/> if len(p.notes) > 0 else None}
                {<Bullets items={p.notes} tx={tx}/> if len(p.notes) > 0 else None}
                {<LinkList links={p.links}/> if len(p.links) > 0 else None}
            </details>
        )
            if len(p.bring) + len(p.notes) + len(p.links) > 0
            else None}
    </Card>
}

def:pub TaskDetail -> JsxElement {
    has tid: str = "",
        view: TaskView | None = None,
        missing: bool = False,
        busy: bool = False,
        error: str = "",
        words: dict[str, str] = {};

    async def load -> None;
    async def toggle(index: int) -> None;
    async def finish -> None;
    async def reopen -> None;

    can with entry {
        load();
    }

    def tx(s: str) -> str {
        return words.get(s, s);
    }

    <AppShell
        title={tx(view.task.title) if view is not None else "Task"}
        active="journey"
    >
        <TopBar back_href="/journey" back_label="Your first week"/>
        {<Card>
            <p style={{"margin": "0"}}>This task isn't on your list.</p>
        </Card>
            if missing
            else None}
        {(
            <div
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("3")
                }}
            >
                <div style={{"display": "flex", "gap": space("2"), "flexWrap": "wrap"}}>
                    <Badge kind="official" label="Official info"/>
                    <Badge
                        kind={"action" if view.task.required else "neutral"}
                        label={"Required" if view.task.required else "Optional"}
                    />
                    <StatusBadge status={view.status}/>
                    <RewardPill label={f"+{view.task.xp} XP"}/>
                    {<Badge kind="ai" label="Translated by AI"/>
                        if len(words) > 0
                        else None}
                </div>
                {<p
                    style={{
                        ** text_style("body"),
                        "margin": "0",
                        "color": color("text-2")
                    }}
                >
                    {tx(view.task.description)}
                </p>
                    if view.task.description
                    else None}
                {(
                    <InfoCard label="Do these first" variant="advice">
                        <span>
                            {"You'll need what these give you: "
                                + ", ".join([tx(x) for x in view.do_first])
                                + "."}
                        </span>
                    </InfoCard>
                )
                    if len(view.do_first) > 0 and view.status != "done"
                    else None}
                <Card>
                    <ProgressBar
                        done={len(
                            [
                                c
                                for c in view.checked
                                if c
                            ]
                        )}
                        total={len(view.checked)}
                        label="Steps"
                    />
                    {[
                        <ChecklistRow
                            key={str(i)}
                            label={tx(step)}
                            checked={view.checked[i]}
                            onToggle={lambda { toggle(i); }}
                        /> for (i, step) in enumerate(view.task.steps)
                    ]}
                    {<p role="alert" style={{"margin": "0", "color": color("danger")}}>
                        {error}
                    </p>
                        if error
                        else None}
                    {(
                        <Button
                            label={"Mark as done"
                                if all(view.checked)
                                else "Tick every step to finish"}
                            full={True}
                            disabled={busy or not all(view.checked)}
                            onClick={lambda (e: MouseEvent) { finish(); }}
                        />
                    )
                        if view.status != "done"
                        else (
                            <div
                                style={{
                                    "display": "flex",
                                    "alignItems": "center",
                                    "gap": space("2")
                                }}
                            >
                                <Badge kind="progress" label="Marked done by you"/>
                                <Button
                                    label="Undo"
                                    variant="text"
                                    onClick={lambda (e: MouseEvent) { reopen(); }}
                                />
                            </div>
                        )}
                </Card>
                <a
                    href={"/journey/ask?id=" + view.task.tid}
                    style={{
                        "display": "flex",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "minHeight": "44px",
                        "borderRadius": "16px",
                        "border": "1px solid " + color("action-line"),
                        "background": color("card"),
                        "color": color("action"),
                        "fontWeight": "600",
                        "textDecoration": "none"
                    }}
                >
                    Have a question? Ask the AI guide
                </a>
                {(
                    <InfoCard label="What to bring">
                        <Bullets items={view.task.bring} tx={tx}/>
                    </InfoCard>
                )
                    if len(view.task.bring) > 0
                    else None}
                <SectionLabel
                    label={"Where"
                        if len(view.task.places) < 2
                        else f"Where: any one of {len(view.task.places)} places"}
                />
                {[
                    <PlaceCard key={str(i)} p={p} tx={tx}/>
                    for (i, p) in enumerate(view.task.places)
                ]}
                {(
                    <TaskMap
                        views={[view]}
                        tx={tx}
                        center={[view.task.places[0].wx, view.task.places[0].wy]}
                        height={280}
                        zoom={15}
                        max_width={688}
                    />
                )
                    if len(
                        [
                            p
                            for p in view.task.places
                            if p.lat != 0.0
                        ]
                    )
                        > 0
                    else None}
                {(
                    <InfoCard label="Before you go">
                        <Bullets items={view.task.notes} tx={tx}/>
                    </InfoCard>
                )
                    if len(view.task.notes) > 0
                    else None}
                {<KeyValueRow label="Cost" value={tx(view.task.cost)}/>
                    if view.task.cost
                    else None}
                {(
                    <Card>
                        <SectionLabel label="Official sources"/>
                        <LinkList links={view.task.links}/>
                    </Card>
                )
                    if len(view.task.links) > 0
                    else None}
                <SourceNote verified={view.task.verified}/>
            </div>
        )
            if view is not None
            else None}
    </AppShell>
}

impl TaskDetail.load -> None {
    wanted = query_param("id");
    tid = wanted;
    summary: JourneySummary | None = None;
    summary = await my_journey();
    found = [
        v
        for v in summary.tasks
        if v.task.tid == wanted
    ];
    if len(found) == 0 {
        missing = True;
        return;
    }
    v = found[0];
    view = v;
    sources: list[str] = [v.task.title, v.task.description, v.task.cost]
        + v.task.steps
        + v.task.bring
        + v.task.notes
        + v.do_first;
    for p in v.task.places {
        sources = sources + [p.hours] + p.bring + p.notes;
    }
    outs: list[str] = [];
    outs = await translate_journey_texts(sources);
    found_words: dict[str, str] = {};
    for (i, src) in enumerate(sources) {
        if i < len(outs) and outs[i] != src {
            found_words[src] = outs[i];
        }
    }
    words = found_words;
}

impl TaskDetail.toggle(index: int) -> None {
    result: TaskResult | None = None;
    result = await toggle_task_step(tid, index);
    if result.ok {
        view = result.task;
        error = "";
    } else {
        error = result.error;
    }
}

impl TaskDetail.finish -> None {
    busy = True;
    result: TaskResult | None = None;
    result = await mark_task_done(tid);
    if result.ok {
        view = result.task;
        error = "";
    } else {
        error = result.error;
    }
    busy = False;
}

impl TaskDetail.reopen -> None {
    result: TaskResult | None = None;
    result = await reopen_task(tid);
    if result.ok {
        view = result.task;
    }
}
