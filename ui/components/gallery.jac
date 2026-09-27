"""/ui: every base component on one page, for design review and screenshots (issue #3)."""

import from ui.components.base { AppShell, Button, Card, Badge, Field }
import from ui.components.blocks {
    SectionLabel,
    QuestionBlock,
    ProgressDots,
    ProgressBar,
    SelectableCard,
    OptionTile,
    ChecklistRow,
    RewardPill,
    Avatar,
    InfoCard,
    TimelineItem
}

def:pub Gallery -> JsxElement {
    has name: str = "",
        note: str = "",
        clicks: int = 0,
        housing: str = "south",
        language: str = "zh",
        phone: bool = False,
        email: bool = True;

    <AppShell title="Components" active="market">
        <Card>
            <h2 style={{"margin": "0"}}>Plan your ride from DTW</h2>
            <div style={{"display": "flex", "gap": "8px", "flexWrap": "wrap"}}>
                <Badge kind="official" label="Official"/>
                <Badge kind="ai" label="AI-generated"/>
                <Badge kind="progress" label="Marked done by you"/>
                <Badge kind="warning" label="Seller says"/>
                <Badge kind="action" label="NEXT ESSENTIAL"/>
                <Badge kind="neutral" label="5 min"/>
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
        <Card>
            <div
                style={{
                    "display": "flex",
                    "justifyContent": "space-between",
                    "alignItems": "center"
                }}
            >
                <ProgressDots steps={4} current={1}/>
                <Avatar initials="UM"/>
            </div>
            <QuestionBlock eyebrow="Step 2" title="Where will you live?"/>
            <SelectableCard
                title="Bursley Hall (North Campus)"
                description="Freshman dorm, very green, near Engineering"
                selected={housing == "bursley"}
                onSelect={lambda { housing = "bursley"; }}
            />
            <SelectableCard
                title="South Quad (Central Campus)"
                description="Heart of Central, excellent dining hall"
                selected={housing == "south"}
                onSelect={lambda { housing = "south"; }}
            />
            <div style={{"display": "flex", "gap": "12px"}}>
                <OptionTile
                    glyph="中"
                    title="中文"
                    caption="Default bilingual view"
                    selected={language == "zh"}
                    onSelect={lambda { language = "zh"; }}
                />
                <OptionTile
                    glyph="EN"
                    title="English"
                    caption="English-only UI"
                    selected={language == "en"}
                    onSelect={lambda { language = "en"; }}
                />
            </div>
            <ChecklistRow
                label="Activated U-Mich email"
                checked={email}
                onToggle={lambda { email = not email; }}
            />
            <ChecklistRow
                label="Passport"
                checked={phone}
                reward="+5 XP"
                onToggle={lambda { phone = not phone; }}
            />
        </Card>
        <Card>
            <ProgressBar done={3} total={6} label="3 of 6 essentials done"/>
            <TimelineItem
                title="U-Mich Email Activation"
                meta="Finished pre-arrival"
                duration="5 min"
                status="done"
            />
            <TimelineItem
                title="Get a U.S. Phone Number"
                meta="Suggest: Day 1 • T-Mobile or eSIM"
                duration="20 min"
            />
            <div style={{"display": "flex", "gap": "8px", "alignItems": "center"}}>
                <SectionLabel label="Trip rewards"/>
                <RewardPill label="+50 XP"/>
            </div>
        </Card>
        <InfoCard label="Why you need it">
            <span>
                To pay tuition online, pay rent automatically, and avoid heavy 3% international card fees.
            </span>
        </InfoCard>
        <InfoCard label="Advice from older students" variant="advice">
            <span>
                Get your US phone first. Banks cannot send verification codes to Chinese numbers.
            </span>
        </InfoCard>
    </AppShell>
}
