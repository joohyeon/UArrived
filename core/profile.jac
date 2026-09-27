"""The student's profile: one per student, on their own root (U1, U2).

The first-week journey (Feature A) writes the journey fields; the marketplace (Feature B)
reads them to prompt and pre-fill posts (R12). Nothing here is marketplace-specific.
"""

import os;
import time;
import random;
import from datetime { date }
import from uuid { UUID }
import from jaclang { JacRuntime as Jac }
import from jaclang.data.pgwire { PgWireError }
import from core.constants { ANN_ARBOR_AREAS, PILOT_LANGUAGES }

glob STUDENT_TYPES: list[str] = ["international", "out-of-state", "in-state"],
     HOUSING_STATUSES: list[str] = ["have-housing", "looking", "temporary"];

node Profile {
    has display_name: str = "",
        umich_email: str = "",
        pending_email: str = "",
        verified: bool = False,
        student_type: str = "",
        preferred_language: str = "en",
        language_chosen: bool = False,
        language_defaulted: bool = False,
        arrival_date: str = "",
        arrival_time: str = "",
        housing_status: str = "",
        move_in_date: str = "",
        area: str = "",
        needs_airport_ride: bool = False,
        has_us_phone: bool = False,
        has_us_bank: bool = False,
        email_notifications: bool = True,
        onboarding_done: bool = False,
        last_seen: str = "";
}

"""Where to email a student, kept on the commons so the system user's notification sweep can
read it without reaching into private roots. Never granted: only its student and the system
user can read it. `language` is the student's preferred language, for rendering the digest."""
node Mailbox {
    has owner_root: str,
        email: str,
        enabled: bool,
        language: str = "en";
}

"""Postgres SQLSTATE for "could not serialize access due to read/write dependencies among
transactions" - the error the server itself tells you retrying may fix (`jaclang.data.pgwire`
raises `PgWireError` with this in its `'C'` field; see `is_serialization_conflict`)."""
glob SERIALIZATION_SQLSTATE: str = "40001";

"""True when `err` is the Postgres serialization-conflict error above. `PgWireError` carries no
typed attribute for it - the runtime itself detects it the same way (`jaclang.server.session`'s
`_is_serialization_conflict`): a dict argument with a `'C'` field equal to the SQLSTATE."""
def is_serialization_conflict(err: PgWireError) -> bool {
    for arg in err.args {
        if isinstance(arg, dict) and arg.get("C") == SERIALIZATION_SQLSTATE {
            return True;
        }
    }
    return False;
}

"""Call `fn()`, retrying up to `attempts` total tries when it raises a serialization-conflict
`PgWireError` (SQLSTATE 40001) - the collision a wide, whole-collection scan like
`sync_mailbox`'s can hit under SERIALIZABLE isolation when something else writes under `shared`
at the same time. Any other error, and the error on the last attempt, propagate unchanged so a
persistent failure is never silently swallowed. Backoff is small and jittered (tens of
milliseconds) so a retry barely moves request latency; `sleep` is injectable so tests run
instantly and deterministically instead of actually waiting."""
def retry_on_conflict(
    fn: Callable[[], any],
    attempts: int = 3,
    sleep: Callable[[float], None] = time.sleep
) -> any {
    tried = 0;
    while True {
        tried += 1;
        try {
            return fn();
        } except PgWireError as err {
            if tried >= attempts or not is_serialization_conflict(err) {
                raise;
            }
            sleep(0.02 * tried + random.uniform(0, 0.02));
        }
    }
}

"""Create or update the caller's Mailbox from their profile. Only verified addresses get one.

The scan below reads every Mailbox node under `shared` inside one SERIALIZABLE transaction, so
any concurrent write anywhere under `shared` can collide with it and raise a serialization-
conflict `PgWireError` (see `retry_on_conflict`) - common now that `default_language_from` calls
this on nearly every first draft. Retrying the read+write a few times absorbs a normal collision
instead of surfacing it as an error."""
def sync_mailbox(profile: Profile, commons: any = None) -> None {
    if not profile.verified {
        return;
    }
    shared: Root = commons if commons is not None else root.shared;
    me = jid(root);

    def attempt -> None {
        for m in [shared-->][?:Mailbox] {
            if m.owner_root == me {
                m.email = profile.umich_email;
                m.enabled = profile.email_notifications;
                m.language = profile.preferred_language;
                return;
            }
        }
        shared ++> Mailbox(
            owner_root=me,
            email=profile.umich_email,
            enabled=profile.email_notifications,
            language=profile.preferred_language
        );
    }
    retry_on_conflict(attempt);
}

