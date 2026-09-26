"""/ui: every base component on one page, for design review and screenshots (issue #3)."""

import from ui.components.base { AppShell, Button, Card, Badge, Field }

def:pub Gallery -> JsxElement {
    has name: str = "",
        note: str = "",
        clicks: int = 0;

    <AppShell title="Components" active="market">
        <Card>
            <h2 style={{"margin": "0"}}>Plan your ride from DTW</h2>
            <div style={{"display": "flex", "gap": "8px", "flexWrap": "wrap"}}>
                <Badge kind="official" label="Official"/>
                <Badge kind="ai" label="AI-generated"/>
                <Badge kind="progress" label="Marked done by you"/>
                <Badge kind="warning" label="Seller says"/>
            </div>
            <Field
                label="Your name"
                value={name}
                onChange={lambda (v: str) { name = v; }}
                hint="Shown on your posts"
            />
            <Field
                label="Message"
                value={note}
                multiline={True}
                onChange={lambda (v: str) { note = v; }}
            />
            <div style={{"display": "flex", "gap": "8px", "flexWrap": "wrap"}}>
                <Button
                    label={f"Primary ({clicks})"}
                    onClick={lambda (e: MouseEvent) { clicks = clicks + 1; }}
                />
                <Button label="Secondary" variant="secondary"/>
                <Button label="Text" variant="text"/>
                <Button label="Disabled" disabled={True}/>
            </div>
        </Card>
    </AppShell>
}
