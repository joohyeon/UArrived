"""Figma building blocks: the pieces the UArrived Figma screens repeat (onboarding, landing plan,
task detail, challenges). Like base.jac, every value comes from ui/tokens.jac.

Status never rides on color alone: done rows say "Marked done by you" or carry a strikethrough
and a check, rewards carry the word "XP", and selection shows a filled radio or check mark.
"""

import from ui.tokens { color, space, text_style, RADIUS, SIZE, FONTS }

def:pub _px(n: int) -> str {
    return f"{n}px";
}

def:pub _text(name: str) -> dict[str, str] {
    t = text_style(name);
    return {
        "fontFamily": t["fontFamily"],
        "fontSize": t["fontSize"],
        "fontWeight": t["fontWeight"],
        "lineHeight": t["lineHeight"]
    };
}

"""Uppercase region name, e.g. WHY YOU NEED IT. `tone` is a color token."""
def:pub SectionLabel(label: str, tone: str = "sub") -> JsxElement {
    style = _text("label");
    style["color"] = color(tone);
    style["textTransform"] = "uppercase";
    style["letterSpacing"] = "0.04em";
    style["margin"] = "0";
    <p style={style}>{label}</p>
}

"""Onboarding question: eyebrow (STEP 2), Outfit title, optional subtitle."""
def:pub QuestionBlock(eyebrow: str, title: str, subtitle: str = "") -> JsxElement {
    eyebrow_style = _text("eyebrow");
    eyebrow_style["color"] = color("action");
    eyebrow_style["textTransform"] = "uppercase";
    eyebrow_style["letterSpacing"] = "0.15em";
    eyebrow_style["margin"] = "0";
    title_style = _text("screen-title");
    title_style["color"] = color("text");
    title_style["margin"] = "0";
    sub_style = _text("small");
    sub_style["color"] = color("sub");
    sub_style["margin"] = "0";
    <div style={{"display": "flex", "flexDirection": "column", "gap": space("2")}}>
        <p style={eyebrow_style}>{eyebrow}</p>
        <h2 style={title_style}>{title}</h2>
        {<p style={sub_style}>{subtitle}</p> if subtitle else None}
    </div>
}

"""The onboarding step indicator: the current step is a 24px bar, the others 6px dots."""
def:pub ProgressDots(steps: int, current: int) -> JsxElement {
    <div
        role="img"
        aria-label={f"Step {current + 1} of {steps}"}
        style={{"display": "flex", "gap": space("1"), "alignItems": "center"}}
    >
        {[
            <span
                key={str(i)}
                style={{
                    "width": "24px" if i == current else "6px",
                    "height": "6px",
                    "borderRadius": "3px",
                    "background": color("action") if i == current else color("border")
                }}
            /> for i in range(steps)
        ]}
    </div>
}

"""A labeled progress bar, e.g. "3 of 6 essentials done" with 50% on the right."""
def:pub ProgressBar(done: int, total: int, label: str = "") -> JsxElement {
    pct = 0 if total <= 0 else int(done * 100 / total);
    meta = _text("meta");
    meta["color"] = color("text-2");
    pct_style = _text("meta");
    pct_style["color"] = color("action");
    <div style={{"display": "flex", "flexDirection": "column", "gap": space("2")}}>
        {(
            <div style={{"display": "flex", "justifyContent": "space-between"}}>
                <span style={meta}>{label}</span>
                <span style={pct_style}>{f"{pct}%"}</span>
            </div>
        )
            if label
            else None}
        <div
            role="progressbar"
            aria-valuenow={pct}
            aria-valuemin={0}
            aria-valuemax={100}
            aria-label={label or "Progress"}
            style={{
                "height": "8px",
                "borderRadius": _px(RADIUS["pill"]),
                "background": color("border"),
                "overflow": "hidden"
            }}
        >
            <div
                style={{
                    "width": f"{pct}%",
                    "height": "100%",
                    "borderRadius": _px(RADIUS["pill"]),
                    "background": color("action")
                }}
            />
        </div>
    </div>
}

