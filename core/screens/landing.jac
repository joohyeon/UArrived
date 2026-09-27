"""/ for visitors: a welcoming introduction to student life in Ann Arbor.

Hero (copy, campus photo, two small example previews), then three outcomes (Get settled, Find
your essentials, Discover campus) in varied layouts, and a closing invitation. Photos are
Wikimedia Commons images credited under each one (public/images/CREDITS.md). Checklist and
marketplace previews are labelled examples; the events are real, from U-M Happening, with links
to their pages. Signed-in students go straight to /today.
"""

import from "@jac/runtime" { jacIsLoggedIn }
import from ui.tokens { color, space, text_style, RADIUS, SIZE, FONTS }
import from ui.components.base { BaseStyles, Badge }
import from journey.events { preview_events, EventView }

glob IMAGES: str = "/static/assets/images/",
     MONTHS: list[str] = [
         "Jan",
         "Feb",
         "Mar",
         "Apr",
         "May",
         "Jun",
         "Jul",
         "Aug",
         "Sep",
         "Oct",
         "Nov",
         "Dec"
     ];

"""Layout rules inline styles can't express: two-column rows that stack on phones (text first),
section links that hide on small screens, and anchor scrolling below the sticky header."""
def:pub LandingStyles -> JsxElement {
    css = (
        "html{scroll-behavior:smooth}"
        + "[id]{scroll-margin-top:84px}"
        + ".lp-row{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:56px;align-items:center}"
        + ".lp-links{display:flex}"
        + ".lp-flip>:first-child{order:2}"
        + "@media (max-width: 900px){"
        + ".lp-row{grid-template-columns:minmax(0,1fr);gap:28px}"
        + ".lp-links{display:none}"
        + ".lp-flip>:first-child{order:0}"
        + ".lp-float{position:static!important;margin-top:12px}"
        + "}"
        + "@media (prefers-reduced-motion: reduce){html{scroll-behavior:auto}}"
    );
    <style>{css}</style>
}

"""A link that looks like a Button: `primary` (indigo, the one main action) or `secondary`."""
def:pub LinkButton(
    href: str, label: str, variant: str = "primary", big: bool = False
) -> JsxElement {
    primary = variant == "primary";
    <a
        href={href}
        style={{
            "display": "inline-flex",
            "alignItems": "center",
            "justifyContent": "center",
            "minHeight": f"{SIZE['button-h'] if big else SIZE['touch-min']}px",
            "padding": "0 " + (space("6") if big else space("4")),
            "borderRadius": f"{RADIUS['button']}px",
            "background": color("action") if primary else color("card"),
            "color": color("on-action") if primary else color("text"),
            "border": "0" if primary else ("1px solid " + color("border-strong")),
            "fontFamily": FONTS["sans"],
            "fontSize": "16px",
            "fontWeight": "600",
            "textDecoration": "none",
            "whiteSpace": "nowrap",
            "boxSizing": "border-box"
        }}
    >
        {label}
    </a>
}

"""A small uppercase coral label above a heading."""
def:pub Kicker(label: str) -> JsxElement {
    <span
        style={{
            ** text_style("label"),
            "display": "inline-flex",
            "alignItems": "center",
            "gap": space("2"),
            "color": color("coral-ink"),
            "textTransform": "uppercase",
            "letterSpacing": "0.08em"
        }}
    >
        <span
            aria-hidden="true"
            style={{
                "width": "8px",
                "height": "8px",
                "borderRadius": "50%",
                "background": color("coral")
            }}
        />
        {label}
    </span>
}

"""A campus photo with its credit line (author and licence, as the licence requires)."""
def:pub Photo(
    file: str,
    alt: str,
    credit: str,
    license: str,
    license_url: str,
    source: str,
    height: str = "420px"
) -> JsxElement {
    <figure
        style={{
            "margin": "0",
            "display": "flex",
            "flexDirection": "column",
            "gap": space("2")
        }}
    >
        <img
            src={IMAGES + file}
            alt={alt}
            loading="lazy"
            style={{
                "width": "100%",
                "height": height,
                "objectFit": "cover",
                "borderRadius": "24px",
                "display": "block",
                "background": color("panel")
            }}
        />
        <figcaption style={{** text_style("caption"), "color": color("sub")}}>
            Photo:{" "}
            <a href={source} style={{"color": color("sub")}}>{credit}</a>
            {", "}
            <a href={license_url} style={{"color": color("sub")}}>{license}</a>
        </figcaption>
    </figure>
}

