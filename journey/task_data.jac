"""First-week task content, read from the repo's task file (deterministic, no AI, no network).

Source: journey/umich_ann_arbor_new_student_tasks_2026.json (official U-M / government / provider
pages, `verified_as_of` in its metadata). The file has addresses and Chinese task names but no
English titles, map coordinates or step lists for every task, so `BASELINE` adds those per task id.
Everything official (where, hours, what to bring, notes, cost, links) comes from the file.

A task can be done at one of several places (MCard: Union or Pierpont; bank: any UMCU/Chase
branch). Each place is a `TaskPlace`; finishing the task at any one of them finishes the task.

Ported from the Orientation Quest prototype (tasks_source.jac), which fetched the same file from
GitHub at runtime; here it is read from disk once and cached by modification time.
"""

import json;
import math;
import os;

glob TASK_FILE: str = os.path.join(
         os.path.dirname(os.path.abspath(__file__)),
         "umich_ann_arbor_new_student_tasks_2026.json"
     ),
     # Web Mercator world pixels are stored at this zoom; the client divides by 2^(18 - zoom).
     MAP_BASE_ZOOM: int = 18,
     DEFAULT_LAT: float = 42.2770,
     DEFAULT_LON: float = -83.7390;

"""One place a task can be done: the office, branch or store, with its own hours and notes.
`lat == 0` means the place has no known coordinates and is shown in the list only."""
obj TaskPlace {
    has name: str,
        address: str = "",
        hours: str = "",
        label: str = "",
        provider: str = "",
        lat: float = 0.0,
        lon: float = 0.0,
        wx: float = 0.0,
        wy: float = 0.0,
        bring: list[str] = [],
        notes: list[str] = [],
        links: list[str] = [];
}

"""A first-week task's content (the same for every student)."""
obj JourneyTask {
    has tid: str,
        title: str,
        short: str,
        required: bool,
        description: str = "",
        steps: list[str] = [],
        bring: list[str] = [],
        notes: list[str] = [],
        places: list[TaskPlace] = [],
        links: list[str] = [],
        cost: str = "",
        xp: int = 60,
        verified: str = "";
}

# Geocoded coordinates (OpenStreetMap Nominatim), keyed by the street part of the address as the
# task file writes it, plus a short map label for that place.
glob STORE_COORDS: dict[str, tuple[float, float, str]] = {
         "530 S State St": (42.27490, -83.74140, "Union"),
         "2101 Bonisteel Blvd": (42.29112, -83.71760, "Pierpont"),
         "1121 South University Avenue": (42.27522, -83.73481, "S University"),
         "340 E Huron Street": (42.28123, -83.74511, "Huron St"),
         "2725 S State St": (42.24816, -83.73926, "S State St"),
         "100 S Main St": (42.28126, -83.74871, "Main St"),
         "3500 Washtenaw Ave": (42.25499, -83.69046, "Washtenaw"),
         "3157 Ann Arbor Saline Road": (42.24918, -83.75887, "Saline Rd"),
         "5609 Jackson Rd": (42.28763, -83.83982, "Jackson Rd"),
         "2275 West Stadium Blvd": (42.27530, -83.77761, "W Stadium"),
         "3143 Ann Arbor Saline Rd": (42.25285, -83.75435, "Saline Rd"),
         "3035 Washtenaw Ave": (42.25789, -83.69912, "Washtenaw"),
         "3389 Plymouth Rd": (42.30490, -83.69502, "Plymouth Rd"),
         "515 E Jefferson St": (42.27660, -83.74255, "SAB"),
         "207 Fletcher St": (42.27979, -83.73668, "UHS")
     };

