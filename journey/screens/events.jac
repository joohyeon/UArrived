"""/events: upcoming U-M events for new students, as a list or on the map, filtered by category
and cost. Each event links to its official U-M Happening page. Tapping a map pin lists that
venue's events (`?venue=`). Its own bottom-nav tab (U4, plan 2026-09-27-003) -- no longer nested
under Journey, so it doesn't render Journey's Tasks/Events sub-tab strip."""

import from ui.tokens { color, space, text_style }
import from ui.components.base { AppShell, Card, Badge, ResponsiveGrid }
import from ui.components.blocks { Chip, SegmentedControl, SectionLabel }
import from ui.components.map { MapCanvas }
import from journey.constants { EVENT_CATEGORIES, ANN_ARBOR_BOUNDS, CAMPUS_CENTER }
import from journey.events { upcoming_events, EventView }
import from journey.guide { translate_journey_texts }
import from journey.screens.common { query_param }

def:pub event_when(e: EventView) -> str {
    when = e.date + (" " + e.time if e.time else "");
    return when + (" – " + e.time_end if e.time_end else "");
}

def:pub EventCard(e: EventView, tx: Callable[[str], str]) -> JsxElement {
    small = text_style("small");
    <Card>
        <div style={{"display": "flex", "gap": space("2"), "flexWrap": "wrap"}}>
            <Badge kind="neutral" label={tx(e.category)}/>
            {<Badge kind="progress" label="Free"/> if e.free else None}
        </div>
        <strong style={text_style("card-title")}>{tx(e.title)}</strong>
        <span style={{** small, "color": color("text-2")}}>{event_when(e)}</span>
        <span style={{** small, "color": color("sub")}}>
            {"Online" if e.virtual else e.location}
        </span>
        {(
            <details>
                <summary
                    style={{
                        ** text_style("meta"),
                        "cursor": "pointer",
                        "minHeight": "44px"
                    }}
                >
                    About this event
                </summary>
                <p
                    style={{
                        ** small,
                        "color": color("text-2"),
                        "whiteSpace": "pre-wrap"
                    }}
                >
                    {e.summary}
                </p>
                {<p style={{** small, "color": color("sub")}}>{"Cost: " + e.cost}</p>
                    if e.cost
                    else None}
                {<p style={{** small, "color": color("sub")}}>{e.sponsor}</p>
                    if e.sponsor
                    else None}
            </details>
        )
            if e.summary
            else None}
        {(
            <a
                href={e.url}
                target="_blank"
                rel="noopener noreferrer"
                style={text_style("meta")}
            >
                Official event page
            </a>
        )
            if e.url
            else None}
    </Card>
}

def:pub Events -> JsxElement {
    has events: list[EventView] = [],
        loaded: bool = False,
        category: str = "All",
        free_only: bool = False,
        view: str = "list",
        venue: str = "",
        words: dict[str, str] = {};

    async def load(cat: str, free: bool) -> None;

    can with entry {
        venue = query_param("venue");
        load("All", False);
    }

    def tx(s: str) -> str {
        return words.get(s, s);
    }

    def pick(cat: str) {
        category = cat;
        venue = "";
        load(cat, free_only);
    }

    def toggleFree {
        now = not free_only;
        free_only = now;
        load(category, now);
    }

    shown = [
        e
        for e in events
        if venue == "" or e.venue == venue
    ];
    online = len(
        [
            e
            for e in shown
            if e.lat == 0.0
        ]
    );
    pins: list[dict[str, any]] = [];
    spots: dict[str, int] = {};
    for e in events {
        if e.lat == 0.0 {
            continue;
        }
        if e.venue in spots {
            pins[spots[e.venue]]["count"] = pins[spots[e.venue]]["count"] + 1;
            continue;
        }
        spots[e.venue] = len(pins);
        pins.append(
            {
                "key": e.venue,
                "wx": e.wx,
                "wy": e.wy,
                "label": e.venue,
                "href": "/events?venue=" + encodeURIComponent(e.venue),  # jac:ignore[W2001]
                "state": "event",
                "count": 1
            }
        );
    }

    <AppShell title="Events" active="events" wide={True}>
        <div
            role="group"
            aria-label="Category"
            style={{
                "display": "flex",
                "gap": space("2"),
                "overflowX": "auto",
                "paddingBottom": space("1")
            }}
        >
            {[
                <Chip
                    key={c}
                    label={"All" if c == "All" else tx(c)}
                    selected={c == category}
                    onSelect={lambda { pick(c); }}
                /> for c in EVENT_CATEGORIES
            ]}
        </div>
        <div
            style={{
                "display": "flex",
                "justifyContent": "space-between",
                "alignItems": "center",
                "gap": space("2"),
                "flexWrap": "wrap"
            }}
        >
            <Chip label="Free only" selected={free_only} onSelect={toggleFree}/>
            <SegmentedControl
                label="Show events as"
                options={[("list", "List"), ("map", "Map")]}
                value={view}
                onChange={lambda (v: str) { view = v; }}
            />
        </div>
        {(
            <div
                style={{
                    "display": "flex",
                    "gap": space("2"),
                    "alignItems": "center",
                    "flexWrap": "wrap"
                }}
            >
                <SectionLabel label={"At " + venue}/>
                <a href="/events" style={text_style("meta")}>Show all venues</a>
            </div>
        )
            if venue
            else None}
        {<p style={{"color": color("sub")}}>Loading events…</p> if not loaded else None}
        {<Card>
            <p style={{"margin": "0"}}>No upcoming events match.</p>
        </Card>
            if loaded and len(shown) == 0
            else None}
        {<Badge kind="ai" label="Translated by AI"/> if len(words) > 0 else None}
        {(
            <MapCanvas
                pins={pins}
                center={CAMPUS_CENTER}
                bounds={ANN_ARBOR_BOUNDS}
                start_zoom={15}
                height={460}
            />
        )
            if view == "map"
            else None}
        {(
            <p style={{** text_style("small"), "color": color("sub"), "margin": "0"}}>
                {f"{online} online or unmapped events are in the list."}
            </p>
        )
            if view == "map" and online > 0
            else None}
        {(
            <ResponsiveGrid min="300px">
                {[<EventCard key={e.eid} e={e} tx={tx}/> for e in shown]}
            </ResponsiveGrid>
        )
            if view == "list"
            else None}
        <p style={{** text_style("caption"), "color": color("sub"), "margin": "0"}}>
            From U-M Happening. Check the official event page before you go.
        </p>
    </AppShell>
}

impl Events.load(cat: str, free: bool) -> None {
    fresh: list[EventView] = [];
    fresh = await upcoming_events(cat, free);
    events = fresh;
    loaded = True;
    sources: list[str] = [c for c in EVENT_CATEGORIES] + [e.title for e in fresh[:60]];
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
