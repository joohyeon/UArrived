"""Dev-only layout preview (no login, no real data): every redesigned market list rendered with
mock data so the tablet/desktop grid and list+detail layouts can be seen and screenshotted without
seeding the dev database. Same purpose as `ui/components/gallery.jac`'s `/ui`; reachable at
`/market/preview`, exempted from the market login gate in `main.jac` the same way `/ui` is."""

import from ui.components.base { AppShell, Card, Badge, ResponsiveGrid }
import from market.screens.common { PostSummary }
import from market.lifecycle { PostView }
import from market.themes { GroupSummary }
import from market.connect { ChatView }
import from market.suggestions { SuggestionView }
import from market.moderation { ReportView }

"""One mock listing. `content` is (title, description) grouped into one parameter to stay under
the too-many-params lint threshold."""
def sample_post(
    id: str,
    kind: str,
    category: str,
    content: tuple[str, str],
    price: float | None,
    area: str,
    ai_generated: bool = False
) -> PostView {
    (title, description) = content;
    return PostView(
        id=id,
        mine=False,
        status="live",
        poster_name="A student",
        kind=kind,
        category=category,
        title=title,
        description=description,
        price=price,
        free=price == 0,
        available_from="2026-08-20",
        available_until="2026-08-30",
        time_from="",
        time_to="",
        area=area,
        route_from="",
        route_to="",
        arrangement="sublet" if category == "housing" else "",
        ai_generated=ai_generated,
        expires_on="2026-09-15"
    );
}

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
             ai_generated=True
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
         )
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

def:pub Section(title: str, children: any = None) -> JsxElement {
    <div style={{"display": "flex", "flexDirection": "column", "gap": "8px"}}>
        <h2 style={{"margin": "0", "fontSize": "18px"}}>{title}</h2>
        {children}
    </div>
}

"""Every market list, side by side with mock data, at whatever width the browser window is."""
def:pub MarketPreview -> JsxElement {
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
            <ResponsiveGrid min="280px">
                {[
                    <Card key={p.id}>
                        <PostSummary p={p}/>
                    </Card> for p in PREVIEW_POSTS
                ]}
            </ResponsiveGrid>
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
