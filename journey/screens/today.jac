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
import from journey.interests { has_interests }

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

"""Gated in sequence, not concurrently: the arrival wizard first (onboarding_done), then the
one-time interest pick (has_interests) once that's done. Running both checks concurrently (each
its own fire-and-forget async call) would race two navigations against each other for a brand new
student who needs both."""
impl Today.load -> None {
    try {
        profile: ProfileView | None = None;
        profile = await get_my_profile();
        if not profile.onboarding_done {
            go("/onboarding");
            return;
        }
        got_interests: bool = await has_interests();
        if not got_interests {
            go("/interests?next=/today");
            return;
        }
    } except Exception as err {
        # A failed gate check must not leave the screen permanently blank with no signal --
        # log it and fall through to loading the journey content anyway (fail open, matching
        # translate_journey_texts's degrade-rather-than-block convention in journey/guide.jac).
        print("Today.load gate check failed: " + str(err));
    }
    fresh: list[JourneyPrompt] = [];
    try {
        fresh = await my_journey_prompts();
        prompts = fresh;
        journey: JourneySummary | None = None;
        journey = await my_journey();
        summary = journey;
    } except Exception as err {
        print("Today.load failed: " + str(err));
    }
    loaded = True;
}