# English title, map label, XP, a fallback map spot and the steps per task id. Anything the task
# file states (where, hours, what to bring, notes, steps) replaces these.
glob BASELINE: dict[str, dict[str, any]] = {
         "mandatory_immigration_checkin": {
             "title": "Complete mandatory immigration check-in",
             "short": "Immigration check-in",
             "xp": 120,
             "lat": 42.27660,
             "lon": -83.74255,
             "description": "Fall 2026 check-in is virtual: complete the International Center Canvas course and upload scanned immigration documents. No in-person visit is needed.",
             "steps": [
                 "Enroll in the Fall 2026 International Center Canvas check-in course",
                 "Complete the course",
                 "Submit scanned copies of the required immigration documents"
             ]
         },
         "international_center": {
             "title": "Visit the International Center (ISSS)",
             "short": "Intl Center",
             "xp": 100,
             "lat": 42.27660,
             "lon": -83.74255,
             "description": "ISSS is U-M's main contact for F-1 and J-1 student issues. Check M-Passport first: many requests do not need an in-person visit.",
             "steps": [
                 "Check M-Passport for your request before going",
                 "Gather your passport, most recent I-94, and I-20 or DS-2019",
                 "Bring any task-specific forms requested in M-Passport",
                 "Visit during open office hours if M-Passport can't handle it"
             ]
         },
         "mcard": {
             "title": "Get your MCard",
             "short": "MCard",
             "xp": 100,
             "lat": 42.27490,
             "lon": -83.74140,
             "description": "Your MCard is your student ID for buildings, dining, buses and libraries. Free for new students and valid for five years.",
             "steps": [
                 "Submit your MCard photo online if you have not yet",
                 "Bring an unexpired government-issued photo ID",
                 "Follow the pickup instructions in your email",
                 "Walk in to an MCard Issuing Station to pick up your card"
             ]
         },
         "tuition": {
             "title": "Confirm your 2026-27 tuition bill",
             "short": "Tuition",
             "xp": 120,
             "lat": 42.27660,
             "lon": -83.74255,
             "description": "Your actual bill depends on school, program, residency and credits. Use your Wolverine Access bill as the authority.",
             "steps": [
                 "Log in to Wolverine Access and open Student Business / eBill",
                 "Review your actual charges for the term",
                 "Pay the balance or set up a payment plan",
                 "For in-person help, bring your UMID number and a photo ID"
             ]
         },
         "medical": {
             "title": "Register with University Health Service",
             "short": "Health Service",
             "xp": 90,
             "lat": 42.27979,
             "lon": -83.73668,
             "description": "Most medical services are free for enrolled U-M students, though not every service is.",
             "steps": [
                 "Set up the patient portal",
                 "Self-schedule or request your first appointment",
                 "Bring your MCard and insurance information",
                 "Hand-carry a hard copy of your health history to your first visit"
             ]
         },
         "mobile": {
             "title": "Get a US phone number",
             "short": "Phone",
             "xp": 90,
             "lat": 42.25789,
             "lon": -83.69912,
             "description": "A US number helps with banking and account recovery. Compare carriers and prepaid vs postpaid plans.",
             "steps": [
                 "Make sure your phone is carrier-unlocked and supports US bands or eSIM",
                 "Bring your passport, immigration document, payment method and US address",
                 "Pick a carrier and plan (prepaid or postpaid)",
                 "Activate your SIM or eSIM and test calls and data"
             ]
         },
         "campus_tour": {
             "title": "Join the official Central Campus tour",
             "short": "Campus tour",
             "xp": 60,
             "lat": 42.27622,
             "lon": -83.73822,
             "description": "A 75-minute official walking tour of Central Campus, including a model residence-hall room. Registration is required; no walk-ins.",
             "steps": [
                 "Register online (party of up to four)",
                 "Check your confirmation for the exact meeting point",
                 "Wear comfortable shoes and weather-appropriate clothing",
                 "Arrive on time: over 10 minutes late and the group will have left"
             ]
         },
         "banking": {
             "title": "Open a bank account",
             "short": "Bank",
             "xp": 60,
             "lat": 42.27490,
             "lon": -83.74140,
             "description": "Student account opening is available on campus at UMCU; Chase downtown is another student-friendly option.",
             "steps": [
                 "Choose a bank or credit union",
                 "Bring your passport, immigration documents and MCard",
                 "Open a student checking account in person",
                 "Set up online banking and note your routing number"
             ]
         },
         "ssn": {
             "title": "Apply for an SSN (only if employed)",
             "short": "SSN",
             "xp": 60,
             "lat": 42.27660,
             "lon": -83.74255,
             "description": "Needed only if you are employed or have accepted a US job offer. Start the SSA online application before your visit.",
             "steps": [
                 "Request the Social Security Letter from the International Center",
                 "Allow 5 working days for the letter",
                 "Apply online and schedule with SSA",
                 "Attend your SSA appointment with original documents"
             ]
         }
     };

glob DAY_KEYS: list[str] = [
         "monday",
         "tuesday",
         "wednesday",
         "thursday",
         "friday",
         "saturday",
         "sunday"
     ],
     PLACE_LABELS: dict[str, str] = {
         "international_center": "Intl Center",
         "ssa": "SSA office"
     },
     _cache: dict[str, any] = {"mtime": -1.0, "tasks": [], "verified": ""};

"""Web Mercator world pixels at MAP_BASE_ZOOM for a coordinate, so the client never needs trig."""
def world_px(lat: float, lon: float) -> tuple[float, float] {
    size = 256.0 * (2 ** MAP_BASE_ZOOM);
    x = (lon + 180.0) / 360.0 * size;
    rad = math.radians(lat);
    y = (1.0 - math.log(math.tan(rad) + 1.0 / math.cos(rad)) / math.pi) / 2.0 * size;
    return (x, y);
}

def str_list(v: any) -> list[str] {
    if isinstance(v, list) {
        return [
            str(x).strip()
            for x in v
            if x
        ];
    }
    if v {
        return [str(v).strip()];
    }
    return [];
}

