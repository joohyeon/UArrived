"""/journey/ask?id=…: ask the AI guide about one task. Every answer is labeled AI-generated, with a
reminder to confirm on the official page; the chat lives only on this screen (not stored)."""

import from ui.tokens { color, space, text_style, RADIUS }
import from ui.components.base { AppShell, Button, Badge, Field }
import from ui.components.blocks { Chip, TopBar }
import from journey.guide { ask_about_task, GuideReply }
import from journey.screens.common { query_param }

glob SUGGESTIONS: list[str] = [
         "What documents do I need to bring?",
         "How do I get there from Central Campus?",
         "How long will this take?"
     ];

def:pub Bubble(role: str, text: str, failed: bool = False) -> JsxElement {
    mine = role == "user";
    <div
        style={{
            ** text_style("body"),
            "alignSelf": "flex-end" if mine else "flex-start",
            "maxWidth": "85%",
            "padding": space("3") + " " + space("4"),
            "borderRadius": f"{RADIUS['card']}px",
            "background": color("action")
                if mine
                else (color("warning-bg") if failed else color("card")),
            "color": color("on-action") if mine else color("text"),
            "border": "0" if mine else ("1px solid " + color("border")),
            "whiteSpace": "pre-wrap"
        }}
    >
        {text}
    </div>
}

def:pub AskGuide -> JsxElement {
    has tid: str = "",
        log: list[dict[str, any]] = [],
        draft: str = "",
        sending: bool = False;

    can with entry {
        tid = query_param("id");
    }

    async def send(text: str) -> None;

    <AppShell title="Ask the AI guide" active="journey">
        <TopBar back_href={"/journey/task?id=" + tid} back_label="Back to the task"/>
        <Badge kind="ai" label="AI-generated answers"/>
        <div style={{"display": "flex", "flexDirection": "column", "gap": space("2")}}>
            <Bubble
                role="guide"
                text="Hi! Ask me anything about this task: documents, directions, hours, costs, or what happens next."
            />
            {[
                <Bubble
                    key={str(i)}
                    role={m["role"]}
                    text={m["text"]}
                    failed={m["failed"]}
                /> for (i, m) in enumerate(log)
            ]}
            {<Bubble role="guide" text="The guide is typing…"/> if sending else None}
        </div>
        {(
            <div style={{"display": "flex", "flexWrap": "wrap", "gap": space("2")}}>
                {[
                    <Chip key={q} label={q} onSelect={lambda { send(q); }}/>
                    for q in SUGGESTIONS
                ]}
            </div>
        )
            if len(log) == 0
            else None}
        <form
            onSubmit={lambda (e: FormEvent) {
                e.preventDefault();
                send(draft);
            }}
            style={{"display": "flex", "flexDirection": "column", "gap": space("2")}}
        >
            <Field
                label="Your question"
                value={draft}
                onChange={lambda (v: str) { draft = v; }}
                placeholder="Type your question"
            />
            <Button
                label="Send"
                button_type="submit"
                full={True}
                disabled={sending or draft.strip() == ""}
            />
        </form>
        <p style={{** text_style("caption"), "color": color("sub"), "margin": "0"}}>
            AI answers can be wrong. Confirm important details on the official page or with the International Center.
        </p>
    </AppShell>
}

impl AskGuide.send(text: str) -> None {
    question = text.strip();
    if question == "" or sending {
        return;
    }
    history = [{"role": m["role"], "text": m["text"]} for m in log];
    asked = log + [{"role": "user", "text": question, "failed": False}];
    log = asked;
    draft = "";
    sending = True;
    reply: GuideReply | None = None;
    try {
        reply = await ask_about_task(tid, question, history);
    } except Exception as err {
        reply = None;
    }
    text_out = reply.text
        if reply is not None
        else "Could not reach the AI guide. Please try again.";
    ok = reply is not None and reply.ok;
    log = asked + [{"role": "guide", "text": text_out, "failed": not ok}];
    sending = False;
}
