"""Today's date for server code. `UARRIVED_TODAY=YYYY-MM-DD` pinneds it so tests can move time
forward (for example, to expire a post) instead of publishing dates in the past."""

import os;
import from datetime { date }

def today_iso -> str {
    pinned = os.environ.get("UARRIVED_TODAY", "");
    return pinned or date.today().isoformat();
}
