"""Help me decide (U10): 2-3 posts side by side (stacked on phones), what each is missing, rule
flags, then AI-phrased questions and notes, labeled. Opened from the For you feed."""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Card, Badge }
import from market.screens.common { MarketTabs, PostSummary, query_param }
import from market.decide { help_me_decide, DecideResult, Compared }

def:pub Compare -> JsxElement {
    has result: DecideResult | None = None;

    async def load -> None;

    can with entry {
        load();
    }

    <AppShell title="Help me decide" active="market">
        <MarketTabs active="/market/feed"/>
        {<Card>
            <p style={{"margin": "0"}}>Comparing...</p>
        </Card>
            if result is None
            else None}
        {<Card>
            <p role="alert" style={{"margin": "0"}}>{result.error}</p>
        </Card>
            if result and not result.ok
            else None}
        <div
            style={{
                "display": "grid",
                "gridTemplateColumns": "repeat(auto-fit, minmax(240px, 1fr))",
                "gap": space("3")
            }}
        >
            {[
                <Card key={c.post.id}>
                    <PostSummary p={c.post}/>
                    <strong style={{"fontSize": "14px"}}>Missing</strong>
                    <span style={{"color": color("sub")}}>
                        {", ".join(c.missing)
                            if len(c.missing) > 0
                            else "Nothing obvious"}
                    </span>
                    {[<Badge key={f} kind="warning" label={f}/> for f in c.flags]}
                </Card> for c in (result.posts if result and result.ok else [])
            ]}
        </div>
        {(
            <Card>
                <div
                    style={{
                        "display": "flex",
                        "justifyContent": "space-between",
                        "alignItems": "center"
                    }}
                >
                    <strong>Questions to ask</strong>
                    <Badge kind="ai" label="AI-generated"/>
                </div>
                <ul style={{"margin": "0", "paddingLeft": "20px"}}>
                    {[<li key={q}>{q}</li> for q in result.questions]}
                </ul>
                {<ul
                    style={{
                        "margin": "0",
                        "paddingLeft": "20px",
                        "color": color("warning")
                    }}
                >
                    {[<li key={n}>{n}</li> for n in result.risk_notes]}
                </ul>
                    if len(result.risk_notes) > 0
                    else None}
                <p style={{"margin": "0", "color": color("sub"), "fontSize": "14px"}}>
                    These notes explain the flags above. They can't tell you whether a post is genuine: meet in public and never pay before you've seen it.
                </p>
            </Card>
        )
            if result and result.ok and result.ai_generated
            else None}
        {<Card>
            <p style={{"margin": "0"}}>{result.ai_note}</p>
        </Card>
            if result and result.ok and result.ai_note
            else None}
    </AppShell>
}

impl Compare.load -> None {
    fresh: DecideResult | None = None;
    ids = [
        x
        for x in query_param("ids").split(",")
        if x
    ];
    fresh = await help_me_decide(ids);
    result = fresh;
}