"""A radio option card (housing choice): title, description, indigo border when selected."""
def:pub SelectableCard(
    title: str,
    description: str = "",
    selected: bool = False,
    onSelect: Callable[[], None] | None = None
) -> JsxElement {
    def handle(e: MouseEvent) {
        if onSelect is not None {
            onSelect();
        }
    }
    title_style = _text("card-title");
    title_style["color"] = color("text");
    desc_style = _text("caption");
    desc_style["color"] = color("sub");
    <button
        type="button"
        role="radio"
        aria-checked={selected}
        onClick={handle}
        style={{
            "display": "flex",
            "alignItems": "center",
            "gap": space("4"),
            "width": "100%",
            "minHeight": _px(SIZE["touch-min"]),
            "padding": space("4"),
            "textAlign": "left",
            "background": color("card"),
            "border": ("2px solid " + color("action"))
                if selected
                else ("1px solid " + color("border")),
            "borderRadius": _px(RADIUS["card"]),
            "boxShadow": "0 2px 8px " + color("shadow"),
            "cursor": "pointer"
        }}
    >
        <span
            aria-hidden="true"
            style={{
                "flexShrink": "0",
                "width": "20px",
                "height": "20px",
                "boxSizing": "border-box",
                "borderRadius": "50%",
                "border": "2px solid "
                    + (color("action") if selected else color("border-strong")),
                "background": color("card"),
                "boxShadow": (
                    "inset 0 0 0 3px "
                    + color("card")
                    + ", inset 0 0 0 10px "
                    + color("action")
                )
                    if selected
                    else "none"
            }}
        />
        <span style={{"display": "flex", "flexDirection": "column", "gap": space("1")}}>
            <span style={title_style}>{title}</span>
            {<span style={desc_style}>{description}</span> if description else None}
        </span>
    </button>
}

"""A big-glyph choice tile (中文 / EN language choice)."""
def:pub OptionTile(
    glyph: str,
    title: str,
    caption: str = "",
    selected: bool = False,
    onSelect: Callable[[], None] | None = None
) -> JsxElement {
    def handle(e: MouseEvent) {
        if onSelect is not None {
            onSelect();
        }
    }
    title_style = _text("card-title");
    title_style["color"] = color("text");
    title_style["fontWeight"] = "700";
    caption_style = _text("caption");
    caption_style["color"] = color("sub");
    <button
        type="button"
        role="radio"
        aria-checked={selected}
        onClick={handle}
        style={{
            "flex": "1 1 0",
            "display": "flex",
            "flexDirection": "column",
            "alignItems": "center",
            "gap": space("2"),
            "padding": space("6") + " " + space("3"),
            "background": color("card"),
            "border": ("2px solid " + color("action"))
                if selected
                else ("1px solid " + color("border")),
            "borderRadius": _px(RADIUS["card"]),
            "cursor": "pointer"
        }}
    >
        <span
            aria-hidden="true"
            style={{
                "width": "40px",
                "height": "40px",
                "borderRadius": "50%",
                "display": "flex",
                "alignItems": "center",
                "justifyContent": "center",
                "background": color("action-soft") if selected else color("panel"),
                "color": color("action") if selected else color("text-2"),
                "fontFamily": FONTS["display"],
                "fontWeight": "700",
                "fontSize": "16px"
            }}
        >
            {glyph}
        </span>
        <span style={title_style}>{title}</span>
        {<span style={caption_style}>{caption}</span> if caption else None}
    </button>
}

"""A checkbox row: 24px indigo check, label (struck through when done), optional XP reward."""
def:pub ChecklistRow(
    label: str,
    checked: bool = False,
    onToggle: Callable[[], None] | None = None,
    reward: str = ""
) -> JsxElement {
    def handle(e: MouseEvent) {
        if onToggle is not None {
            onToggle();
        }
    }
    label_style = _text("body");
    label_style["fontSize"] = "15px";
    label_style["color"] = color("text-2") if checked else color("text");
    label_style["flexGrow"] = "1";
    label_style["textDecoration"] = "line-through" if checked else "none";
    <button
        type="button"
        role="checkbox"
        aria-checked={checked}
        onClick={handle}
        style={{
            "display": "flex",
            "alignItems": "center",
            "gap": space("4"),
            "width": "100%",
            "minHeight": "56px",
            "padding": "0 " + space("4"),
            "textAlign": "left",
            "background": color("card"),
            "border": "1px solid "
                + (color("action-line") if checked else color("border")),
            "borderRadius": _px(RADIUS["card"]),
            "cursor": "pointer"
        }}
    >
        <span
            aria-hidden="true"
            style={{
                "flexShrink": "0",
                "width": "24px",
                "height": "24px",
                "boxSizing": "border-box",
                "borderRadius": _px(RADIUS["check"]),
                "border": "2px solid "
                    + (color("action") if checked else color("border-strong")),
                "background": color("action") if checked else color("card"),
                "color": color("on-action"),
                "display": "flex",
                "alignItems": "center",
                "justifyContent": "center",
                "fontSize": "14px",
                "fontWeight": "700"
            }}
        >
            {"✓" if checked else ""}
        </span>
        <span style={label_style}>{label}</span>
        {<RewardPill label={reward}/> if reward else None}
    </button>
}

