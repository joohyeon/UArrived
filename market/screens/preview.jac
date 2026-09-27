"""Dev-only layout preview (no login, no real data): every redesigned market list rendered with
mock data so the tablet/desktop grid and list+detail layouts can be seen and screenshotted without
seeding the dev database. Same purpose as `ui/components/gallery.jac`'s `/ui`; reachable at
`/market/preview`, exempted from the market login gate in `main.jac` the same way `/ui` is."""

import from ui.tokens { color }
import from ui.components.base { AppShell, Card, Badge, ResponsiveGrid }
import from market.screens.common { PostSummary }
import from market.lifecycle { PostView }
import from market.themes { GroupSummary }
import from market.connect { ChatView }
import from market.suggestions { SuggestionView }
import from market.moderation { ReportView }

"""The optional, less-common fields of a mock listing, grouped into one object so `sample_post`
stays under the too-many-params lint threshold. Every field defaults to what the original three
sample posts always used, so those callers don't need to pass this at all."""
obj SampleMeta {
    has poster_name: str = "A student",
        available_from: str = "2026-08-20",
        available_until: str = "2026-08-30",
        time_from: str = "",
        route_from: str = "",
        route_to: str = "",
        ai_generated: bool = False;
}

"""One mock listing. `content` is (title, description) grouped into one parameter, and the
less-common fields live on `meta` (`SampleMeta`), both to stay under the too-many-params lint
threshold."""
def sample_post(
    id: str,
    kind: str,
    category: str,
    content: tuple[str, str],
    price: float | None,
    area: str,
    meta: SampleMeta = SampleMeta()
) -> PostView {
    (title, description) = content;
    return PostView(
        id=id,
        mine=False,
        status="live",
        poster_name=meta.poster_name,
        kind=kind,
        category=category,
        title=title,
        description=description,
        price=price,
        free=price == 0,
        available_from=meta.available_from,
        available_until=meta.available_until,
        time_from=meta.time_from,
        time_to="",
        area=area,
        route_from=meta.route_from,
        route_to=meta.route_to,
        arrangement="sublet" if category == "housing" else "",
        ai_generated=meta.ai_generated,
        expires_on="2026-09-15"
    );
}

"""Second-hand items with a real match on the other side, so the interactive match finder below
has something to show. Kept separate from `PREVIEW_POSTS`'s original three so those stay
untouched and these can be referenced by name from `PREVIEW_SUGGESTIONS`."""
glob POST_DESK_OFFER: PostView = sample_post(
         "p4",
         "offer",
         "furniture",
         (
             "IKEA study desk",
             "Light scratches on top, otherwise solid. Pickup in Kerrytown."
         ),
         25.0,
         "Kerrytown",
         meta=SampleMeta(
             ai_generated=True,
             poster_name="Priya",
             available_from="2026-08-18",
             available_until="2026-08-25"
         )
     ),
     POST_DESK_REQUEST: PostView = sample_post(
         "p5",
         "request",
         "furniture",
         (
             "Need a desk for my dorm",
             "Anything sturdy under $50 works, moving in next week."
         ),
         50.0,
         "Kerrytown",
         meta=SampleMeta(
             poster_name="Sam",
             available_from="2026-08-20",
             available_until="2026-08-22"
         )
     ),
     POST_FRIDGE_OFFER: PostView = sample_post(
         "p6",
         "offer",
         "essentials",
         ("Mini fridge, works great", "Free to a good home, must pick up by Friday."),
         0.0,
         "South Quad",
         meta=SampleMeta(poster_name="Wei")
     ),
     POST_FRIDGE_REQUEST: PostView = sample_post(
         "p7",
         "request",
         "essentials",
         ("Looking for a mini fridge", "Just moved into South Quad, need one ASAP."),
         None,
         "South Quad",
         meta=SampleMeta(poster_name="Luis")
     ),
     POST_MATTRESS_OFFER: PostView = sample_post(
         "p8",
         "offer",
         "furniture",
         (
             "Twin XL mattress, like new",
             "Selling since I'm switching to a full-size bed."
         ),
         40.0,
         "North Campus",
         meta=SampleMeta(
             poster_name="Aisha",
             available_from="2026-08-15",
             available_until="2026-08-25"
         )
     ),
     POST_MATTRESS_REQUEST: PostView = sample_post(
         "p9",
         "request",
         "furniture",
         ("Need a twin mattress", "Move-in is Sept 2, budget is a little tight."),
         45.0,
         "Central Campus",
         meta=SampleMeta(
             poster_name="Marco",
             available_from="2026-08-18",
             available_until="2026-08-24"
         )
     ),
     POST_SUBLET_REQUEST: PostView = sample_post(
         "p10",
         "request",
         "housing",
         ("Looking for a fall sublet", "Sept-Dec, quiet, near central campus."),
         1000.0,
         "Kerrytown",
         meta=SampleMeta(
             poster_name="Noah",
             available_from="2026-08-25",
             available_until="2026-09-05"
         )
     ),
     POST_RIDE_A: PostView = sample_post(
         "p11",
         "request",
         "service",
         ("Looking for a ride from DTW", "Landing Aug 25, 3pm. Happy to split gas."),
         None,
         "",
         meta=SampleMeta(
             poster_name="Tariq",
             available_from="2026-08-25",
             available_until="2026-08-25",
             time_from="14:30",
             route_from="DTW",
             route_to="Ann Arbor"
         )
     ),
     POST_RIDE_B: PostView = sample_post(
         "p12",
         "request",
         "service",
         ("Anyone flying into DTW around 3pm on Aug 25?", "Want to split an Uber."),
         None,
         "",
         meta=SampleMeta(
             poster_name="Grace",
             available_from="2026-08-25",
             available_until="2026-08-25",
             time_from="15:00",
             route_from="Detroit Metro Airport",
             route_to="ann arbor"
         )
     ),
     POST_BOOKSHELF_OFFER: PostView = sample_post(
         "p13",
         "offer",
         "furniture",
         (
             "Bookshelf, IKEA Kallax",
             "Great condition, no scratches. Leaving in December."
         ),
         20.0,
         "South Quad",
         meta=SampleMeta(poster_name="Ben")
     ),
     POST_BIKE_OFFER: PostView = sample_post(
         "p14",
         "offer",
         "vehicle",
         ("Bike for sale, great condition", "Selling before I leave for winter break."),
         60.0,
         "Central Campus",
         meta=SampleMeta(poster_name="Chloe")
     );