"""Set `profile`'s language to `lang` (already validated) and keep its Mailbox in step.
`chosen` records an explicit choice, which a first-message default never overwrites. Nothing
is written when neither the language nor the chosen flag changes; returns whether it synced."""
def set_language(
    profile: Profile, lang: str, chosen: bool, commons: any = None
) -> bool {
    if chosen {
        profile.language_defaulted = True;
    }
    if profile.preferred_language == lang and (profile.language_chosen or not chosen) {
        return False;
    }
    profile.preferred_language = lang;
    if chosen {
        profile.language_chosen = True;
    }
    sync_mailbox(profile, commons);
    return True;
}

"""Make `lang` the default language of `profile` (the caller's, if None) unless the student
already chose one (R29). Only the first message counts: once a default has been considered (or
the student chose), later messages never change the language. Only pilot languages apply, and
this never sets the chosen flag. Returns whether the language was applied."""
def default_language_from(
    lang: str, profile: Profile | None = None, commons: any = None
) -> bool {
    code = lang.strip().lower();
    p = profile if profile is not None else my_profile();
    if p.language_chosen or p.language_defaulted {
        return False;
    }
    p.language_defaulted = True;
    if code not in PILOT_LANGUAGES or p.preferred_language == code {
        return False;
    }
    set_language(p, code, False, commons);
    return True;
}

"""What the client sees of a profile; `is_moderator` is computed, never stored or editable."""
obj ProfileView {
    has display_name: str,
        umich_email: str,
        verified: bool,
        student_type: str,
        preferred_language: str,
        language_chosen: bool,
        arrival_date: str,
        arrival_time: str,
        housing_status: str,
        move_in_date: str,
        area: str,
        needs_airport_ride: bool,
        has_us_phone: bool,
        has_us_bank: bool,
        email_notifications: bool,
        onboarding_done: bool,
        is_moderator: bool;
}

"""Result of a profile update: the new view, or the first validation error."""
obj ProfileUpdateResult {
    has ok: bool,
        error: str = "",
        profile: ProfileView | None = None;
}

"""The caller's profile, created on first use.

Called on nearly every protected endpoint, so this whole-collection scan under SERIALIZABLE
easily collides with a concurrent write anywhere under the caller's root - the client's own
`heartbeat` polling while a slower request (e.g. `post_in_group`'s AI draft call) is still open
is enough to trigger it. Wrapped in `retry_on_conflict` for the same reason `sync_mailbox` is."""
def my_profile -> Profile {
    def attempt -> Profile {
        found = [root-->][?:Profile];
        if found {
            return found[0];
        }
        return root ++> Profile();
    }
    return retry_on_conflict(attempt);
}

"""The moderators, as one access group (U11). Posts and reports are shared with the group once,
at creation, and a moderator joins by an edge, so moderators added later (or re-listed) see every
earlier post and report. Anyone may connect to it; membership is checked against
UARRIVED_MODERATORS on every moderator call (sync_moderator_membership)."""
node ModeratorGroup {
    def __jac_access__ -> AccessLevel | None {
        return AccessLevel.CONNECT;
    }
}

edge ModeratorOf: Root --> ModeratorGroup {}

def moderator_groups(commons: any = None) -> list[ModeratorGroup] {
    shared = commons if commons is not None else root.shared;
    return [shared-->][?:ModeratorGroup];
}

"""The moderator group(s), creating one if none exists yet. Normally exactly one; if two
requests race to create it, both are used everywhere so nothing is lost."""
def ensure_moderator_groups -> list[ModeratorGroup] {
    groups = moderator_groups();
    if not groups {
        root.shared ++> ModeratorGroup();
        groups = moderator_groups();
    }
    return groups;
}

