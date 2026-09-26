"""The student's profile: one per student, on their own root (U1, U2).

The first-week journey (Feature A) writes the journey fields; the marketplace (Feature B)
reads them to prompt and pre-fill posts (R12). Nothing here is marketplace-specific.
"""

import os;

glob ANN_ARBOR_AREAS: list[str] = [
         "Central Campus",
         "North Campus",
         "South Campus",
         "Kerrytown",
         "Old West Side",
         "Downtown",
         "Other"
     ],
     STUDENT_TYPES: list[str] = ["international", "out-of-state", "in-state"],
     HOUSING_STATUSES: list[str] = ["have-housing", "looking", "temporary"];

node Profile {
    has display_name: str = "",
        umich_email: str = "",
        verified: bool = False,
        student_type: str = "",
        preferred_language: str = "en",
        arrival_date: str = "",
        arrival_time: str = "",
        housing_status: str = "",
        move_in_date: str = "",
        area: str = "",
        needs_airport_ride: bool = False,
        has_us_phone: bool = False,
        has_us_bank: bool = False,
        email_notifications: bool = True;
}

"""What the client sees of a profile; `is_moderator` is computed, never stored or editable."""
obj ProfileView {
    has display_name: str,
        umich_email: str,
        verified: bool,
        student_type: str,
        preferred_language: str,
        arrival_date: str,
        arrival_time: str,
        housing_status: str,
        move_in_date: str,
        area: str,
        needs_airport_ride: bool,
        has_us_phone: bool,
        has_us_bank: bool,
        email_notifications: bool,
        is_moderator: bool;
}

"""Result of a profile update: the new view, or the first validation error."""
obj ProfileUpdateResult {
    has ok: bool,
        error: str = "",
        profile: ProfileView | None = None;
}

"""The caller's profile, created on first use."""
def my_profile -> Profile {
    found = [root-->][?:Profile];
    if found {
        return found[0];
    }
    return root ++> Profile();
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
        arrival_date=profile.arrival_date,
        arrival_time=profile.arrival_time,
        housing_status=profile.housing_status,
        move_in_date=profile.move_in_date,
        area=profile.area,
        needs_airport_ride=profile.needs_airport_ride,
        has_us_phone=profile.has_us_phone,
        has_us_bank=profile.has_us_bank,
        email_notifications=profile.email_notifications,
        is_moderator=is_moderator(profile)
    );
}

"""True for "" (unset) or a real calendar date written YYYY-MM-DD."""
def valid_date(value: str) -> bool {
    if value == "" {
        return True;
    }
    parts = value.split("-");
    if len(parts) != 3
        or len(parts[0]) != 4
        or len(parts[1]) != 2
        or len(parts[2]) != 2 {
        return False;
    }
    if not (parts[0].isdigit() and parts[1].isdigit() and parts[2].isdigit()) {
        return False;
    }
    (month, day) = (int(parts[1]), int(parts[2]));
    return 1 <= month <= 12 and 1 <= day <= 31;
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
         "email_notifications"
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
    if error {
        return ProfileUpdateResult(ok=False, error=error);
    }
    if "display_name" in text {
        p.display_name = text["display_name"][:60];
    }
    if "student_type" in text {
        p.student_type = text["student_type"];
    }
    if "preferred_language" in text {
        p.preferred_language = text["preferred_language"][:10] or "en";
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
    return ProfileUpdateResult(ok=True, profile=view_of(p));
}

test "dates and times accept only well-formed values or empty" {
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
