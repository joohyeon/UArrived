"""Matches inbox: the market's landing screen (R8, R13, R21). Suggestions with fact-only reasons,
Connect / Not interested, and an unread badge. Polls while open."""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Card, Badge }
import from market.screens.common { MarketTabs, PostSummary, go, ReportBox }
import from market.moderation { report_post, block_in_suggestion }
import from market.suggestions { list_my_suggestions, SuggestionView }
import from market.connect { connect, decline, ConnectResult }
import from market.notify { mark_suggestions_seen }
import from market.feed { heartbeat }

glob POLL_MS: int = 10000;

def:pub MatchesInbox -> JsxElement {
    has items: list[SuggestionView] = [],
        loaded: bool = False,
        status: str = "";

    async def load -> None;
    async def accept(sid: str) -> None;
    async def pass_on(sid: str) -> None;
    async def blockThem(sid: str) -> None;

    can with entry {
        load();
        timer = setInterval(lambda { load(); }, POLL_MS);  # jac:ignore[W2001]
        return lambda { clearInterval(timer); };  # jac:ignore[W2001]
    }

    <AppShell title="Matches" active="market">
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
                            label="Connect"
                            onClick={lambda (e: MouseEvent) { accept(s.id); }}
                        />
                        <Button
                            label="Not interested"
                            variant="secondary"
                            onClick={lambda (e: MouseEvent) { pass_on(s.id); }}
                        />
                    </div>
                )
                    if not s.i_accepted
                    else (
                        <p style={{"margin": "0", "color": color("sub")}}>
                            {"You're connected: open Chats."
                                if s.status == "connected"
                                else "Waiting for them to connect too."}
                        </p>
                    )}
                <div style={{"display": "flex", "gap": space("2"), "flexWrap": "wrap"}}>
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

impl MatchesInbox.accept(sid: str) -> None {
    result: ConnectResult | None = None;
    result = await connect(sid);
    if not result.ok {
        status = result.error;
    } elif result.connected {
        go("/market/chat?id=" + result.chat_id);
        return;
    } else {
        status = "Sent. You'll be able to chat once they connect too.";
    }
    await load();
}

impl MatchesInbox.pass_on(sid: str) -> None {
    await decline(sid);
    await load();
}

impl MatchesInbox.blockThem(sid: str) -> None {
    await block_in_suggestion(sid);
    await load();
}
