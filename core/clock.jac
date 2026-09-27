"""Today's date for server code. `UARRIVED_TODAY=YYYY-MM-DD` pins it so tests can move time
forward (for example, to expire a post) instead of publishing dates in the past."""

import os;
import from datetime { date, datetime, timezone }

def today_iso -> str {
    pinned = os.environ.get("UARRIVED_TODAY", "");
    return pinned or date.today().isoformat();
}

"""Now as an ISO timestamp (UTC, seconds). `UARRIVED_NOW` overrides it in tests (e.g. to trigger the
assistant's nudge without waiting hours)."""
def now_iso -> str {
    pinned = os.environ.get("UARRIVED_NOW", "");
    return pinned or datetime.now(timezone.utc).isoformat(timespec="seconds");
}

"""Like now_iso but to the microsecond, for records ordered against each other within a second
(group messages, leaving a group, invites). Still ISO, so it compares and parses the same."""
def now_precise -> str {
    pinned = os.environ.get("UARRIVED_NOW", "");
    return pinned or datetime.now(timezone.utc).isoformat(timespec="microseconds");
}
