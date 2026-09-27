"""Today: a short greeting, the next first-week step and progress, arrival prompts that lead into
the marketplace (the DTW ride share), and on the side what's on around campus and quick ways into
the Market. Two columns on wide screens, one on phones. Students who haven't finished the arrival
wizard are sent to /onboarding first.
"""

import from ui.tokens { color, space, text_style, RADIUS }
import from ui.components.base { AppShell, Card }
import from ui.components.blocks { ProgressBar, LevelBadge, SectionLabel }
import from journey.prompts { my_journey_prompts, JourneyPrompt }
import from journey.walkers { my_journey, JourneySummary }
import from journey.events { upcoming_events, EventView }
import from journey.screens.journey { TaskListCard }
import from core.profile { get_my_profile, ProfileView }
import from journey.screens.common { go }

def:pub same_text(s: str) -> str {
    return s;
}

def:pub TodayStyles -> JsxElement {
    <style>
        {".td-grid{display:grid;grid-template-columns:minmax(0,1fr);gap:16px;align-items:start}"
            + "@media (min-width: 900px){.td-grid{grid-template-columns:minmax(0,3fr) minmax(0,2fr);gap:24px}}"}
    </style>
}

"""A labelled link row: the action in bold, one line of detail, a chevron."""
def:pub QuickLink(href: str, title: str, text: str) -> JsxElement {
    <a
        href={href}
        style={{
            "display": "flex",
            "alignItems": "center",
            "gap": space("3"),
            "minHeight": "56px",
            "padding": space("2") + " 0",
            "borderTop": "1px solid " + color("border"),
            "textDecoration": "none",
            "color": color("text")
        }}
    >
        <span style={{"flexGrow": "1", "display": "flex", "flexDirection": "column"}}>
            <strong style={text_style("card-title")}>{title}</strong>
            <span style={{** text_style("small"), "color": color("sub")}}>{text}</span>
        </span>
        <span aria-hidden="true" style={{"color": color("sub"), "fontSize": "20px"}}>
            ›
        </span>
    </a>
}

def:pub TodayEvent(e: EventView) -> JsxElement {
    <li
        style={{
            "display": "flex",
            "flexDirection": "column",
            "gap": "2px",
            "padding": space("3") + " 0",
            "borderTop": "1px solid " + color("border")
        }}
    >
        <span style={{** text_style("meta"), "color": color("coral-ink")}}>
            {e.when}
        </span>
        <a
            href={e.url}
            target="_blank"
            rel="noopener noreferrer"
            style={{
                ** text_style("card-title"),
                "color": color("text"),
                "textDecoration": "none"
            }}
        >
            {e.title}
        </a>
        <span style={{** text_style("small"), "color": color("sub")}}>
            {e.location}
        </span>
    </li>
}

def:pub Today -> JsxElement {
    has prompts: list[JourneyPrompt] = [],
        summary: JourneySummary | None = None,
        events: list[EventView] = [],
        name: str = "",
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
    first_name = name.split(" ")[0] if name else "";

    <AppShell title="Today" active="today" wide={True}>
        <TodayStyles/>
        <p
            style={{
                ** text_style("body"),
                "margin": "-8px 0 0",
                "color": color("text-2")
            }}
        >
            {("Hi " + first_name + ". " if first_name else "")
                + (
                    "Here's your next step."
                        if len(next_views) > 0
                        else "Here's what's on."
                )}
        </p>
        <div className="td-grid">
            <div
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("4")
                }}
            >
                {(
                    <section
                        style={{
                            "display": "flex",
                            "flexDirection": "column",
                            "gap": space("2")
                        }}
                    >
                        <SectionLabel label="Up next"/>
                        <TaskListCard v={next_views[0]} tx={same_text} next={True}/>
                    </section>
                )
                    if len(next_views) > 0
                    else None}{(
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
                        <a
                            href="/journey"
                            style={{
                                ** text_style("meta"),
                                "minHeight": "44px",
                                "display": "inline-flex",
                                "alignItems": "center"
                            }}
                        >
                            See all first-week tasks
                        </a>
                    </Card>
                )
                    if summary is not None
                    else <p style={{"color": color("sub")}}>
                        Loading your first week…
                    </p>}{[
                    <Card key={p.key}>
                        <strong style={text_style("card-title")}>{p.title}</strong>
                        <p
                            style={{
                                ** text_style("body"),
                                "margin": "0",
                                "color": color("text-2")
                            }}
                        >
                            {p.body}
                        </p>
                        <a
                            href={p.link}
                            style={{
                                "display": "inline-flex",
                                "alignItems": "center",
                                "justifyContent": "center",
                                "minHeight": "44px",
                                "borderRadius": f"{RADIUS['button']}px",
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
            </div>
            <div
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("4")
                }}
            >
                <Card>
                    <SectionLabel label="Around campus"/>
                    {(
                        <ul
                            style={{"listStyle": "none", "margin": "0", "padding": "0"}}
                        >
                            {[<TodayEvent key={e.eid} e={e}/> for e in events]}
                        </ul>
                    )
                        if len(events) > 0
                        else (
                            <p
                                style={{
                                    ** text_style("small"),
                                    "margin": "0",
                                    "color": color("sub")
                                }}
                            >
                                {"Loading events…"
                                    if not loaded
                                    else "No upcoming events listed right now."}
                            </p>
                        )}
                    <a
                        href="/journey/events"
                        style={{
                            ** text_style("meta"),
                            "minHeight": "44px",
                            "display": "inline-flex",
                            "alignItems": "center"
                        }}
                    >
                        See all events
                    </a>
                </Card>
                <Card>
                    <SectionLabel label="Buy, sell and find a place"/>
                    <QuickLink
                        href="/market"
                        title="Post in a group"
                        text="Furniture, Housing & sublets, Rides and more"
                    />
                    <QuickLink
                        href="/market/matches"
                        title="Your matches"
                        text="Students buying or selling what you posted"
                    />
                    <QuickLink
                        href="/market/chats"
                        title="Messages"
                        text="Your private chats"
                    />
                </Card>
            </div>
        </div>
    </AppShell>
}

impl Today.load -> None {
    profile: ProfileView | None = None;
    profile = await get_my_profile();
    if not profile.onboarding_done {
        go("/onboarding");
        return;
    }
    name = profile.display_name;
    fresh: list[JourneyPrompt] = [];
    fresh = await my_journey_prompts();
    prompts = fresh;
    journey: JourneySummary | None = None;
    journey = await my_journey();
    summary = journey;
    upcoming: list[EventView] = [];
    try {
        upcoming = await upcoming_events("All", False);
    } except Exception as err {
        upcoming = [];
    }
    events = upcoming[:3];
    loaded = True;
}
