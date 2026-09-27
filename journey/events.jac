"""Upcoming U-M events for new students, read from journey/umich_event_data (U-M Happening export:
a JSON object of events keyed by id). Deterministic: categories come from the event type, map
spots from a venue keyword table; virtual or unknown venues are list-only (`lat == 0`).

Ported from the Orientation Quest prototype (events_source.jac), which fetched the same file from
GitHub at runtime; here it is read from disk and cached by modification time. "Upcoming" uses
core/clock, so tests can move today with UARRIVED_TODAY.
"""

import html;
import json;
import os;
import re;
import from core.clock { today_iso }
import from journey.task_data { world_px }

glob EVENT_FILE: str = os.path.join(
         os.path.dirname(os.path.abspath(__file__)), "umich_event_data"
     ),
     # The map's Ann Arbor bounds (south, north, west, east); events outside are list-only.
     AA_BOUNDS: tuple[float, float, float, float] = (
         42.2220,
         42.3230,
         -83.8500,
         -83.6750
     ),
     MAX_EVENTS: int = 120,
     _cache: dict[str, any] = {"mtime": -1.0, "events": []};

"""Venue keyword (lower case) -> (lat, lon, short label). First match wins."""
glob VENUES: list[tuple[str, float, float, str]] = [
         ("stamps gallery", 42.2799, -83.7486, "Stamps Gallery"),
         ("201 s", 42.2799, -83.7486, "Stamps Gallery"),
         ("art & architecture", 42.2892, -83.7169, "Art & Architecture"),
         ("bonisteel", 42.2892, -83.7169, "Art & Architecture"),
         ("district library pittsfield", 42.2403, -83.7058, "AADL Pittsfield"),
         ("district library", 42.2786, -83.7458, "AADL Downtown"),
         ("aadl", 42.2786, -83.7458, "AADL Downtown"),
         ("343 s", 42.2786, -83.7458, "AADL Downtown"),
         ("harper hall", 42.2856, -83.7355, "Harper Hall"),
         ("wolverine village", 42.2856, -83.7355, "Wolverine Village"),
         ("museum of art", 42.2752, -83.7397, "UMMA"),
         ("umma", 42.2752, -83.7397, "UMMA"),
         ("wesley foundation", 42.2818, -83.7408, "Wesley Foundation"),
         ("602 e huron", 42.2818, -83.7408, "Wesley Foundation"),
         ("st. andrew", 42.2825, -83.7489, "St. Andrew's Church"),
         ("306 n. division", 42.2825, -83.7489, "St. Andrew's Church"),
         ("michigan theater", 42.2793, -83.7436, "Michigan Theater"),
         ("603 e liberty", 42.2793, -83.7436, "Michigan Theater"),
         ("state theatre", 42.2792, -83.7410, "State Theatre"),
         ("233 s", 42.2792, -83.7410, "State Theatre"),
         ("trotter", 42.2758, -83.7402, "Trotter Center"),
         ("428 s state", 42.2758, -83.7402, "Trotter Center"),
         ("weiser hall", 42.2767, -83.7371, "Weiser Hall"),
         ("500 church", 42.2767, -83.7371, "Weiser Hall"),
         ("214 s. state", 42.2787, -83.7409, "214 S State St"),
         ("pizza house", 42.2743, -83.7336, "Pizza House"),
         ("literati", 42.2808, -83.7475, "Literati Bookstore"),
         (
             "institute for the humanities",
             42.2791,
             -83.7383,
             "Institute for the Humanities"
         ),
         ("202 s. thayer", 42.2791, -83.7383, "Institute for the Humanities"),
         ("1007 e. huron", 42.2809, -83.7331, "1007 E Huron"),
         ("ncrc", 42.3016, -83.7063, "NCRC"),
         ("2800 plymouth", 42.3016, -83.7063, "NCRC"),
         ("traverwood", 42.3063, -83.7131, "3333 Traverwood Dr"),
         ("eisenhower", 42.2458, -83.7118, "3090 E Eisenhower"),
         ("schuler", 42.2626, -83.7832, "Schuler's Books"),
         ("jackson ave", 42.2626, -83.7832, "Schuler's Books"),
         ("michigan union", 42.2750, -83.7417, "Michigan Union"),
         ("league", 42.2789, -83.7383, "Michigan League"),
         ("hill auditorium", 42.2792, -83.7387, "Hill Auditorium"),
         ("rackham", 42.2797, -83.7379, "Rackham"),
         ("duderstadt", 42.2911, -83.7164, "Duderstadt Center"),
         ("pierpont", 42.2913, -83.7174, "Pierpont Commons"),
         ("crisler", 42.2658, -83.7486, "Crisler Center"),
         ("yost", 42.2682, -83.7406, "Yost Ice Arena"),
         ("michigan stadium", 42.2658, -83.7487, "Michigan Stadium"),
         ("diag", 42.2770, -83.7382, "The Diag"),
         ("ann arbor, mich", 42.2770, -83.7390, "Ann Arbor (campus)")
     ];

