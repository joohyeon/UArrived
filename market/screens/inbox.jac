"""Matches inbox: the market's landing screen (R8, R13, R21, R29). Suggestions with fact-only
reasons (already in the reader's language), Message privately / Not interested, and an unread badge. Polls
while open. The language picker here stands in for a Profile screen setting until one exists: it
saves `preferred_language`, which also clears the client read cache so the reload is localized."""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Card, Badge, ResponsiveGrid }
import from core.constants { PILOT_LANGUAGES, LANGUAGE_NAMES }
import from core.profile {
    get_my_profile,
    update_my_profile,
    ProfileView,
    ProfileUpdateResult
}
import from market.screens.common { MarketTabs, PostSummary, go, ReportBox, Choice }
import from market.moderation { report_post, block_in_suggestion }
import from market.suggestions { list_my_suggestions, SuggestionView }
import from market.connect { decline }
import from market.threads { start_thread, ThreadResult }
import from market.notify { mark_suggestions_seen }
import from market.feed { heartbeat }

glob POLL_MS: int = 10000;

def:pub MatchesInbox -> JsxElement {
    has items: list[SuggestionView] = [],
        loaded: bool = False,
        status: str = "",
        lang: str = "en";

    async def load -> None;
    async def accept(pair: str) -> None;
    async def pass_on(sid: str) -> None;
    async def blockThem(sid: str) -> None;
    async def loadLanguage -> None;
    async def chooseLanguage(code: str) -> None;

    can with entry {
        loadLanguage();
        load();
        timer = setInterval(lambda { load(); }, POLL_MS);  # jac:ignore[W2001]
        return lambda { clearInterval(timer); };  # jac:ignore[W2001]
    }

    <AppShell title="Matches" active="market" wide={True}>
        <MarketTabs
            active="/market/matches"
            unread={len(
                [
                    i
                    for i in items
                    if i.unread
                ]
            )}
        />
        <Choice
            label="Language"
            value={lang}
            options={[(code, LANGUAGE_NAMES[code]) for code in PILOT_LANGUAGES]}
            onChange={lambda (v: str) { chooseLanguage(v); }}
        />
        {<p role="status">{status}</p> if status else None}
        {(
            <Card>
                <strong>No matches yet</strong>
                <p style={{"margin": "0", "color": color("text-2")}}>
                    Drop one message about what you're selling, giving away or looking for, and we'll suggest it to students it fits.
                </p>
                <Button
                    label="Drop a message"
                    onClick={lambda (e: MouseEvent) { go("/market/new"); }}
                />
            </Card>
        )
            if loaded and len(items) == 0
            else None}
        <ResponsiveGrid min="340px">
            {[
                <Card key={s.id}>
                    <div
                        style={{
                            "display": "flex",
                            "gap": space("2"),
                            "alignItems": "center"
                        }}
                    >
                        {<Badge kind="progress" label="New"/> if s.unread else None}
                        <span style={{"color": color("sub"), "fontSize": "14px"}}>
                            {"For your post: " + s.my_post.title}
                        </span>
                    </div>
                    <PostSummary p={s.other_post}/>
                    <ul
                        lang={lang}
                        style={{
                            "margin": "0",
                            "paddingLeft": "20px",
                            "color": color("progress")
                        }}
                    >
                        {[<li key={r}>{r}</li> for r in s.reasons]}
                    </ul>
                    {(
                        <div style={{"display": "flex", "gap": space("2")}}>
                            <Button
                                label="I'm interested"
                                onClick={lambda (e: MouseEvent) { accept(
                                    s.other_post.id + "|" + s.my_post.id
                                ); }}
                            />
                            <Button
                                label="Not interested"
                                variant="secondary"
                                onClick={lambda (e: MouseEvent) { pass_on(s.id); }}
                            />
                        </div>
                    )
                        if s.status == "open" or s.status == "connected"
                        else None}
                    <div
                        style={{
                            "display": "flex",
                            "gap": space("2"),
                            "flexWrap": "wrap"
                        }}
                    >
                        <ReportBox
                            onSubmit={lambda (r: str) { return report_post(
                                s.other_post.id, r
                            ); }}
                        />
                        <Button
                            label="Block"
                            variant="text"
                            onClick={lambda (e: MouseEvent) { blockThem(s.id); }}
                        />
                    </div>
                </Card> for s in items
            ]}
        </ResponsiveGrid>
    </AppShell>
}

impl MatchesInbox.load -> None {
    fresh: list[SuggestionView] = [];
    await heartbeat();
    fresh = await list_my_suggestions();
    items = fresh;
    loaded = True;
    unseen = [
        i.id
        for i in fresh
        if i.unread
    ];
    if len(unseen) > 0 {
        await mark_suggestions_seen(unseen);
    }
}

impl MatchesInbox.loadLanguage -> None {
    me: ProfileView | None = None;
    me = await get_my_profile();
    lang = me.preferred_language or "en";
}

"""Save the picked language (a write, so the read cache clears) and reload the matches in it."""
impl MatchesInbox.chooseLanguage(code: str) -> None {
    result: ProfileUpdateResult | None = None;
    lang = code;
    result = await update_my_profile({"preferred_language": code});
    if not result.ok {
        status = result.error;
        await loadLanguage();
        return;
    }
    status = "";
    await load();
}

"""Open a private thread with the other post's owner (plan 2026-09-27-003 M-R4). `pair` is
"<their post id>|<my post id>"."""
impl MatchesInbox.accept(pair: str) -> None {
    result: ThreadResult | None = None;
    ids = pair.split("|");
    result = await start_thread(ids[0], ids[1], "", "");
    if result is None {
        return;
    }
    if not result.ok {
        status = result.error;
        await load();
        return;
    }
    go("/market/chat?id=" + result.chat_id);
}

impl MatchesInbox.pass_on(sid: str) -> None {
    await decline(sid);
    await load();
}

impl MatchesInbox.blockThem(sid: str) -> None {
    await block_in_suggestion(sid);
    await load();
}