def unique(items: list[str]) -> list[str] {
    out: list[str] = [];
    for x in items {
        if x and x not in out {
            out.append(x);
        }
    }
    return out;
}

"""'monday-friday' -> 'Mon-Fri'; a place key ('ssa') -> its label."""
def day_label(k: str) -> str {
    key = str(k).lower();
    if key in PLACE_LABELS {
        return PLACE_LABELS[key] + ":";
    }
    parts = key.replace("_", " ").split("-");
    if parts and parts[0].strip() in DAY_KEYS {
        return "-".join([p.strip()[:3].capitalize() for p in parts]);
    }
    return key.replace("_", " ").capitalize() + ":";
}

"""The file's hours (a day-range -> time dict, or a string) as one line."""
def format_hours(h: any) -> str {
    if isinstance(h, dict) {
        return "; ".join(
            [
                day_label(k) + " " + str(h[k])
                for k in h
                if k not in ["holidays", "special_closure"]
            ]
        );
    }
    return str(h) if h else "";
}

def strip_step_number(s: str) -> str {
    t = s.strip();
    if len(t) > 2 and t[0].isdigit() and t[1] in [".", ")"] {
        t = t[2:].strip();
    }
    return t.rstrip(".");
}

"""Coordinates and short label for an address, or None when it isn't geocoded."""
def lookup(addr: str) -> tuple[float, float, str] | None {
    low = addr.lower();
    for key in STORE_COORDS {
        if key.lower() in low {
            return STORE_COORDS[key];
        }
    }
    return None;
}

def make_place(
    name: str,
    address: str,
    hours: str,
    provider: str,
    fallback: tuple[float, float] | None,
    extras: tuple[list[str], list[str], list[str]]
) -> TaskPlace {
    (bring, notes, links) = extras;
    found = lookup(address);
    lat = 0.0;
    lon = 0.0;
    label = "";
    if found is not None {
        (lat, lon, label) = found;
    } elif fallback is not None {
        (lat, lon) = fallback;
    }
    short_provider = "UMCU"
        if "UMCU" in provider or "Credit Union" in provider
        else provider;
    if provider {
        label = (short_provider + " " + label).strip();
    }
    (wx, wy) = world_px(lat, lon) if lat else (0.0, 0.0);
    return TaskPlace(
        name=(provider + " - " + name) if provider and provider not in name else name,
        address=address,
        hours=hours,
        label=label,
        provider=provider,
        lat=lat,
        lon=lon,
        wx=wx,
        wy=wy,
        bring=bring,
        notes=notes,
        links=links
    );
}

"""The places a task record names: `where` (one place, a list, or labelled addresses) and
`providers` / `provider_options` (a store per location). Returns (places, extra notes)."""
def places_of(
    t: dict[str, any], base: dict[str, any]
) -> tuple[list[TaskPlace], list[str]] {
    places: list[TaskPlace] = [];
    notes: list[str] = [];
    fallback: tuple[float, float] = (
        float(base.get("lat", DEFAULT_LAT)),
        float(base.get("lon", DEFAULT_LON))
    );
    task_hours = format_hours(t.get("hours"));
    w = t.get("where");
    entries: list[dict[str, any]] = [];
    if isinstance(w, list) {
        entries = [x if isinstance(x, dict) else {"name": str(x)} for x in w];
    } elif isinstance(w, dict) {
        if w.get("name") or w.get("address") {
            entries = [w];
        } elif w.get("in_person_support") {
            # tuition: online first, plus an office written as "Name, address"
            office = str(w["in_person_support"]);
            cut = office.find(",");
            entries = [
                {
                    "name": office[:cut] if cut > 0 else office,
                    "address": office[cut + 1:].strip() if cut > 0 else ""
                }
            ];
            if w.get("primary") {
                notes.append("Online: " + str(w["primary"]));
            }
        } else {
            # ssn: {"international_center_for_letter": addr, "ssa_office": addr}
            for k in w {
                if isinstance(w[k], str) {
                    entries.append(
                        {"name": str(k).replace("_", " ").capitalize(), "address": w[k]}
                    );
                }
            }
        }
    } elif isinstance(w, str) and w {
        entries = [{"name": w}];
    }
    for (i, e) in enumerate(entries) {
        appointment = e.get("appointment") or "";
        places.append(
            make_place(
                str(e.get("name", "")),
                str(e.get("address", "")),
                format_hours(e.get("hours")) or task_hours,
                "",
                fallback if i == 0 else None,
                ([], [str(appointment)] if appointment else [], [])
            )
        );
    }
    providers = t.get("providers") or t.get("provider_options") or [];
    if isinstance(providers, list) {
        for p in providers {
            if not isinstance(p, dict) {
                continue;
            }
            provider = str(p.get("provider", ""));
            links = str_list(p.get("source_urls")) + str_list(p.get("source_url"));
            for loc in (p.get("locations") or []) {
                if not isinstance(loc, dict) {
                    continue;
                }
                places.append(
                    make_place(
                        str(loc.get("name", provider)),
                        str(loc.get("address", "")),
                        format_hours(loc.get("hours")),
                        provider,
                        None,
                        (
                            str_list(p.get("what_to_bring")),
                            str_list(loc.get("notes")) + str_list(p.get("notes")),
                            links
                        )
                    )
                );
            }
        }
    }
    return (places, notes);
}

