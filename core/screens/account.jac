"""/profile: who is signed in, the details UMadeIt uses to tailor the first week (arrival,
housing, language, student type) with a way to change them in the setup wizard, a first-week
progress summary, and Log out."""

import from "@jac/runtime" { jacLogout }
import from core.profile { get_my_profile, ProfileView }
import from core.constants { LANGUAGE_NAMES }
import from journey.walkers { my_journey, JourneySummary }
import from ui.tokens { color, space, text_style, SIZE }
import from ui.components.base { AppShell, Button, Card, Badge }
import from ui.components.blocks {
    Avatar,
    KeyValueRow,
    SectionLabel,
    ProgressBar,
    LevelBadge
}

glob HOUSING_LABELS: dict[str, str] = {
         "have-housing": "Have a place",
         "looking": "Still looking",
         "temporary": "Somewhere temporary"
     },
     STUDENT_LABELS: dict[str, str] = {
         "international": "International student",
         "out-of-state": "Out-of-state student",
         "in-state": "In-state student"
     };

def:pub ProfileStyles -> JsxElement {
    <style>
        {".pf-grid{display:grid;grid-template-columns:minmax(0,1fr);gap:16px;align-items:start}"
            + "@media (min-width: 900px){.pf-grid{grid-template-columns:minmax(0,3fr) minmax(0,2fr);gap:24px}}"}
    </style>
}

def:pub Account -> JsxElement {
    has me: ProfileView | None = None,
        summary: JourneySummary | None = None;

    async def load {
        fresh: ProfileView | None = None;
        fresh = await get_my_profile();
        me = fresh;
        journey: JourneySummary | None = None;
        journey = await my_journey();
        summary = journey;
    }

    can with entry {
        load();
    }

    def logOut(e: MouseEvent) {
        jacLogout();
        window.location.assign("/login");  # jac:ignore[E1032,W2001]
    }

    def arrival(p: ProfileView) -> str {
        if not p.arrival_date {
            return "Not set";
        }
        return p.arrival_date + (" at " + p.arrival_time if p.arrival_time else "");
    }

    link = {
        ** text_style("meta"),
        "minHeight": f"{SIZE['touch-min']}px",
        "display": "inline-flex",
        "alignItems": "center"
    };

    <AppShell title="Profile" active="profile" wide={True}>
        <ProfileStyles/>
        {(
            <div className="pf-grid">
                <div
                    style={{
                        "display": "flex",
                        "flexDirection": "column",
                        "gap": space("4")
                    }}
                >
                    <Card>
                        <div
                            style={{
                                "display": "flex",
                                "alignItems": "center",
                                "gap": space("3")
                            }}
                        >
                            <Avatar
                                initials={(me.display_name or me.umich_email or "U")[:1].upper()}
                            />
                            <div
                                style={{
                                    "display": "flex",
                                    "flexDirection": "column",
                                    "gap": "2px",
                                    "minWidth": "0"
                                }}
                            >
                                <strong style={text_style("stage-title")}>
                                    {me.display_name or "Student"}
                                </strong>
                                <span
                                    style={{
                                        ** text_style("small"),
                                        "color": color("sub"),
                                        "overflowWrap": "anywhere"
                                    }}
                                >
                                    {me.umich_email or "No email yet"}
                                </span>
                            </div>
                        </div>
                        {<Badge kind="progress" label="@umich.edu email confirmed"/>
                            if me.verified
                            else None}
                    </Card>
                    <Card>
                        <SectionLabel label="Your details"/>
                        <p
                            style={{
                                ** text_style("small"),
                                "margin": "0",
                                "color": color("sub")
                            }}
                        >
                            These shape your first-week tasks and the groups we suggest.
                        </p>
                        <KeyValueRow label="Arrival" value={arrival(me)}/>
                        <KeyValueRow
                            label="Housing"
                            value={HOUSING_LABELS.get(me.housing_status, "Not set")}
                        />
                        <KeyValueRow label="Area" value={me.area or "Not set"}/>
                        <KeyValueRow
                            label="Language"
                            value={LANGUAGE_NAMES.get(
                                me.preferred_language, me.preferred_language
                            )}
                        />
                        <KeyValueRow
                            label="Student"
                            value={STUDENT_LABELS.get(me.student_type, "Not set")}
                        />
                        <KeyValueRow
                            label="Airport ride"
                            value={"Needs a ride from DTW"
                                if me.needs_airport_ride
                                else "No"}
                        />
                        <a href="/onboarding" style={link}>Edit your details</a>
                    </Card>
                </div>
                <div
                    style={{
                        "display": "flex",
                        "flexDirection": "column",
                        "gap": space("4")
                    }}
                >
                    {(
                        <Card>
                            <div
                                style={{
                                    "display": "flex",
                                    "justifyContent": "space-between",
                                    "alignItems": "center"
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
                            <span
                                style={{
                                    ** text_style("small"),
                                    "color": color("text-2")
                                }}
                            >
                                {f"{summary.done} of {summary.total} tasks marked done by you · {summary.xp} XP"}
                            </span>
                            <a href="/journey" style={link}>Open your first week</a>
                        </Card>
                    )
                        if summary is not None
                        else None}
                    <Card>
                        <SectionLabel label="Account"/>
                        <a href="/market/mine" style={link}>My posts</a>
                        <a href="/market/chats" style={link}>Messages</a>
                        <Button
                            label="Log out"
                            variant="secondary"
                            full={True}
                            onClick={logOut}
                        />
                    </Card>
                </div>
            </div>
        )
            if me is not None
            else <p style={{"color": color("sub")}}>Loading…</p>}
    </AppShell>
}