"""Event type keywords -> category (first match wins)."""
glob CATEGORY_RULES: list[tuple[str, list[str]]] = [
         ("Learning", ["workshop", "class", "lecture", "conference", "presentation"]),
         ("Arts", ["exhibition", "performance", "film"]),
         ("Sports", ["sport", "fitness", "recreational"]),
         ("Careers", ["career"]),
         ("Social", ["social", "reception", "fair", "festival", "rally", "meeting"]),
         ("Well-being", ["well"]),
         ("Tours", ["tour"]),
         ("Community", ["community"])
     ];

obj EventView {
    has eid: str,
        title: str,
        etype: str,
        category: str,
        date: str,
        date_end: str,
        time: str,
        time_end: str,
        location: str,
        venue: str,
        virtual: bool,
        lat: float,
        lon: float,
        wx: float,
        wy: float,
        summary: str,
        cost: str,
        free: bool,
        url: str,
        sponsor: str;
}

def clean(s: any) -> str {
    if not s {
        return "";
    }
    t = html.unescape(str(s));
    t = re.sub("<[^>]+>", " ", t);
    t = re.sub("[ \\t]+", " ", t);
    t = re.sub("\\n\\s*\\n+", "\n\n", t);
    return t.strip();
}

def is_virtual(loc: str, tags: list[str]) -> bool {
    low = loc.lower();
    if not low
        or "virtual" in low
        or "zoom" in low
        or "http" in low
        or "remote" in low {
        return True;
    }
    return "Virtual" in tags and "In Person" not in tags;
}

def venue_of(loc: str) -> tuple[float, float, str] {
    low = loc.lower();
    for (key, lat, lon, label) in VENUES {
        if key in low {
            return (lat, lon, label);
        }
    }
    return (0.0, 0.0, "");
}

"""'19:30:00' -> '7:30 PM'."""
def time_12h(t: str) -> str {
    if len(t) < 5 or not t[:2].isdigit() {
        return "";
    }
    h = int(t[0:2]);
    h12 = h % 12 or 12;
    return f"{h12}:{t[3:5]} " + ("PM" if h >= 12 else "AM");
}

def category_of(etype: str) -> str {
    low = etype.lower();
    for (name, words) in CATEGORY_RULES {
        if any([w in low for w in words]) {
            return name;
        }
    }
    return "Other";
}

"""Events that haven't ended by `today`, one per title and start date, soonest first."""
def parse_events(doc: dict[str, any], today: str) -> list[EventView] {
    out: list[EventView] = [];
    seen: set[str] = set();
    for eid in doc {
        e = doc[eid];
        if not isinstance(e, dict) {
            continue;
        }
        start = str(e.get("date_start") or "");
        end = str(e.get("date_end") or start);
        title = clean(e.get("combined_title") or e.get("event_title"));
        if not title or (end and end < today) or (title + "|" + start) in seen {
            continue;
        }
        seen.add(title + "|" + start);
        tags = [str(t) for t in (e.get("tags") or [])];
        loc = clean(e.get("location_name"));
        virtual = is_virtual(loc, tags);
        (lat, lon, label) = (0.0, 0.0, "") if virtual else venue_of(loc);
        (south, north, west, east) = AA_BOUNDS;
        if lat and not (south <= lat <= north and west <= lon <= east) {
            (lat, lon) = (0.0, 0.0);
        }
        (wx, wy) = world_px(lat, lon) if lat else (0.0, 0.0);
        etype = clean(e.get("event_type")) or "Other";
        cost = clean(e.get("cost"));
        sponsors = e.get("sponsors") or [];
        sponsor = str(sponsors[0].get("group_name", ""))
            if sponsors and isinstance(sponsors[0], dict)
            else "";
        out.append(
            EventView(
                eid=str(eid),
                title=title,
                etype=etype,
                category=category_of(etype),
                date=start,
                date_end=end,
                time=time_12h(str(e.get("time_start") or "")),
                time_end=time_12h(str(e.get("time_end") or "")),
                location=loc or "Online",
                venue=label or ("Online" if virtual else loc[:40]),
                virtual=virtual,
                lat=lat,
                lon=lon,
                wx=wx,
                wy=wy,
                summary=clean(e.get("description"))[:600],
                cost=cost,
                free="Free" in tags or cost.lower() in ["", "free"],
                url=str(e.get("permalink") or e.get("website") or ""),
                sponsor=sponsor
            )
        );
    }
    return sorted(out, key=lambda (x: EventView) -> str { x.date + x.time; });
}