glob PREVIEW_POSTS: list[PostView] = [
         sample_post(
             "p1",
             "offer",
             "furniture",
             (
                 "Twin XL bed frame + mattress",
                 "Barely used, moving out Aug 28. Pickup only, South Quad area."
             ),
             60.0,
             "South Quad",
             meta=SampleMeta(ai_generated=True)
         ),
         sample_post(
             "p2",
             "request",
             "vehicle",
             (
                 "Looking for a ride from DTW",
                 "Landing Aug 25, 3pm. Happy to split gas."
             ),
             None,
             "Central Campus"
         ),
         sample_post(
             "p3",
             "offer",
             "housing",
             (
                 "Sublet: 1BR near Kerrytown",
                 "Sept-Dec, quiet building, 8 min walk to Diag."
             ),
             950.0,
             "Kerrytown"
         ),
         POST_DESK_OFFER,
         POST_DESK_REQUEST,
         POST_FRIDGE_OFFER,
         POST_FRIDGE_REQUEST,
         POST_MATTRESS_OFFER,
         POST_MATTRESS_REQUEST,
         POST_SUBLET_REQUEST,
         POST_RIDE_A,
         POST_RIDE_B,
         POST_BOOKSHELF_OFFER,
         POST_BIKE_OFFER
     ],
     PREVIEW_GROUPS: list[GroupSummary] = [
         GroupSummary(
             id="g0",
             key="furniture",
             name="Furniture",
             icon="🪑",
             description="Desks, beds, mattresses, chairs, shelves and sofas.",
             members=212,
             member=True,
             suggested=False,
             last_message="Selling my IKEA desk, $30, pickup in Kerrytown",
             last_at="2026-09-20"
         ),
         GroupSummary(
             id="g1",
             key="textbooks",
             name="Textbooks",
             icon="📚",
             description="Course books, readers and study guides.",
             members=48,
             member=False,
             suggested=False,
             last_message="",
             last_at=""
         ),
         GroupSummary(
             id="g2",
             key="moveout",
             name="Move-out sales",
             icon="📦",
             description="Leaving Ann Arbor? Sell or give away everything in one place.",
             members=96,
             member=False,
             suggested=True,
             last_message="",
             last_at=""
         )
     ],
     PREVIEW_CHATS: list[ChatView] = [
         ChatView(
             id="c1",
             open=True,
             my_post_title="Twin XL bed frame + mattress",
             other_post_title="Looking for a bed frame",
             last_message="Does it come with the mattress too?",
             last_at="2026-09-20"
         ),
         ChatView(
             id="c2",
             open=False,
             my_post_title="",
             other_post_title="Sublet: 1BR near Kerrytown",
             last_message="Thanks, already found a place!",
             last_at="2026-09-10"
         )
     ],
     PREVIEW_SUGGESTIONS: list[SuggestionView] = [
         SuggestionView(
             id="s1",
             status="pending",
             score=92,
             reasons=["Same move-out window", "Both in South Quad"],
             my_post=PREVIEW_POSTS[1],
             other_post=PREVIEW_POSTS[0],
             i_accepted=False,
             unread=True
         ),
         SuggestionView(
             id="s2",
             status="pending",
             score=95,
             reasons=[
                 "Dates overlap",
                 "$25 is within the $50 budget",
                 "Both in Kerrytown"
             ],
             my_post=POST_DESK_REQUEST,
             other_post=POST_DESK_OFFER,
             i_accepted=False,
             unread=True
         ),
         SuggestionView(
             id="s3",
             status="pending",
             score=80,
             reasons=["It's free", "Both in South Quad"],
             my_post=POST_FRIDGE_REQUEST,
             other_post=POST_FRIDGE_OFFER,
             i_accepted=False,
             unread=True
         ),
         SuggestionView(
             id="s4",
             status="pending",
             score=65,
             reasons=["Dates overlap", "$40 is within the $45 budget"],
             my_post=POST_MATTRESS_REQUEST,
             other_post=POST_MATTRESS_OFFER,
             i_accepted=False,
             unread=False
         ),
         SuggestionView(
             id="s5",
             status="pending",
             score=90,
             reasons=["Dates overlap", "Both want a sublet", "Both in Kerrytown"],
             my_post=POST_SUBLET_REQUEST,
             other_post=PREVIEW_POSTS[2],
             i_accepted=False,
             unread=True
         ),
         SuggestionView(
             id="s6",
             status="pending",
             score=85,
             reasons=["Same route: DTW to Ann Arbor", "Times are 30 minutes apart"],
             my_post=POST_RIDE_A,
             other_post=POST_RIDE_B,
             i_accepted=False,
             unread=True
         )
     ],
     PREVIEW_REPORTS: list[ReportView] = [
         ReportView(
             id="r1",
             post_id="p1",
             post_title="Twin XL bed frame + mattress",
             chat_id="",
             reason="Seller asked for a deposit over text before meeting.",
             created_at="2026-09-21"
         )
     ];