"""The small "Example" tag on anything illustrative."""
def:pub ExampleTag -> JsxElement {
    <span
        style={{
            ** text_style("badge"),
            "alignSelf": "flex-start",
            "padding": "2px 8px",
            "borderRadius": f"{RADIUS['pill']}px",
            "background": color("panel"),
            "color": color("sub"),
            "textTransform": "uppercase",
            "letterSpacing": "0.06em"
        }}
    >
        Example
    </span>
}

def:pub CheckRow(label: str, kind: str, done: bool) -> JsxElement {
    <li
        style={{
            "display": "flex",
            "alignItems": "center",
            "gap": space("3"),
            "padding": space("2") + " 0",
            "borderTop": "1px solid " + color("border")
        }}
    >
        <span
            role="img"
            aria-label={"Done" if done else "Not done yet"}
            style={{
                "width": "22px",
                "height": "22px",
                "flexShrink": "0",
                "boxSizing": "border-box",
                "borderRadius": f"{RADIUS['check']}px",
                "border": "2px solid "
                    + (color("action") if done else color("border-strong")),
                "background": color("action") if done else color("card"),
                "color": color("on-action"),
                "fontSize": "13px",
                "fontWeight": "700",
                "display": "flex",
                "alignItems": "center",
                "justifyContent": "center"
            }}
        >
            {"✓" if done else ""}
        </span>
        <span
            style={{
                ** text_style("body"),
                "fontSize": "15px",
                "flexGrow": "1",
                "color": color("sub") if done else color("text"),
                "textDecoration": "line-through" if done else "none"
            }}
        >
            {label}
        </span>
        <span style={{** text_style("caption"), "color": color("sub")}}>{kind}</span>
    </li>
}

"""The example first-week checklist: 2 of the 5 steps shown are done."""
def:pub ChecklistPreview -> JsxElement {
    <div
        style={{
            "background": color("card"),
            "border": "1px solid " + color("border"),
            "borderRadius": "20px",
            "padding": space("6"),
            "display": "flex",
            "flexDirection": "column",
            "gap": space("3"),
            "boxShadow": "0 16px 40px " + color("shadow")
        }}
    >
        <ExampleTag/>
        <div
            style={{
                "display": "flex",
                "justifyContent": "space-between",
                "alignItems": "baseline"
            }}
        >
            <strong style={text_style("card-title")}>Your first week</strong>
            <span style={{** text_style("meta"), "color": color("action")}}>
                2 of 5 done
            </span>
        </div>
        <div
            role="img"
            aria-label="2 of 5 steps done"
            style={{
                "height": "8px",
                "borderRadius": "999px",
                "background": color("border")
            }}
        >
            <div
                style={{
                    "width": "40%",
                    "height": "100%",
                    "borderRadius": "999px",
                    "background": color("coral")
                }}
            />
        </div>
        <ul style={{"listStyle": "none", "margin": "0", "padding": "0"}}>
            <CheckRow label="Pick up your MCard" kind="Practical" done={True}/>
            <CheckRow label="Get a US phone number" kind="Practical" done={True}/>
            <CheckRow label="Open a bank account" kind="Practical" done={False}/>
            <CheckRow label="Join the official campus tour" kind="Social" done={False}/>
            <CheckRow label="Go to a welcome event" kind="Social" done={False}/>
        </ul>
    </div>
}

