"""Journey prompts (U9, R12, F2): first-week tasks that point into the marketplace.

Journey data only prompts and pre-fills; nothing is posted or matched until the student
confirms the post. The link is the whole contract with the marketplace: journey/ never
imports market/ (scripts/check_rules.sh), it only builds a URL that /market/new understands.
"""

import from core.clock { today_iso as clock_today }
import from datetime { date }
import from urllib.parse { urlencode }
import from core.profile { Profile, my_profile, valid_date, valid_time }

obj JourneyPrompt {
    has key: str,
        title: str,
        body: str,
        action_label: str,
        link: str;
}

"""The DTW ride-share prompt for this profile as of `today`, or None when it doesn't apply
(no arrival date, doesn't need an airport ride, or the arrival day has passed)."""
def ride_share_prompt(p: Profile, today: str) -> JourneyPrompt | None {
    if not p.needs_airport_ride
        or not p.arrival_date
        or not valid_date(p.arrival_date) {
        return None;
    }
    if p.arrival_date < today {
        return None;
    }
    params: dict[str, str] = {"prefill": "ride", "date": p.arrival_date};
    if p.arrival_time and valid_time(p.arrival_time) {
        params["time"] = p.arrival_time;
    }
    when = p.arrival_date + (f" around {p.arrival_time}" if p.arrival_time else "");
    return JourneyPrompt(
        key="dtw-ride-share",
        title="Plan your ride from DTW",
        body=f"Because you arrive {when} and told us you have no car. Other students may be landing then too.",
        action_label="Find students arriving the same day",
        link="/market/new?" + urlencode(params)
    );
}

def prompts_for(p: Profile, today: str) -> list[JourneyPrompt] {
    found = [ride_share_prompt(p, today)];
    return [
        x
        for x in found
        if x is not None
    ];
}

def:protect my_journey_prompts -> list[JourneyPrompt] {
    return prompts_for(my_profile(), clock_today());
}

test "a student arriving with no car gets the ride prompt with date and time in the link (AE4)" {
    p = Profile(
        needs_airport_ride=True, arrival_date="2026-08-20", arrival_time="15:00"
    );
    prompt = ride_share_prompt(p, "2026-08-01");
    assert prompt is not None;
    assert prompt.link == "/market/new?prefill=ride&date=2026-08-20&time=15%3A00";
    assert "2026-08-20 around 15:00" in prompt.body;
}

test "no prompt without a ride need, without a date, or after arrival" {
    assert ride_share_prompt(Profile(arrival_date="2026-08-20"), "2026-08-01") is None;
    assert ride_share_prompt(Profile(needs_airport_ride=True), "2026-08-01") is None;
    assert ride_share_prompt(
        Profile(needs_airport_ride=True, arrival_date="2026-08-20"), "2026-08-21"
    )
        is None;
}

test "a missing time leaves it out of the link rather than guessing" {
    prompt = ride_share_prompt(
        Profile(needs_airport_ride=True, arrival_date="2026-08-20"), "2026-08-01"
    );
    assert prompt is not None and "time=" not in prompt.link;
}