"""Share `target` with every moderator, present and future."""
def share_with_moderators(target: any, level: AccessLevel = AccessLevel.WRITE) {
    for g in ensure_moderator_groups() {
        Jac.allow_group(target, UUID(jid(g)), level);  # jac:ignore[E1053]
    }
}

"""Join the moderator group(s) if the caller is a moderator now; leave them if not."""
def sync_moderator_membership(profile: Profile) -> bool {
    moderator = is_moderator(profile);
    joined = [jid(g) for g in [root->:ModeratorOf:->]];
    for g in ensure_moderator_groups() {
        if moderator and jid(g) not in joined {
            root +>:ModeratorOf():+> g;
        }
        if not moderator and jid(g) in joined {
            del [edge root->:ModeratorOf:->g];
        }
    }
    return moderator;
}

"""Moderators are verified students whose email is listed in UARRIVED_MODERATORS (comma-separated)."""
def is_moderator(profile: Profile) -> bool {
    listed = [
        e.strip().lower()
        for e in os.environ.get("UARRIVED_MODERATORS", "").split(",")
        if e.strip()
    ];
    return profile.verified and profile.umich_email in listed;
}

def view_of(profile: Profile) -> ProfileView {
    return ProfileView(
        display_name=profile.display_name,
        umich_email=profile.umich_email,
        verified=profile.verified,
        student_type=profile.student_type,
        preferred_language=profile.preferred_language,
        language_chosen=profile.language_chosen,
        arrival_date=profile.arrival_date,
        arrival_time=profile.arrival_time,
        housing_status=profile.housing_status,
        move_in_date=profile.move_in_date,
        area=profile.area,
        needs_airport_ride=profile.needs_airport_ride,
        has_us_phone=profile.has_us_phone,
        has_us_bank=profile.has_us_bank,
        email_notifications=profile.email_notifications,
        onboarding_done=profile.onboarding_done,
        is_moderator=is_moderator(profile)
    );
}

"""True for "" (unset) or a real calendar date written YYYY-MM-DD."""
def valid_date(value: str) -> bool {
    if value == "" {
        return True;
    }
    if len(value) != 10 or value[4] != "-" or value[7] != "-" {
        return False;
    }
    try {
        date.fromisoformat(value);
    } except ValueError {
        return False;
    }
    return True;
}

"""True for "" (unset) or a 24-hour time written HH:MM."""
def valid_time(value: str) -> bool {
    if value == "" {
        return True;
    }
    parts = value.split(":");
    if len(parts) != 2 or not (parts[0].isdigit() and parts[1].isdigit()) {
        return False;
    }
    return 0 <= int(parts[0]) <= 23 and 0 <= int(parts[1]) <= 59;
}

"""The first reason these profile values are invalid, or "" if they are all fine."""
def profile_error(
    student_type: str,
    housing_status: str,
    area: str,
    arrival_date: str,
    arrival_time: str,
    move_in_date: str
) -> str {
    if student_type and student_type not in STUDENT_TYPES {
        return f"Student type must be one of: {', '.join(STUDENT_TYPES)}.";
    }
    if housing_status and housing_status not in HOUSING_STATUSES {
        return f"Housing status must be one of: {', '.join(HOUSING_STATUSES)}.";
    }
    if area and area not in ANN_ARBOR_AREAS {
        return f"Area must be one of: {', '.join(ANN_ARBOR_AREAS)}.";
    }
    if not valid_date(arrival_date) or not valid_date(move_in_date) {
        return "Dates must be written YYYY-MM-DD.";
    }
    if not valid_time(arrival_time) {
        return "Arrival time must be written HH:MM (24-hour).";
    }
    return "";
}

"""The caller's own profile."""
def:protect get_my_profile -> ProfileView {
    return view_of(my_profile());
}

glob TEXT_FIELDS: list[str] = [
         "display_name",
         "student_type",
         "preferred_language",
         "arrival_date",
         "arrival_time",
         "housing_status",
         "move_in_date",
         "area"
     ],
     FLAG_FIELDS: list[str] = [
         "needs_airport_ride",
         "has_us_phone",
         "has_us_bank",
         "email_notifications",
         "onboarding_done"
     ];