"""One step of the example marketplace flow."""
def:pub FlowStep(n: str, title: str, children: any = None) -> JsxElement {
    <li style={{"display": "flex", "gap": space("4"), "alignItems": "flex-start"}}>
        <span
            aria-hidden="true"
            style={{
                ** text_style("meta"),
                "flexShrink": "0",
                "width": "32px",
                "height": "32px",
                "borderRadius": "50%",
                "background": color("coral"),
                "color": color("text"),
                "display": "flex",
                "alignItems": "center",
                "justifyContent": "center"
            }}
        >
            {n}
        </span>
        <div
            style={{
                "flexGrow": "1",
                "display": "flex",
                "flexDirection": "column",
                "gap": space("2")
            }}
        >
            <span style={{** text_style("meta"), "color": color("text-2")}}>
                {title}
            </span>
            {children}
        </div>
    </li>
}

def:pub bubble(mine: bool) -> dict[str, str] {
    return {
        ** text_style("body"),
        "fontSize": "15px",
        "alignSelf": "flex-start",
        "maxWidth": "100%",
        "padding": space("3") + " " + space("4"),
        "borderRadius": "16px",
        "background": color("action") if mine else color("card"),
        "color": color("on-action") if mine else color("text"),
        "border": "0" if mine else ("1px solid " + color("border"))
    };
}

"""The example: a Selling message in a themed group, the labelled match note, a private chat."""
def:pub MarketFlow -> JsxElement {
    <div
        style={{
            "background": color("card"),
            "border": "1px solid " + color("border"),
            "borderRadius": "20px",
            "padding": space("6"),
            "display": "flex",
            "flexDirection": "column",
            "gap": space("4")
        }}
    >
        <ExampleTag/>
        <ol
            style={{
                "listStyle": "none",
                "margin": "0",
                "padding": "0",
                "display": "flex",
                "flexDirection": "column",
                "gap": space("4")
            }}
        >
            <FlowStep n="1" title="You post in the Furniture group">
                <span style={bubble(True)}>
                    <strong>Selling</strong>
                    {" · IKEA desk and chair, $45 for both. Pick up near North Campus by Oct 3."}
                </span>
            </FlowStep>
            <FlowStep n="2" title="A note under your message points to buyers">
                <div
                    style={{
                        "display": "flex",
                        "flexDirection": "column",
                        "gap": space("2"),
                        "padding": space("3") + " " + space("4"),
                        "borderRadius": "16px",
                        "background": color("ai-bg")
                    }}
                >
                    <Badge kind="ai" label="AI-generated"/>
                    <span style={{** text_style("body"), "fontSize": "15px"}}>
                        2 students in this group are looking for a desk near North Campus.
                    </span>
                </div>
            </FlowStep>
            <FlowStep n="3" title="You settle the details privately">
                <span style={bubble(False)}>
                    <strong>Message privately</strong>
                    {" · \"Hi! Is the desk still available on Saturday?\""}
                </span>
            </FlowStep>
        </ol>
    </div>
}

"""'2026-10-03' -> 'Oct 3'."""
def:pub short_date(iso: str) -> str {
    parts = iso.split("-");
    if len(parts) != 3 {
        return iso;
    }
    return MONTHS[int(parts[1]) - 1] + " " + str(int(parts[2]));
}

def:pub EventRow(e: EventView) -> JsxElement {
    <li
        style={{
            "display": "grid",
            "gridTemplateColumns": "72px minmax(0, 1fr)",
            "gap": space("4"),
            "padding": space("4") + " 0",
            "borderTop": "1px solid " + color("border")
        }}
    >
        <div style={{"display": "flex", "flexDirection": "column"}}>
            <span style={{** text_style("stage-title"), "color": color("coral-ink")}}>
                {short_date(e.date)}
            </span>
            <span style={{** text_style("caption"), "color": color("sub")}}>
                {e.time}
            </span>
        </div>
        <div style={{"display": "flex", "flexDirection": "column", "gap": space("1")}}>
            <strong style={text_style("card-title")}>{e.title}</strong>
            <span style={{** text_style("small"), "color": color("text-2")}}>
                {e.location}
            </span>
            <a
                href={e.url}
                target="_blank"
                rel="noopener noreferrer"
                style={{** text_style("small"), "fontWeight": "600"}}
            >
                Event page on U-M Happening
            </a>
        </div>
    </li>
}

