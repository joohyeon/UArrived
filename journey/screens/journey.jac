"""/journey: the first-week task list and map (Feature A), ported from the Orientation Quest
prototype. Level and XP on top, the next essential task, then every task as a list or as pins on
the Ann Arbor map. Task text shows in the student's language when AI translation is available,
labeled "Translated by AI"."""

import from ui.tokens { color, space, text_style }
import from ui.components.base { AppShell, Card, Badge, ResponsiveGrid }
import from ui.components.blocks {
    ProgressBar,
    RewardPill,
    LevelBadge,
    SegmentedControl,
    SectionLabel
}
import from journey.constants { XP_PER_LEVEL }
import from journey.walkers { my_journey, JourneySummary, TaskView }
import from journey.guide { translate_journey_texts }
import from journey.screens.common {
    JourneyTabs,
    StatusBadge,
    SourceNote,
    TaskMap,
    query_param
}

"""One task in the list: the whole card links to its detail."""
def:pub TaskListCard(
    v: TaskView, tx: Callable[[str], str], next: bool = False
) -> JsxElement {
    total = len(v.checked);
    ticked = len(
        [
            c
            for c in v.checked
            if c
        ]
    );
    place = v.task.places[0].name if len(v.task.places) > 0 else "";
    more = len(v.task.places) - 1;
    meta = text_style("small");
    <a
        href={"/journey/task?id=" + v.task.tid}
        style={{
            "display": "flex",
            "flexDirection": "column",
            "gap": space("2"),
            "padding": space("4"),
            "textDecoration": "none",
            "color": color("text"),
            "background": color("card"),
            "border": ("2px solid " + color("action"))
                if next
                else ("1px solid " + color("border")),
            "borderRadius": "16px",
            "boxShadow": "0 2px 8px " + color("shadow")
        }}
    >
        <div style={{"display": "flex", "gap": space("2"), "flexWrap": "wrap"}}>
            {<Badge kind="action" label="NEXT ESSENTIAL"/> if next else None}
            <Badge
                kind={"official" if v.task.required else "neutral"}
                label={"Required" if v.task.required else "Optional"}
            />
            <StatusBadge status={v.status}/>
        </div>
        <strong style={text_style("card-title")}>{tx(v.task.title)}</strong>
        {<span style={{** meta, "color": color("sub")}}>
            {place
                + (
                    f" + {more} more place" + ("s" if more > 1 else "")
                        if more > 0
                        else ""
                )}
        </span>
            if place
            else None}
        <div
            style={{
                "display": "flex",
                "justifyContent": "space-between",
                "gap": space("2")
            }}
        >
            <span style={{** meta, "color": color("text-2")}}>
                {f"{ticked} of {total} steps"}
            </span>
            <RewardPill label={f"+{v.task.xp} XP"}/>
        </div>
        {<span style={{** meta, "color": color("warning")}}>
            {"Do first: " + ", ".join([tx(x) for x in v.do_first])}
        </span>
            if len(v.do_first) > 0 and v.status != "done"
            else None}
    </a>
}

def:pub JourneyHome -> JsxElement {
    has summary: JourneySummary | None = None,
        view: str = "list",
        words: dict[str, str] = {},
        error: str = "";

    async def load -> None;

    can with entry {
        view = "map" if query_param("view") == "map" else "list";
        load();
    }

    def tx(s: str) -> str {
        return words.get(s, s);
    }

    def switchView(v: str) {
        view = v;
    }

    <AppShell title="Your first week" active="journey" wide={True}>
        <JourneyTabs active="/journey"/>
        {(
            <Card>
                <div
                    style={{
                        "display": "flex",
                        "alignItems": "center",
                        "gap": space("3")
                    }}
                >
                    <LevelBadge level={summary.level}/>
                    <span style={{** text_style("meta"), "color": color("text-2")}}>
                        {f"{summary.xp} XP · {XP_PER_LEVEL
                            - summary.xp_into_level} XP to the next level"}
                    </span>
                </div>
                <ProgressBar
                    done={summary.required_done}
                    total={summary.required_total}
                    label={f"{summary.required_done} of {summary.required_total} essentials done"}
                />
                {<Badge kind="ai" label="Translated by AI"/>
                    if len(words) > 0
                    else None}
            </Card>
        )
            if summary is not None
            else <p style={{"color": color("danger") if error else color("sub")}}>
                {error or "Loading your tasks…"}
            </p>}
        {(
            <div
                style={{
                    "display": "flex",
                    "justifyContent": "space-between",
                    "alignItems": "center",
                    "gap": space("2"),
                    "flexWrap": "wrap"
                }}
            >
                <SectionLabel
                    label={f"{summary.done} of {summary.total} tasks marked done by you"}
                />
                <SegmentedControl
                    label="Show tasks as"
                    options={[("list", "List"), ("map", "Map")]}
                    value={view}
                    onChange={switchView}
                />
            </div>
        )
            if summary is not None
            else None}
        {(
            <ResponsiveGrid min="300px">
                {[
                    <TaskListCard
                        key={v.task.tid}
                        v={v}
                        tx={tx}
                        next={v.task.tid == summary.next_tid}
                    /> for v in summary.tasks
                ]}
            </ResponsiveGrid>
        )
            if summary is not None and view == "list"
            else None}
        {(<TaskMap views={summary.tasks} tx={tx} center={[]}/>)
            if summary is not None and view == "map"
            else None}
        {<SourceNote verified={summary.verified}/> if summary is not None else None}
    </AppShell>
}

impl JourneyHome.load -> None {
    fresh: JourneySummary | None = None;
    try {
        fresh = await my_journey();
    } except Exception as err {
        print("JourneyHome.load failed: " + str(err));
        error = "We couldn't load your tasks. Refresh to try again.";
        return;
    }
    if fresh is None {
        return;
    }
    error = "";
    summary = fresh;
    sources: list[str] = [];
    for v in fresh.tasks {
        sources = sources + [v.task.title, v.task.short];
    }
    outs: list[str] = [];
    outs = await translate_journey_texts(sources);
    found: dict[str, str] = {};
    for (i, src) in enumerate(sources) {
        if i < len(outs) and outs[i] != src {
            found[src] = outs[i];
        }
    }
    words = found;
}
