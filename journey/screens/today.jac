"""Today (stub for U9): shows journey prompts that lead into the marketplace.

Feature A owns the real Today screen (next three actions, milestones); this stub only renders
`my_journey_prompts` so the DTW ride-share link works end to end until then. Replace freely.
"""

import from ui.tokens { color }
import from ui.components.base { AppShell, Card, Badge }
import from journey.prompts { my_journey_prompts, JourneyPrompt }

def:pub Today -> JsxElement {
    has prompts: list[JourneyPrompt] = [],
        loaded: bool = False;

    async def load -> None;

    can with entry {
        load();
    }

    <AppShell title="Today" active="today">
        {(
            <Card>
                <p style={{"margin": "0"}}>
                    Nothing to suggest yet. Add your arrival date and whether you need an airport ride in Profile.
                </p>
            </Card>
        )
            if loaded and not prompts
            else None}{[
            <Card key={p.key}>
                <strong style={{"fontSize": "18px"}}>{p.title}</strong>
                <p style={{"margin": "0", "color": color("text-2")}}>{p.body}</p>
                <a
                    href={p.link}
                    style={{
                        "display": "inline-flex",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "minHeight": "44px",
                        "borderRadius": "12px",
                        "background": color("action"),
                        "color": color("on-action"),
                        "fontWeight": "600",
                        "textDecoration": "none"
                    }}
                >
                    {p.action_label}
                </a>
            </Card> for p in prompts
        ]}
    </AppShell>
}

impl Today.load -> None {
    fresh: list[JourneyPrompt] = [];
    fresh = await my_journey_prompts();
    prompts = fresh;
    loaded = True;
}