def:pub Landing -> JsxElement {
    has events: list[EventView] = [],
        eventsLoaded: bool = False;

    async def loadEvents {
        fresh: list[EventView] = [];
        try {
            fresh = await preview_events(3);
        } except Exception as err {
            fresh = [];
        }
        events = fresh;
        eventsLoaded = True;
    }

    can with entry {
        if jacIsLoggedIn() {
            window.location.assign("/today");  # jac:ignore[E1032,W2001]
        }
        loadEvents();
    }

    wrap = {
        "maxWidth": "1160px",
        "margin": "0 auto",
        "padding": "0 " + space("4"),
        "boxSizing": "border-box",
        "width": "100%"
    };
    h2 = {
        "margin": "0",
        "fontFamily": FONTS["display"],
        "fontSize": "clamp(30px, 4vw, 42px)",
        "fontWeight": "700",
        "lineHeight": "1.1",
        "color": color("text")
    };
    lead = {
        ** text_style("body"),
        "fontSize": "18px",
        "margin": "0",
        "color": color("text-2")
    };
    nav_link = {
        ** text_style("meta"),
        "fontSize": "15px",
        "color": color("text"),
        "textDecoration": "none",
        "minHeight": f"{SIZE['touch-min']}px",
        "display": "inline-flex",
        "alignItems": "center"
    };

    <div
        style={{
            "minHeight": "100vh",
            "background": color("canvas"),
            "color": color("text")
        }}
    >
        <BaseStyles/>
        <LandingStyles/>
        <header
            style={{
                "position": "sticky",
                "top": "0",
                "zIndex": "10",
                "background": color("canvas"),
                "borderBottom": "1px solid " + color("border")
            }}
        >
            <div
                style={{
                    ** wrap,
                    "minHeight": "68px",
                    "display": "flex",
                    "alignItems": "center",
                    "gap": space("6")
                }}
            >
                <a
                    href="/"
                    style={{
                        "fontFamily": FONTS["display"],
                        "fontSize": "24px",
                        "fontWeight": "700",
                        "color": color("action"),
                        "textDecoration": "none",
                        "marginRight": "auto"
                    }}
                >
                    UMade
                    <span style={{"color": color("coral-ink")}}>It</span>
                </a>
                <nav
                    aria-label="Sections"
                    className="lp-links"
                    style={{"gap": space("6")}}
                >
                    <a href="#settle" style={nav_link}>Get settled</a>
                    <a href="#finds" style={nav_link}>Housing &amp; finds</a>
                    <a href="#campus" style={nav_link}>Campus life</a>
                </nav>
                <div
                    style={{
                        "display": "flex",
                        "gap": space("2"),
                        "alignItems": "center"
                    }}
                >
                    <a
                        href="/login"
                        style={{
                            ** nav_link,
                            "fontWeight": "700",
                            "padding": "0 " + space("2")
                        }}
                    >
                        Sign in
                    </a>
                    <LinkButton href="/signup" label="Create account"/>
                </div>
            </div>
        </header>
        <main>
            <section style={{** wrap, "padding": space("8") + " " + space("4")}}>
                <div className="lp-row">
                    <div
                        style={{
                            "display": "flex",
                            "flexDirection": "column",
                            "gap": space("6")
                        }}
                    >
                        <Kicker label="For student life in Ann Arbor"/>
                        <h1
                            style={{
                                "margin": "0",
                                "fontFamily": FONTS["display"],
                                "fontSize": "clamp(40px, 6.4vw, 68px)",
                                "fontWeight": "700",
                                "lineHeight": "1.02",
                                "letterSpacing": "-0.02em"
                            }}
                        >
                            Settle into Michigan,{" "}
                            <span style={{"color": color("action")}}>together.</span>
                        </h1>
                        <p style={{** lead, "fontSize": "19px", "maxWidth": "540px"}}>
                            Find a place, furnish your space, and discover what's happening around campus. UMadeIt helps you get settled—and make Ann Arbor feel like home.
                        </p>
                        <div
                            style={{
                                "display": "flex",
                                "gap": space("3"),
                                "flexWrap": "wrap"
                            }}
                        >
                            <LinkButton href="/signup" label="Get started" big={True}/>
                            <LinkButton
                                href="#settle"
                                label="Explore UMadeIt"
                                variant="secondary"
                                big={True}
                            />
                        </div>
                        <span style={{** text_style("small"), "color": color("sub")}}>
                            Sign up with your @umich.edu email.
                        </span>
                    </div>
                    <div style={{"position": "relative"}}>
                        <Photo
                            file="diag-festival.jpg"
                            alt="Students gathered on the Diag among white event tents on a sunny day"
                            credit="AndrewHorne"
                            license="CC BY 3.0"
                            license_url="https://creativecommons.org/licenses/by/3.0/"
                            source="https://commons.wikimedia.org/wiki/File:UniversityofMIchiganDiag.JPG"
                            height="clamp(260px, 38vw, 480px)"
                        />
                        <div
                            className="lp-float"
                            style={{
                                "position": "absolute",
                                "left": "-28px",
                                "bottom": "56px",
                                "background": color("card"),
                                "border": "1px solid " + color("border"),
                                "borderRadius": "16px",
                                "padding": space("3") + " " + space("4"),
                                "boxShadow": "0 12px 32px " + color("shadow"),
                                "display": "flex",
                                "flexDirection": "column",
                                "gap": space("1"),
                                "maxWidth": "260px"
                            }}
                        >
                            <ExampleTag/>
                            <strong
                                style={{** text_style("small"), "fontWeight": "700"}}
                            >
                                Match found in Furniture
                            </strong>
                            <span
                                style={{
                                    ** text_style("small"),
                                    "color": color("text-2")
                                }}
                            >
                                A student is buying the desk you're selling.
                            </span>
                        </div>
                    </div>
                </div>
            </section>
            <section
                id="settle"
                style={{** wrap, "padding": space("8") + " " + space("4")}}
            >
                <div className="lp-row lp-flip">
                    <div
                        style={{
                            "display": "flex",
                            "flexDirection": "column",
                            "gap": space("4")
                        }}
                    >
                        <Kicker label="Get settled"/>
                        <h2 style={h2}>A first-week checklist made for you</h2>
                        <p style={lead}>
                            MCard, phone, bank and health service in a sensible order, each with where to go, opening hours and what to bring from official U-M pages. Add the social side too, and mark milestones as you go.
                        </p>
                        <ChecklistPreview/>
                    </div>
                    <div style={{"position": "relative"}}>
                        <Photo
                            file="diag-walk.jpg"
                            alt="A shaded path across the Diag under tall trees"
                            credit="w_lemay"
                            license="CC BY-SA 2.0"
                            license_url="https://creativecommons.org/licenses/by-sa/2.0/"
                            source="https://commons.wikimedia.org/wiki/File:The_Diag,_University_of_Michigan,_University_Avenue,_Ann_Arbor,_MI.jpg"
                            height="clamp(240px, 34vw, 440px)"
                        />
                    </div>
                </div>
            </section>
            <section
                id="finds"
                style={{
                    "background": color("card"),
                    "borderTop": "1px solid " + color("border"),
                    "borderBottom": "1px solid " + color("border")
                }}
            >
                <div style={{** wrap, "padding": space("8") + " " + space("4")}}>
                    <div className="lp-row lp-flip">
                        <div
                            style={{
                                "display": "flex",
                                "flexDirection": "column",
                                "gap": space("4")
                            }}
                        >
                            <Kicker label="Find your essentials"/>
                            <h2 style={h2}>
                                Housing and secondhand finds, from students nearby
                            </h2>
                            <p style={lead}>
                                Post in themed groups like Furniture, Housing &amp; sublets or Rides. Say what you're buying or selling in your own words.
                            </p>
                            <ul
                                style={{
                                    ** lead,
                                    "fontSize": "17px",
                                    "paddingLeft": "22px",
                                    "display": "flex",
                                    "flexDirection": "column",
                                    "gap": space("2")
                                }}
                            >
                                <li>Find students buying what you're selling</li>
                                <li>Find a sublet or a room near campus</li>
                                <li>
                                    Share a ride from DTW with students arriving the same day
                                </li>
                                <li>
                                    Write in English, 한국어 or 中文; others read it in theirs
                                </li>
                            </ul>
                        </div>
                        <MarketFlow/>
                    </div>
                </div>
            </section>
            <section
                id="campus"
                style={{** wrap, "padding": space("8") + " " + space("4")}}
            >
                <div className="lp-row">
                    <div
                        style={{
                            "display": "flex",
                            "flexDirection": "column",
                            "gap": space("4")
                        }}
                    >
                        <Kicker label="Discover campus"/>
                        <h2 style={h2}>See what's happening this week</h2>
                        <p style={lead}>
                            Upcoming events from U-M Happening, with where and when, so saying yes is easy.
                        </p>
                        {(
                            <ul
                                style={{
                                    "listStyle": "none",
                                    "margin": "0",
                                    "padding": "0"
                                }}
                            >
                                {[<EventRow key={e.eid} e={e}/> for e in events]}
                            </ul>
                        )
                            if len(events) > 0
                            else (
                                <p
                                    style={{
                                        ** text_style("small"),
                                        "color": color("sub"),
                                        "margin": "0"
                                    }}
                                >
                                    {"Loading upcoming events…"
                                        if not eventsLoaded
                                        else "Upcoming events show here as U-M Happening lists them."}
                                </p>
                            )}
                    </div>
                    <Photo
                        file="art-fair.jpg"
                        alt="Art fair tents on State Street in front of the Michigan Theater sign"
                        credit="David Harris"
                        license="CC BY-SA 4.0"
                        license_url="https://creativecommons.org/licenses/by-sa/4.0/"
                        source="https://commons.wikimedia.org/wiki/File:Ann_Arbor_Art_Fair,_2019.jpg"
                        height="clamp(240px, 34vw, 460px)"
                    />
                </div>
            </section>
            <section
                style={{
                    ** wrap,
                    "padding": space("4") + " " + space("4") + " " + space("8")
                }}
            >
                <div
                    style={{
                        "background": color("action"),
                        "borderRadius": "28px",
                        "padding": "clamp(32px, 5vw, 56px)",
                        "display": "flex",
                        "flexWrap": "wrap",
                        "alignItems": "center",
                        "justifyContent": "space-between",
                        "gap": space("6")
                    }}
                >
                    <div
                        style={{
                            "display": "flex",
                            "flexDirection": "column",
                            "gap": space("2"),
                            "maxWidth": "560px"
                        }}
                    >
                        <h2 style={{** h2, "color": color("on-action")}}>
                            Make Ann Arbor feel like home.
                        </h2>
                        <p style={{** lead, "color": color("action-soft")}}>
                            It takes a minute to join, and your first week is ready when you are.
                        </p>
                    </div>
                    <div
                        style={{
                            "display": "flex",
                            "flexDirection": "column",
                            "gap": space("2"),
                            "alignItems": "flex-start"
                        }}
                    >
                        <a
                            href="/signup"
                            style={{
                                "display": "inline-flex",
                                "alignItems": "center",
                                "minHeight": f"{SIZE['button-h']}px",
                                "padding": "0 " + space("6"),
                                "borderRadius": f"{RADIUS['button']}px",
                                "background": color("card"),
                                "color": color("action"),
                                "fontFamily": FONTS["sans"],
                                "fontSize": "16px",
                                "fontWeight": "700",
                                "textDecoration": "none"
                            }}
                        >
                            Create account
                        </a>
                        <span
                            style={{
                                ** text_style("small"),
                                "color": color("action-soft")
                            }}
                        >
                            Already a member?{" "}
                            <a
                                href="/login"
                                style={{
                                    "color": color("on-action"),
                                    "fontWeight": "700"
                                }}
                            >
                                Sign in
                            </a>
                        </span>
                    </div>
                </div>
            </section>
        </main>
        <footer
            style={{
                ** wrap,
                ** text_style("small"),
                "padding": space("6") + " " + space("4"),
                "color": color("sub"),
                "borderTop": "1px solid " + color("border")
            }}
        >
            UMadeIt is a student project and is not affiliated with or endorsed by the University of Michigan. Event details come from U-M Happening; check each event page before you go.
        </footer>
    </div>
}
