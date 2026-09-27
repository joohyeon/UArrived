"""/interests: the one-time post-signup pick of interest categories that personalizes the Events
tab (U3, plan 2026-09-27-003). Shown once right after signup; a student who already has interests
set skips straight past it (checked in journey/screens/today.jac's `Today.load`).
"""

import from ui.tokens { color, space }
import from ui.components.base { BaseStyles, Button }
import from ui.components.blocks { QuestionBlock, Chip }
import from journey.constants { INTEREST_CATEGORIES }
import from journey.interests { set_interests, my_interests }
import from journey.screens.common { query_param }

def:pub InterestsGate -> JsxElement {
    has picked: list[str] = [],
        busy: bool = False;

    async def load -> None;

    can with entry {
        load();
    }

    def toggle(cat: str) {
        picked = [
            c
            for c in picked
            if c != cat
        ]
            if cat in picked
            else picked + [cat];
    }

    async def go(categories: list[str]) -> None;

    <div style={{"minHeight": "100vh", "background": color("ground")}}>
        <BaseStyles/>
        <main
            style={{
                "maxWidth": "420px",
                "minHeight": "100vh",
                "margin": "0 auto",
                "padding": space("8") + " " + space("4") + " " + space("6"),
                "boxSizing": "border-box",
                "display": "flex",
                "flexDirection": "column",
                "gap": space("6")
            }}
        >
            <QuestionBlock
                eyebrow="ONE QUICK PICK"
                title="What sounds like you?"
                subtitle="Pick a few things you're into so we can point out events worth going to. You can always browse everything, picked or not."
            />
            <div style={{"display": "flex", "flexWrap": "wrap", "gap": space("2")}}>
                {[
                    <Chip
                        key={cat}
                        label={cat}
                        selected={cat in picked}
                        onSelect={lambda { toggle(cat); }}
                    /> for cat in INTEREST_CATEGORIES
                ]}
            </div>
            <Button
                label={"Saving…" if busy else "Continue →"}
                onClick={lambda (e: MouseEvent) { go(picked); }}
                full={True}
                disabled={busy}
            />
            <button
                type="button"
                onClick={lambda (e: MouseEvent) { go(picked); }}
                disabled={busy}
                style={{
                    "background": "none",
                    "border": "0",
                    "color": color("sub"),
                    "textDecoration": "underline",
                    "cursor": "pointer",
                    "padding": "0"
                }}
            >
                Skip for now
            </button>
        </main>
    </div>
}

"""Only a same-origin path is a safe redirect target. `?next=` is student-supplied input read
straight from the URL, so a bare "/today" default plus rejecting anything that isn't a genuine
relative path (no "//host" protocol-relative URL, no "javascript:" or other scheme) stops it being
used to send a logged-in student to an external site or run script in their session."""
def:pub safe_next(raw: str) -> str {
    return raw if raw.startswith("/") and not raw.startswith("//") else "/today";
}

"""Pre-fills the picker with whatever the student already has -- a no-op empty list for a
first-time visitor, but this screen is also reachable later to change a previous pick (the Events
screen's "Edit your interests" link), so a returning visitor should see their current picks
checked, not a blank slate they'd overwrite by accident."""
impl InterestsGate.load -> None {
    existing: list[str] = [];
    existing = await my_interests();
    picked = existing;
}

impl InterestsGate.go(categories: list[str]) -> None {
    busy = True;
    await set_interests(categories);
    window.location.assign(safe_next(query_param("next")));  # jac:ignore[E1032,W2001]
}