"""The suggestions in `PREVIEW_SUGGESTIONS` that involve `post_id`, on either side."""
def matches_for(post_id: str) -> list[SuggestionView] {
    return [
        s
        for s in PREVIEW_SUGGESTIONS
        if s.my_post.id == post_id or s.other_post.id == post_id
    ];
}

"""The post in `PREVIEW_POSTS` with `post_id`, or None when it isn't one of the mock posts."""
def post_by_id(post_id: str) -> PostView | None {
    found = [
        p
        for p in PREVIEW_POSTS
        if p.id == post_id
    ];
    return found[0] if found else None;
}

"""Whichever side of suggestion `s` is not the post the student is looking from."""
def other_side(s: SuggestionView, post_id: str) -> PostView {
    return s.other_post if s.my_post.id == post_id else s.my_post;
}

"""The assistant's "nothing yet" note, in the same voice as the real one written by
market/messages.jac's `compose_note` (kept as a literal here since a client screen can't import a
rules function, only `def:pub`/`def:protect` ones)."""
def no_match_text(post: PostView | None) -> str {
    if post is None {
        return "";
    }
    nobody = "No offers match yet."
        if post.kind == "request"
        else "Nobody is looking for this yet.";
    return nobody + " I'll keep looking and tell you when one does.";
}

def:pub Section(title: str, children: any = None) -> JsxElement {
    <div style={{"display": "flex", "flexDirection": "column", "gap": "8px"}}>
        <h2 style={{"margin": "0", "fontSize": "18px"}}>{title}</h2>
        {children}
    </div>
}

