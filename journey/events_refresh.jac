"""Keeps journey/umich_event_data current from U-M's public events feed (events.umich.edu),
without journey/events.jac's own parsing/caching logic changing at all -- all_events() already
picks up a refreshed file by its modification time on its next read (U1, plan 2026-09-27-003).

The fetch endpoint is overridable by environment variable so tests never touch the network, the
same UARRIVED_*-env-var test-double convention interop/email_sender.py uses for SMTP. The live
feed's exact field shape has not been verified against this file's schema from a real network
path (a fetch attempt during planning returned HTTP 403, most likely bot protection) -- see the
plan's Open Questions. refresh_events() validates the fetched document before overwriting
anything, so an unverified or mismatched schema degrades to "keep the old file," never a
corruption.
"""

import json;
import os;
import urllib.request;
import urllib.error;
import from journey.events { EVENT_FILE }

glob EVENTS_FEED_URL: str = os.environ.get(
         "UARRIVED_EVENTS_FEED_URL", "https://events.umich.edu/list/json?v=2"
     ),
     EVENTS_FETCH_TIMEOUT: float = 15.0;

"""True if `doc` looks like a usable export: a non-empty dict whose values are event-shaped dicts
carrying at least a title and a start date -- matching what journey.events.parse_events() expects.
Guards against overwriting a good file with an empty or malformed response."""
def looks_like_events_doc(doc: any) -> bool {
    if not isinstance(doc, dict) or len(doc) == 0 {
        return False;
    }
    sample = list(doc.values())[:5];
    return all(
        [
            isinstance(e, dict)
                and bool(e.get("event_title") or e.get("combined_title"))
                and bool(e.get("date_start")) for e in sample
        ]
    );
}

"""Fetch `url` as parsed JSON, or None on any network, timeout, or parse failure."""
def fetch_events_doc(url: str) -> dict[str, any] | None {
    req = urllib.request.Request(
        url, headers={"User-Agent": "Mozilla/5.0 (compatible; UArrived event refresh)"}
    );
    try {
        with urllib.request.urlopen(req, timeout=EVENTS_FETCH_TIMEOUT) as resp {
            return json.loads(resp.read().decode("utf-8"));
        }
    } except (urllib.error.URLError, ValueError, TimeoutError) {
        return None;
    }
}

"""Atomically replace `path` with `doc` as JSON, so a concurrent reader never sees a torn file."""
def write_events_doc(path: str, doc: dict[str, any]) {
    tmp_path = path + ".tmp";
    with open(tmp_path, "w", encoding="utf-8") as f {
        json.dump(doc, f);
    }
    os.replace(tmp_path, path);
}

"""Refresh `event_file` from `url` (or EVENTS_FEED_URL) if the fetch succeeds and the result looks
like a real export; otherwise leaves `event_file` untouched. Returns whether it refreshed. Never
raises -- a failed refresh is invisible to students, not a crash."""
def refresh_events(event_file: str, url: str = "") -> bool {
    doc = fetch_events_doc(url or EVENTS_FEED_URL);
    if doc is None or not looks_like_events_doc(doc) {
        return False;
    }
    write_events_doc(event_file, doc);
    return True;
}

# Daily at 09:17 UTC -- any coarse daily-ish cadence satisfies R1; this is not a load-bearing time.
@schedule(trigger=ScheduleTrigger.STATIC, cron="17 9 * * *")
def scheduled_events_refresh {
    refresh_events(EVENT_FILE);
}

test "a well-formed feed response is written and round-trips through parse_events" {
    import from journey.events { parse_events }
    import tempfile;

    fixture = {
        "1": {
            "event_title": "Fixture Mixer",
            "event_type": "Social",
            "date_start": "2026-10-05",
            "time_start": "18:00:00",
            "location_name": "Michigan Union"
        }
    };
    with tempfile.TemporaryDirectory() as d {
        target = os.path.join(d, "events.json");
        with open(target, "w", encoding="utf-8") as f {
            json.dump({"0": {"event_title": "Old", "date_start": "2020-01-01"}}, f);
        }
        fixture_path = os.path.join(d, "fixture.json");
        with open(fixture_path, "w", encoding="utf-8") as f {
            json.dump(fixture, f);
        }
        ok = refresh_events(target, "file://" + fixture_path);
        assert ok;
        with open(target, encoding="utf-8") as f {
            written = json.load(f);
        }
        assert "1" in written and "0" not in written;
        events = parse_events(written, "2026-10-01");
        assert [e.title for e in events] == ["Fixture Mixer"];
    }
}

test "an empty or malformed feed response leaves the existing file untouched" {
    import tempfile;

    with tempfile.TemporaryDirectory() as d {
        target = os.path.join(d, "events.json");
        original = {"0": {"event_title": "Keep me", "date_start": "2026-01-01"}};
        with open(target, "w", encoding="utf-8") as f {
            json.dump(original, f);
        }
        empty_path = os.path.join(d, "empty.json");
        with open(empty_path, "w", encoding="utf-8") as f {
            json.dump({}, f);
        }
        ok = refresh_events(target, "file://" + empty_path);
        assert not ok;
        with open(target, encoding="utf-8") as f {
            after = json.load(f);
        }
        assert after == original;
    }
}

test "a fetch failure leaves the existing file untouched and does not raise" {
    import tempfile;

    with tempfile.TemporaryDirectory() as d {
        target = os.path.join(d, "events.json");
        original = {"0": {"event_title": "Keep me too", "date_start": "2026-01-01"}};
        with open(target, "w", encoding="utf-8") as f {
            json.dump(original, f);
        }
        ok = refresh_events(target, "file://" + os.path.join(d, "does-not-exist.json"));
        assert not ok;
        with open(target, encoding="utf-8") as f {
            after = json.load(f);
        }
        assert after == original;
    }
}
