"""My posts (R10, R11, R18): each post's status, who it was suggested to, and the poster's
controls: stop suggestions, mark done, renew. Plus the "For you" feed (R13), kept secondary."""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Card, Badge }
import from market.screens.common { MarketTabs, PostSummary, go }
import from market.lifecycle {
    list_my_posts,
    mark_post_done,
    renew_post,
    PostView,
    PostResult
}
import from market.suggestions { list_my_suggestions, stop_suggestions, SuggestionView }
import from market.feed { for_you_feed }

def:pub MyPosts -> JsxElement {
    has posts: list[PostView] = [],
        suggestions: list[SuggestionView] = [],
        loaded: bool = False;

    async def load -> None;
    async def done(post_id: str) -> None;
    async def renew(post_id: str) -> None;
    async def stop(post_id: str) -> None;

    can with entry {
        load();
    }

    def matchedTo(post_id: str) -> list[SuggestionView] {
        return [
            s
            for s in suggestions
            if s.my_post.id == post_id
        ];
    }

    <AppShell title="My posts" active="market">
        <MarketTabs active="/market/mine"/>
        {<Card>
            <p style={{"margin": "0"}}>You haven't posted anything yet.</p>
        </Card>
            if loaded and not posts
            else None}
        {[
            <Card key={p.id}>
                <div style={{"display": "flex", "gap": space("2")}}>
                    <Badge
                        kind={"progress" if p.status == "live" else "warning"}
                        label={p.status.capitalize()}
                    />
                    {<span style={{"color": color("sub"), "fontSize": "14px"}}>
                        {"Until " + p.expires_on}
                    </span>
                        if p.status == "live"
                        else None}
                </div>
                <PostSummary p={p}/>
                <strong style={{"fontSize": "14px"}}>
                    {f"Suggested to {len(matchedTo(p.id))} student(s)"}
                </strong>
                <ul style={{"margin": "0", "paddingLeft": "20px"}}>
                    {[
                        <li key={s.id}>
                            {s.other_post.title + ": " + "; ".join(s.reasons)}
                        </li> for s in matchedTo(p.id)
                    ]}
                </ul>
                <div style={{"display": "flex", "gap": space("2"), "flexWrap": "wrap"}}>
                    {<Button
                        label="Mark done"
                        variant="secondary"
                        onClick={lambda (e: MouseEvent) { done(p.id); }}
                    />
                        if p.status == "live"
                        else None}{<Button
                        label="Stop suggesting"
                        variant="text"
                        onClick={lambda (e: MouseEvent) { stop(p.id); }}
                    />
                        if p.status == "live"
                        else None}{<Button
                        label="Renew"
                        variant="secondary"
                        onClick={lambda (e: MouseEvent) { renew(p.id); }}
                    />
                        if p.status == "expired"
                        else None}
                </div>
            </Card> for p in posts
        ]}
    </AppShell>
}

impl MyPosts.load -> None {
    fresh_posts: list[PostView] = [];
    fresh_suggestions: list[SuggestionView] = [];
    fresh_posts = await list_my_posts();
    fresh_suggestions = await list_my_suggestions();
    posts = fresh_posts;
    suggestions = fresh_suggestions;
    loaded = True;
}

impl MyPosts.done(post_id: str) -> None {
    await mark_post_done(post_id);
    await load();
}

impl MyPosts.renew(post_id: str) -> None {
    await renew_post(post_id);
    await load();
}

impl MyPosts.stop(post_id: str) -> None {
    await stop_suggestions(post_id);
    await load();
}

def:pub ForYou -> JsxElement {
    has posts: list[PostView] = [],
        loaded: bool = False,
        picked: list[str] = [];

    def toggle(post_id: str) {
        picked = [
            x
            for x in picked
            if x != post_id
        ]
            if post_id in picked
            else (picked + [post_id])[-3:];
    }

    async def load -> None;

    can with entry {
        load();
    }

    <AppShell title="For you" active="market">
        <MarketTabs active="/market/feed"/>
        <p style={{"margin": "0", "color": color("sub")}}>
            Ranked by how well each post fits your own posts. Your matches tab has the best ones.
        </p>
        {<Card>
            <p style={{"margin": "0"}}>
                No live posts yet. Be the first: drop a message.
            </p>
        </Card>
            if loaded and not posts
            else None}
        {[
            <Card key={p.id}>
                <PostSummary p={p}/>
                <label
                    style={{
                        "display": "flex",
                        "gap": "8px",
                        "alignItems": "center",
                        "minHeight": "44px"
                    }}
                >
                    <input
                        type="checkbox"
                        checked={p.id in picked}
                        onChange={lambda (e: ChangeEvent) { toggle(p.id); }}
                    />
                    Compare
                </label>
            </Card> for p in posts
        ]}
        {(
            <Button
                label={f"Help me decide ({len(picked)})"}
                disabled={len(picked) < 2}
                full={True}
                onClick={lambda (e: MouseEvent) { go(
                    "/market/compare?ids=" + ",".join(picked)
                ); }}
            />
        )
            if posts
            else None}
    </AppShell>
}

impl ForYou.load -> None {
    fresh: list[PostView] = [];
    fresh = await for_you_feed();
    posts = fresh;
    loaded = True;
}
