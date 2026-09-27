"""ComponentSpec: a token-resolved description of one component variant from the Figma file."""

import from ui.tokens { FONTS, color, RADIUS, SIZE }

obj ComponentSpec {
    has name: str,
        family: str,
        variant: str = "default",
        description: str = "",
        props: dict[str, str] = {},
        styles: dict[str, str] = {},
        states: list[str] = [];
}

def make_spec(
    name: str,
    family: str,
    variant: str = "default",
    description: str = "",
    props: dict[str, str] = {},
    styles: dict[str, str] = {},
    states: list[str] = []
) -> ComponentSpec {
    resolved_styles: dict[str, str] = {
        "fontFamily": FONTS["sans"],
        "color": color("text"),
        "backgroundColor": color("card"),
        "borderColor": color("border"),
        "radius": f"{RADIUS['card']}px",
        "minTouchTarget": f"{SIZE['touch-min']}px"
    };
    for key in styles {
        resolved_styles[key] = styles[key];
    }
    return ComponentSpec(
        name=name,
        family=family,
        variant=variant,
        description=description,
        props=props,
        styles=resolved_styles,
        states=states
    );
}