"""An XP reward label such as "+50 XP": text only, no emoji carrying meaning."""
def:pub RewardPill(label: str) -> JsxElement {
    style = _text("meta");
    style["color"] = color("progress");
    style["whiteSpace"] = "nowrap";
    <span style={style}>{label}</span>
}

"""Initials avatar, e.g. UM."""
def:pub Avatar(initials: str) -> JsxElement {
    <span
        aria-hidden="true"
        style={{
            "width": "40px",
            "height": "40px",
            "flexShrink": "0",
            "borderRadius": "50%",
            "display": "inline-flex",
            "alignItems": "center",
            "justifyContent": "center",
            "background": color("action-soft"),
            "color": color("action"),
            "fontFamily": FONTS["sans"],
            "fontWeight": "700",
            "fontSize": "14px"
        }}
    >
        {initials}
    </span>
}

"""A labeled card. `plain` (WHY YOU NEED IT) or `advice` (ADVICE FROM OLDER STUDENTS, amber)."""
def:pub InfoCard(
    label: str, variant: str = "plain", children: any = None
) -> JsxElement {
    advice = variant == "advice";
    body = _text("small");
    body["color"] = color("text-2");
    body["display"] = "flex";
    body["flexDirection"] = "column";
    body["gap"] = space("2");
    <section
        style={{
            "background": color("warning-bg") if advice else color("card"),
            "border": "1px solid " + (color("accent") if advice else color("border")),
            "borderRadius": _px(RADIUS["card"]),
            "padding": space("4"),
            "display": "flex",
            "flexDirection": "column",
            "gap": space("2")
        }}
    >
        <SectionLabel label={label} tone={"warning" if advice else "sub"}/>
        <div style={body}>{children}</div>
    </section>
}

"""One stop in the landing plan: status mark, title, meta line and a duration badge.
`status` is done (check, struck through) or next (indigo dot)."""
def:pub TimelineItem(
    title: str, meta: str = "", duration: str = "", status: str = "next"
) -> JsxElement {
    done = status == "done";
    title_style = _text("card-title");
    title_style["color"] = color("sub") if done else color("text");
    title_style["textDecoration"] = "line-through" if done else "none";
    meta_style = _text("small");
    meta_style["color"] = color("sub");
    badge_style = _text("badge");
    badge_style["padding"] = "3px 8px";
    badge_style["borderRadius"] = _px(RADIUS["sm"]);
    badge_style["background"] = color("panel") if done else color("action-soft");
    badge_style["color"] = color("sub") if done else color("action");
    badge_style["whiteSpace"] = "nowrap";
    <div
        style={{
            "display": "flex",
            "gap": space("3"),
            "alignItems": "flex-start",
            "padding": space("2") + " 0"
        }}
    >
        <span
            aria-label={"Done" if done else "Up next"}
            role="img"
            style={{
                "flexShrink": "0",
                "width": "24px",
                "height": "24px",
                "borderRadius": "50%",
                "display": "flex",
                "alignItems": "center",
                "justifyContent": "center",
                "background": color("progress-bg") if done else color("action-soft"),
                "color": color("progress") if done else color("action"),
                "fontSize": "13px",
                "fontWeight": "700"
            }}
        >
            {"✓" if done else "●"}
        </span>
        <div
            style={{
                "flexGrow": "1",
                "display": "flex",
                "flexDirection": "column",
                "gap": space("1")
            }}
        >
            <span style={title_style}>{title}</span>
            {<span style={meta_style}>{meta}</span> if meta else None}
        </div>
        {(<span style={badge_style}>{duration}</span>) if duration else None}
    </div>
}
