"""Today: the next first-week task and progress (links into /journey), then journey prompts that
lead into the marketplace (the DTW ride share).
"""

import from ui.tokens { color, space, text_style }
import from ui.components.base { AppShell, Card, Badge }
import from ui.components.blocks { ProgressBar, LevelBadge, SectionLabel }
import from journey.prompts { my_journey_prompts, JourneyPrompt }
import from journey.walkers { my_journey, JourneySummary }
import from journey.screens.journey { TaskListCard }
import from core.profile { get_my_profile, ProfileView }
import from journey.screens.common { go }

def:pub same_text(s: str) -> str {
    return s;
}

def:pub Today -> JsxElement {
    has prompts: list[JourneyPrompt] = [],
        summary: JourneySummary | None = None,
        loaded: bool = False;

    async def load -> None;

    can with entry {
        load();
    }

    next_views = [
        v
        for v in summary.tasks
        if v.task.tid == summary.next_tid
    ]
        if summary is not None
        else [];

    <AppShell title="Today" active="today">
        {(
            <Card>
                <div
                    style={{
                        "display": "flex",
                        "alignItems": "center",
                        "justifyContent": "space-between"
                    }}
                >
                    <SectionLabel label="Your first week"/>
                    <LevelBadge level={summary.level}/>
                </div>
                <ProgressBar
                    done={summary.required_done}
                    total={summary.required_total}
                    label={f"{summary.required_done} of {summary.required_total} essentials done"}
                />
                <a href="/journey" style={text_style("meta")}>
                    See all first-week tasks
                </a>
            </Card>
        )
            if summary is not None
            else None}{<TaskListCard v={next_views[0]} tx={same_text} next={True}/>
            if len(next_views) > 0
            else None}{(
            <Card>
                <p style={{"margin": "0"}}>
                    Nothing to suggest yet. Add your arrival date and whether you need an airport ride in Profile.
                </p>
            </Card>
        )
            if loaded and len(prompts) == 0
            else None}{[
            <Card key={p.key}>
                <strong style={{"fontSize": "18px"}}>{p.title}</strong>
                <p style={{"margin": "0", "color": color("text-2")}}>{p.body}</p>
                <a
                    href={p.link}
                    style={{
                        "display": "inline-flex",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "minHeight": "44px",
                        "borderRadius": "12px",
                        "background": color("action"),
                        "color": color("on-action"),
                        "fontWeight": "600",
                        "textDecoration": "none"
                    }}
                >
                    {p.action_label}
                </a>
            </Card> for p in prompts
        ]}
    </AppShell>
}

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