def all_events(today: str) -> list[EventView] {
    mtime = os.path.getmtime(EVENT_FILE);
    if _cache["mtime"] != mtime or _cache.get("today") != today {
        with open(EVENT_FILE, encoding="utf-8") as f {
            doc = json.load(f);
        }
        _cache["events"] = parse_events(doc, today);
        _cache["mtime"] = mtime;
        _cache["today"] = today;
    }
    return _cache["events"];
}

"""Upcoming events, optionally one category ("All" = every category) and free ones only."""
def:protect upcoming_events(
    category: str = "All", free_only: bool = False
) -> list[EventView] {
    return [
        e
        for e in all_events(today_iso())
        if (category == "All" or e.category == category) and (not free_only or e.free)
    ][:MAX_EVENTS];
}

"""In-person events with an official page link, soonest first, at most `count` (0-6)."""
def preview_of(events: list[EventView], count: int) -> list[EventView] {
    return [
        e
        for e in events
        if not e.virtual and e.url and e.location
    ][:max(0, min(count, 6))];
}

"""A few upcoming in-person events for the public landing page: public U-M Happening data, no
login needed."""
def:pub preview_events(count: int = 3) -> list[EventView] {
    return preview_of(all_events(today_iso()), count);
}

"""The soonest event in `events` whose category is one of `interests`, or None if none match.
`events` must already be date-sorted (as all_events()/upcoming_events() return them) -- the first
match is therefore the soonest one. Deterministic tag matching, no ranking model (U5, plan
2026-09-27-003)."""
def best_match(events: list[EventView], interests: list[str]) -> EventView | None {
    for e in events {
        if e.category in interests {
            return e;
        }
    }
    return None;
}

"""A public, content-free record that some student marked interest in event `eid` -- the
market/graph.jac ReplyTick shape: no identity, no dedup, a pure fire-and-forget tally (U6, plan
2026-09-27-003 R11: "no memory of which student clicked")."""
node EventInterest {
    has eid: str;

    def __jac_access__ -> AccessLevel | None {
        return AccessLevel.READ;
    }
}

def commons_or_shared(commons: any = None) -> any {
    return commons if commons is not None else root.shared;
}

"""How many students have marked interest in event `eid`."""
def interest_count(eid: str, commons: any = None) -> int {
    return len(
        [
            t
            for t in [commons_or_shared(commons)-->][?:EventInterest]
            if t.eid == eid
        ]
    );
}

"""Interest counts for several events in one call, so the events screen doesn't pay one round
trip per card. Every id in `eids` is present in the result, 0 if nobody has marked it yet."""
def:protect interest_counts(eids: list[str]) -> dict[str, int] {
    wanted = set(eids);
    counts: dict[str, int] = {eid: 0 for eid in eids};
    for t in [root.shared-->][?:EventInterest] {
        if t.eid in wanted {
            counts[t.eid] = counts.get(t.eid, 0) + 1;
        }
    }
    return counts;
}

"""Record that the caller is interested in event `eid`. Fire-and-forget: no de-dup, no identity
kept, so a repeat tap simply adds to the count -- an accepted trade-off for keeping this a
throwaway tally instead of a tracked RSVP (see the plan's Key Technical Decisions). `eid` must
belong to a real upcoming event, so the endpoint can't be used to grow the graph with tallies for
made-up ids -- unlike a fire-and-forget count, that growth would be unbounded and unrelated to any
real event. Returns the new count (unchanged if `eid` isn't real)."""
def:protect mark_interested(eid: str) -> int {
    if eid not in [e.eid for e in all_events(today_iso())] {
        return interest_count(eid);
    }
    root.shared ++> EventInterest(eid=eid);
    return interest_count(eid);
}