"""One task record from the file, merged with its baseline."""
def normalize(t: dict[str, any], verified: str) -> JourneyTask {
    tid = str(t.get("id", "")).strip();
    base: dict[str, any] = BASELINE.get(tid, {});
    (places, where_notes) = places_of(t, base);
    required = t.get("required");
    is_required = required == True
        or (isinstance(required, str) and "required" in required.lower());
    notes = where_notes + str_list(t.get("notes")) + str_list(t.get("general_prep"));
    for extra in [
        t.get("route_note"),
        t.get("eligibility_note"),
        t.get("international_center_note")
    ] {
        if extra {
            notes.append(str(extra));
        }
    }
    reg = t.get("registration");
    if isinstance(reg, dict) and reg.get("official_registration") {
        walk = "" if reg.get("walk_ins") else ", no walk-ins";
        notes.insert(
            0, "Registration required" + walk + ": " + str(reg["official_registration"])
        );
    }
    steps = [strip_step_number(s) for s in str_list(t.get("steps"))];
    if not steps {
        steps = [str(s) for s in base.get("steps", [])];
    }
    raw_title = str(t.get("task", tid));
    return JourneyTask(
        tid=tid,
        title=str(base.get("title", raw_title)),
        short=str(base.get("short", raw_title[:18])),
        required=is_required,
        description=str(base.get("description", "")),
        steps=steps,
        bring=str_list(t.get("what_to_bring")),
        notes=unique(notes),
        places=places,
        links=unique(str_list(t.get("source_url")) + str_list(t.get("source_urls"))),
        cost=str(t["cost"])
            if t.get("cost") and not isinstance(t["cost"], dict)
            else "",
        xp=int(base.get("xp", 60)),
        verified=verified
    );
}

"""Parse a whole task document. Records without an id are skipped."""
def parse_tasks(doc: dict[str, any]) -> list[JourneyTask] {
    verified = str(doc.get("metadata", {}).get("verified_as_of", ""));
    return [
        normalize(t, verified)
        for t in doc.get("tasks", [])
        if isinstance(t, dict) and t.get("id")
    ];
}

"""Every task in the task file, re-read only when the file changes."""
def all_tasks -> list[JourneyTask] {
    mtime = os.path.getmtime(TASK_FILE);
    if _cache["mtime"] != mtime {
        with open(TASK_FILE, encoding="utf-8") as f {
            doc = json.load(f);
        }
        _cache["tasks"] = parse_tasks(doc);
        _cache["verified"] = str(doc.get("metadata", {}).get("verified_as_of", ""));
        _cache["mtime"] = mtime;
    }
    return _cache["tasks"];
}

def task_by_id(tid: str) -> JourneyTask | None {
    for t in all_tasks() {
        if t.tid == tid {
            return t;
        }
    }
    return None;
}

test "every task in the file loads with an English title, steps and a source link" {
    tasks = all_tasks();
    assert len(tasks) >= 9;
    for t in tasks {
        assert t.title and t.steps , t.tid;
        assert t.links or any([len(p.links) > 0 for p in t.places]) , t.tid;
        assert t.verified;
    }
}

test "a multi-location task becomes one task with a place per branch" {
    bank = task_by_id("banking");
    assert bank is not None;
    assert len(bank.places) >= 5;
    union = [
        p
        for p in bank.places
        if p.label == "UMCU Union"
    ];
    assert len(union) == 1 and union[0].lat > 42.0 and union[0].wx > 0;
    assert len(union[0].links) > 0;
}

test "numbered steps from the file replace the baseline steps" {
    ssn = task_by_id("ssn");
    assert ssn is not None;
    assert ssn.steps[0].startswith("If you are a U-M F-1/J-1 student");
    assert not ssn.required;
    assert len(ssn.places) == 2 and ssn.places[1].lat == 0.0;
}

test "hours dicts read as one line and unknown records get defaults" {
    assert format_hours({"monday-friday": "08:00-19:00", "sunday": "Closed"})
        == "Mon-Fri 08:00-19:00; Sun Closed";
    t = normalize(
        {"id": "new_task", "task": "Something new", "required": True}, "2026-09-26"
    );
    assert t.required and t.title == "Something new" and t.steps == [] and t.xp == 60;
}