"""Update the caller's own profile from `changes` (field -> new value).

Only the fields in TEXT_FIELDS and FLAG_FIELDS can change; identity, verification and
moderator status are ignored. Omitted fields keep their value. Takes one dict because
jaclang 0.37 passes an omitted `str | None` endpoint parameter as the string "None".
"""
def:protect update_my_profile(changes: dict[str, any]) -> ProfileUpdateResult {
    p = my_profile();
    text: dict[str, str] = {};
    for name in TEXT_FIELDS {
        if name in changes {
            if not isinstance(changes[name], str) {
                return ProfileUpdateResult(ok=False, error=f"{name} must be text.");
            }
            text[name] = changes[name].strip();
        }
    }
    for name in FLAG_FIELDS {
        if name in changes and not isinstance(changes[name], bool) {
            return ProfileUpdateResult(
                ok=False, error=f"{name} must be true or false."
            );
        }
    }
    error = profile_error(
        text.get("student_type", p.student_type),
        text.get("housing_status", p.housing_status),
        text.get("area", p.area),
        text.get("arrival_date", p.arrival_date),
        text.get("arrival_time", p.arrival_time),
        text.get("move_in_date", p.move_in_date)
    );
    if not error
        and "preferred_language" in text
        and text["preferred_language"].lower() not in PILOT_LANGUAGES {
        error = f"Language must be one of: {', '.join(PILOT_LANGUAGES)}.";
    }
    if error {
        return ProfileUpdateResult(ok=False, error=error);
    }
    if "display_name" in text {
        p.display_name = text["display_name"][:60];
    }
    if "student_type" in text {
        p.student_type = text["student_type"];
    }
    if "arrival_date" in text {
        p.arrival_date = text["arrival_date"];
    }
    if "arrival_time" in text {
        p.arrival_time = text["arrival_time"];
    }
    if "housing_status" in text {
        p.housing_status = text["housing_status"];
    }
    if "move_in_date" in text {
        p.move_in_date = text["move_in_date"];
    }
    if "area" in text {
        p.area = text["area"];
    }
    if "needs_airport_ride" in changes {
        p.needs_airport_ride = changes["needs_airport_ride"];
    }
    if "has_us_phone" in changes {
        p.has_us_phone = changes["has_us_phone"];
    }
    if "has_us_bank" in changes {
        p.has_us_bank = changes["has_us_bank"];
    }
    if "email_notifications" in changes {
        p.email_notifications = changes["email_notifications"];
    }
    if "onboarding_done" in changes {
        p.onboarding_done = changes["onboarding_done"];
    }
    synced = "preferred_language" in text
        and set_language(p, text["preferred_language"].lower(), True);
    if "email_notifications" in changes and not synced {
        sync_mailbox(p);
    }
    return ProfileUpdateResult(ok=True, profile=view_of(p));
}

test "dates and times accept only well-formed values or empty" {
    assert not valid_date("2026-02-30")
        and not valid_date("2026-04-31")
        and valid_date("2028-02-29");
    assert valid_date("") and valid_date("2026-08-20");
    assert not valid_date("2026-8-20");
    assert not valid_date("2026-13-01");
    assert not valid_date("Aug 20");
    assert valid_time("") and valid_time("15:00") and valid_time("00:05");
    assert not valid_time("25:00")
        and not valid_time("3pm")
        and not valid_time("15:60");
}

test "profile values outside the allowed lists are rejected with a reason" {
    assert profile_error("", "", "", "", "", "") == "";
    assert profile_error(
        "international", "looking", "North Campus", "2026-08-20", "15:00", "2026-08-22"
    )
        == "";
    assert "Student type" in profile_error("tourist", "", "", "", "", "");
    assert "Housing status" in profile_error("", "homeless-ish", "", "", "", "");
    assert "Area" in profile_error("", "", "Detroit", "", "", "");
    assert "YYYY-MM-DD" in profile_error("", "", "", "20/08/2026", "", "");
    assert "HH:MM" in profile_error("", "", "", "", "3pm", "");
}