test "events file parses into upcoming, deduplicated events in date order" {
    events = all_events("2026-09-27");
    assert len(events) > 20;
    dates = [e.date + e.time for e in events];
    assert dates == sorted(dates);
    assert all([e.date_end >= "2026-09-27" for e in events]);
    keys = [e.title + "|" + e.date for e in events];
    assert len(keys) == len(set(keys));
}

test "a venue keyword places an event on the map; virtual events are list-only" {
    doc = {
        "1": {
            "event_title": "Film night",
            "event_type": "Film",
            "date_start": "2026-10-01",
            "time_start": "19:30:00",
            "location_name": "Michigan Theater, 603 E Liberty"
        },
        "2": {
            "event_title": "Webinar",
            "event_type": "Workshop / Seminar",
            "date_start": "2026-10-02",
            "location_name": "Zoom"
        },
        "3": {
            "event_title": "Old",
            "event_type": "Lecture",
            "date_start": "2026-09-01",
            "location_name": "Rackham"
        }
    };
    events = parse_events(doc, "2026-09-27");
    assert [e.title for e in events] == ["Film night", "Webinar"];
    assert events[0].venue == "Michigan Theater"
        and events[0].lat > 42
        and events[0].wx > 0;
    assert events[0].time == "7:30 PM"
        and events[0].category == "Arts"
        and events[0].free;
    assert events[1].virtual
        and events[1].lat == 0.0
        and events[1].category == "Learning";
}

test "the public preview lists only in-person events with a source link, capped at six" {
    doc = {
        "1": {
            "event_title": "Film night",
            "event_type": "Film",
            "date_start": "2026-10-01",
            "location_name": "Michigan Theater",
            "permalink": "https://events.umich.edu/event/1"
        },
        "2": {
            "event_title": "Webinar",
            "event_type": "Workshop",
            "date_start": "2026-10-01",
            "location_name": "Zoom",
            "permalink": "https://events.umich.edu/event/2"
        },
        "3": {
            "event_title": "No link",
            "event_type": "Lecture",
            "date_start": "2026-10-02",
            "location_name": "Rackham"
        }
    };
    events = parse_events(doc, "2026-09-27");
    assert [e.title for e in preview_of(events, 3)] == ["Film night"];
    assert len(preview_of(all_events("2026-09-27"), 50)) == 6;
    assert preview_of(events, -1) == [];
}

test "best_match picks the soonest event in an interest category, or None if none match" {
    doc = {
        "1": {
            "event_title": "Film night",
            "event_type": "Film",
            "date_start": "2026-10-01",
            "location_name": "Michigan Theater"
        },
        "2": {
            "event_title": "Career Fair",
            "event_type": "Career",
            "date_start": "2026-10-02",
            "location_name": "Pierpont Commons"
        },
        "3": {
            "event_title": "Second Film",
            "event_type": "Film",
            "date_start": "2026-10-03",
            "location_name": "State Theatre"
        }
    };
    events = parse_events(doc, "2026-09-27");
    arts_match = best_match(events, ["Arts"]);
    careers_match = best_match(events, ["Careers"]);
    assert arts_match is not None and arts_match.title == "Film night";
    assert careers_match is not None and careers_match.title == "Career Fair";
    assert best_match(events, ["Sports"]) is None;
}

test "marking interest is a fire-and-forget tally with no dedup" {
    real = all_events(today_iso())[0].eid;
    assert interest_count(real) == 0;
    n1 = mark_interested(real);
    assert n1 == 1 and interest_count(real) == 1;
    n2 = mark_interested(real);
    assert n2 == 2 , "a repeat tap adds to the count instead of being deduped";
    assert interest_count("e2") == 0;
}

test "marking interest in a made-up event id is a no-op, not a recorded tally" {
    assert interest_count("not-a-real-event") == 0;
    n = mark_interested("not-a-real-event");
    assert n == 0 , "an unrecognized eid must not create an EventInterest node";
    assert interest_count("not-a-real-event") == 0;
}

test "interest_counts batches several events in one call, defaulting unmarked ones to 0" {
    upcoming = all_events(today_iso());
    (marked, never_marked) = (upcoming[0].eid, upcoming[1].eid);
    mark_interested(marked);
    counts = interest_counts([marked, never_marked]);
    assert counts == {marked: 1, never_marked: 0};
}
