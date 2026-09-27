"""Moderator queue (U11, R17): open reports, hide the post, resolve. Only moderators get data;
everyone else sees an empty queue."""

import from ui.tokens { color, space }
import from ui.components.base { AppShell, Button, Card }
import from market.moderation {
    moderation_queue,
    hide_post,
    resolve_report,
    ReportView
}

def:pub Moderate -> JsxElement {
    has reports: list[ReportView] = [],
        loaded: bool = False;

    async def load -> None;
    async def hideIt(post_id: str, report_id: str) -> None;
    async def resolveIt(report_id: str) -> None;

    can with entry {
        load();
    }

    <AppShell title="Reports" active="market">
        {<Card>
            <p style={{"margin": "0"}}>No open reports (or you aren't a moderator).</p>
        </Card>
            if loaded and not reports
            else None}{[
            <Card key={r.id}>
                <strong>{r.post_title}</strong>
                <span style={{"color": color("sub"), "fontSize": "14px"}}>
                    {r.created_at + (" · from a chat" if r.chat_id else "")}
                </span>
                <p style={{"margin": "0"}}>{r.reason}</p>
                <div style={{"display": "flex", "gap": space("2")}}>
                    <Button
                        label="Hide post"
                        onClick={lambda (e: MouseEvent) { hideIt(r.post_id, r.id); }}
                    />
                    <Button
                        label="Resolve"
                        variant="secondary"
                        onClick={lambda (e: MouseEvent) { resolveIt(r.id); }}
                    />
                </div>
            </Card> for r in reports
        ]}
    </AppShell>
}

impl Moderate.load -> None {
    fresh: list[ReportView] = [];
    fresh = await moderation_queue();
    reports = fresh;
    loaded = True;
}

impl Moderate.hideIt(post_id: str, report_id: str) -> None {
    await hide_post(post_id);
    await resolve_report(report_id);
    await load();
}

impl Moderate.resolveIt(report_id: str) -> None {
    await resolve_report(report_id);
    await load();
}