"""Every market list, side by side with mock data, at whatever width the browser window is."""
def:pub MarketPreview -> JsxElement {
    has selected_id: str = "";

    selected_post = post_by_id(selected_id) if selected_id else None;
    current_matches = matches_for(selected_id) if selected_id else [];

    <AppShell title="Market layout preview" active="market" wide={True}>
        <p style={{"margin": "0"}}>
            Mock data only, for checking the tablet/desktop grid layouts without a seeded database. Resize the window to see the column count change.
        </p>
        <Section title="Groups">
            <ResponsiveGrid min="320px">
                {[
                    <Card key={g.id}>
                        <strong>{g.icon + " " + g.name}</strong>
                        {<Badge kind="action" label="Suggested for you"/>
                            if g.suggested
                            else None}
                        <span>{g.last_message or g.description}</span>
                    </Card> for g in PREVIEW_GROUPS
                ]}
            </ResponsiveGrid>
        </Section>
        <Section title="Chats">
            <ResponsiveGrid min="320px">
                {[
                    <Card key={c.id}>
                        <div
                            style={{
                                "display": "flex",
                                "justifyContent": "space-between"
                            }}
                        >
                            <strong>{c.other_post_title}</strong>
                            {<Badge kind="warning" label="Closed"/>
                                if not c.open
                                else None}
                        </div>
                        <span>{c.last_message}</span>
                    </Card> for c in PREVIEW_CHATS
                ]}
            </ResponsiveGrid>
        </Section>
        <Section title="Matches">
            <ResponsiveGrid min="340px">
                {[
                    <Card key={s.id}>
                        <PostSummary p={s.other_post}/>
                        <ul style={{"margin": "0", "paddingLeft": "20px"}}>
                            {[<li key={r}>{r}</li> for r in s.reasons]}
                        </ul>
                    </Card> for s in PREVIEW_SUGGESTIONS
                ]}
            </ResponsiveGrid>
        </Section>
        <Section title="My posts / For you">
            <p style={{"margin": "0", "color": color("sub"), "fontSize": "14px"}}>
                Click a listing to see who the assistant would match it with, and why.
            </p>
            <ResponsiveGrid min="280px">
                {[
                    <div
                        key={p.id}
                        onClick={lambda (e: MouseEvent) { selected_id = ""
                            if selected_id == p.id
                            else p.id; }}
                        style={{
                            "cursor": "pointer",
                            "borderRadius": "12px",
                            "outline": ("2px solid " + color("action"))
                                if selected_id == p.id
                                else "none",
                            "outlineOffset": "2px"
                        }}
                    >
                        <Card>
                            <PostSummary p={p}/>
                        </Card>
                    </div> for p in PREVIEW_POSTS
                ]}
            </ResponsiveGrid>
        </Section>
        <Section title="AI match finder">
            {(
                <p style={{"margin": "0", "color": color("sub")}}>
                    Click a listing above to see who the marketplace assistant would match it with.
                </p>
            )
                if selected_post is None
                else None}{(
                <div
                    style={{
                        "display": "flex",
                        "flexDirection": "column",
                        "gap": "12px"
                    }}
                >
                    <p style={{"margin": "0", "color": color("sub")}}>
                        {"Matches for \"" + selected_post.title + "\":"}
                    </p>
                    {(
                        <ResponsiveGrid min="340px">
                            {[
                                <Card key={s.id}>
                                    <PostSummary p={other_side(s, selected_id)}/>
                                    <ul style={{"margin": "0", "paddingLeft": "20px"}}>
                                        {[<li key={r}>{r}</li> for r in s.reasons]}
                                    </ul>
                                </Card> for s in current_matches
                            ]}
                        </ResponsiveGrid>
                    )
                        if len(current_matches) > 0
                        else (
                            <Card>
                                <p style={{"margin": "0"}}>
                                    {no_match_text(selected_post)}
                                </p>
                            </Card>
                        )}
                </div>
            )
                if selected_post is not None
                else None}
        </Section>
        <Section title="Moderation queue">
            <ResponsiveGrid min="360px">
                {[
                    <Card key={r.id}>
                        <strong>{r.post_title}</strong>
                        <p style={{"margin": "0"}}>{r.reason}</p>
                    </Card> for r in PREVIEW_REPORTS
                ]}
            </ResponsiveGrid>
        </Section>
    </AppShell>
}
