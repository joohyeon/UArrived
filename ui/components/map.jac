"""Map building blocks (Figma: MapCanvas, MapPin): a pannable, zoomable OpenStreetMap view with
labelled pins. Pure presentation: callers pass pins already projected to Web Mercator world pixels
at zoom 18 (`wx`, `wy`; the server does the trig), so no map library or API key is needed.

A pin is a dict: {"key", "wx", "wy", "label", "href", "state"} plus an optional "count".
`state` is done (progress green, check mark), active (indigo), optional (stone) or event (indigo,
with the count). Every pin is a link with its label in words; state never rides on color alone.
Pins at the same spot stack upwards so none hides another.
"""

import from ui.tokens { color, space, text_style, RADIUS, SIZE, FONTS }

glob TILE: int = 256,
     BASE_ZOOM: int = 18,
     MIN_ZOOM: int = 12,
     MAX_ZOOM: int = 18,
     TILE_URL: str = "https://tile.openstreetmap.org/";

def:pub _pin_color(state: str) -> str {
    if state == "done" {
        return color("progress");
    }
    if state == "optional" {
        return color("sub");
    }
    return color("action");
}

"""One labelled pin, positioned by its canvas pixel (`left`, `top`) = the point it marks."""
def:pub MapPin(
    label: str, href: str, state: str, left: float, top: float, count: int = 0
) -> JsxElement {
    tone = _pin_color(state);
    glyph = "✓" if state == "done" else (str(count) if count > 0 else "");
    <a
        href={href}
        aria-label={label + (" (done)" if state == "done" else "")}
        style={{
            "position": "absolute",
            "left": f"{left}px",
            "top": f"{top}px",
            "transform": "translate(-14px, -50%)",
            "display": "flex",
            "alignItems": "center",
            "gap": space("1"),
            "minHeight": f"{SIZE['touch-min']}px",
            "textDecoration": "none",
            "zIndex": "2"
        }}
    >
        <span
            aria-hidden="true"
            style={{
                "width": "28px",
                "height": "28px",
                "flexShrink": "0",
                "boxSizing": "border-box",
                "borderRadius": "50%",
                "border": "3px solid " + color("card"),
                "background": tone,
                "color": color("on-action"),
                "display": "flex",
                "alignItems": "center",
                "justifyContent": "center",
                "fontFamily": FONTS["sans"],
                "fontSize": "12px",
                "fontWeight": "700",
                "boxShadow": "0 1px 4px " + color("scrim")
            }}
        >
            {glyph}
        </span>
        <span
            style={{
                "maxWidth": "160px",
                "overflow": "hidden",
                "textOverflow": "ellipsis",
                "whiteSpace": "nowrap",
                "padding": "2px 8px",
                "borderRadius": f"{RADIUS['sm']}px",
                "background": color("card"),
                "border": "1px solid " + tone,
                "color": color("text"),
                "fontFamily": FONTS["sans"],
                "fontSize": text_style("caption")["fontSize"],
                "fontWeight": "600"
            }}
        >
            {label}
        </span>
    </a>
}

"""A round +/- style map control (44px)."""
def:pub MapControl(label: str, text: str, onPress: Callable[[], None]) -> JsxElement {
    <button
        type="button"
        aria-label={label}
        onClick={lambda (e: MouseEvent) { onPress(); }}
        style={{
            "minWidth": f"{SIZE['touch-min']}px",
            "minHeight": f"{SIZE['touch-min']}px",
            "padding": "0 " + space("3"),
            "borderRadius": f"{RADIUS['field']}px",
            "border": "1px solid " + color("border"),
            "background": color("card"),
            "color": color("text"),
            "fontFamily": FONTS["sans"],
            "fontSize": "16px",
            "fontWeight": "700",
            "boxShadow": "0 1px 4px " + color("shadow"),
            "cursor": "pointer"
        }}
    >
        {text}
    </button>
}

"""The map. `center` is the starting view (world px at zoom 18); `bounds` (min x, min y, max x,
max y) keeps panning inside an area, or pass an empty list for none. `max_width` is the page
column it sits in (688 in a default AppShell, 1168 in a wide one). Drag to pan; +/- to zoom."""
def:pub MapCanvas(
    pins: list[dict[str, any]],
    center: list[float],
    bounds: list[float],
    start_zoom: int = 16,
    height: int = 420,
    max_width: int = 1168
) -> JsxElement {
    has cx: float = 0.0,
        cy: float = 0.0,
        zoom: int = 16,
        width: float = 360.0,
        dragging: bool = False,
        lastX: float = 0.0,
        lastY: float = 0.0,
        ready: bool = False;

    can with entry {
        cx = center[0];
        cy = center[1];
        zoom = start_zoom;
        # The page column: the viewport less the 16px gutters, up to the shell's content width.
        width = min(float(window.innerWidth) - 32, float(max_width));  # jac:ignore[E1032,W2001]
        ready = True;
    }

    def clamp(x: float, y: float) -> list[float] {
        if len(bounds) < 4 {
            return [x, y];
        }
        return [min(max(x, bounds[0]), bounds[2]), min(max(y, bounds[1]), bounds[3])];
    }

    def down(e: PointerEvent) {
        dragging = True;
        lastX = e.clientX;
        lastY = e.clientY;
    }

    def move(e: PointerEvent) {
        if not dragging {
            return;
        }
        s = 2 ** (BASE_ZOOM - zoom);
        c = clamp(cx - (e.clientX - lastX) * s, cy - (e.clientY - lastY) * s);
        cx = c[0];
        cy = c[1];
        lastX = e.clientX;
        lastY = e.clientY;
    }

    def up(e: PointerEvent) {
        dragging = False;
    }

    def zoomBy(step: int) {
        zoom = min(MAX_ZOOM, max(MIN_ZOOM, zoom + step));
    }

    def recenter {
        cx = center[0];
        cy = center[1];
        zoom = start_zoom;
    }

    scale = 2 ** (BASE_ZOOM - zoom);
    ox = cx / scale - width / 2;
    oy = cy / scale - height / 2;
    tiles: list[dict[str, any]] = [];
    last = 2 ** zoom - 1;
    tx0 = int(Math.floor(ox / TILE));  # jac:ignore[W2001]
    tx1 = int(Math.floor((ox + width) / TILE));  # jac:ignore[W2001]
    ty0 = int(Math.floor(oy / TILE));  # jac:ignore[W2001]
    ty1 = int(Math.floor((oy + height) / TILE));  # jac:ignore[W2001]
    for tx in range(tx0, tx1 + 1) {
        for ty in range(ty0, ty1 + 1) {
            if tx >= 0 and ty >= 0 and tx <= last and ty <= last {
                tiles.append(
                    {
                        "key": f"{zoom}/{tx}/{ty}",
                        "left": tx * TILE - ox,
                        "top": ty * TILE - oy
                    }
                );
            }
        }
    }
    stacked: dict[str, int] = {};
    placed: list[dict[str, any]] = [];
    for p in pins {
        left = p["wx"] / scale - ox;
        top = p["wy"] / scale - oy;
        spot = f"{Math.round(left / 8)},{Math.round(top / 8)}";  # jac:ignore[W2001]
        n = stacked.get(spot, 0);
        stacked[spot] = n + 1;
        if left > -40 and left < width + 40 and top > -40 and top < height + 40 {
            placed.append({"pin": p, "left": left, "top": top - n * 34});
        }
    }

    <div
        style={{
            "position": "relative",
            "height": f"{height}px",
            "overflow": "hidden",
            "borderRadius": f"{RADIUS['card']}px",
            "border": "1px solid " + color("border"),
            "background": color("panel"),
            "touchAction": "none",
            "userSelect": "none",
            "cursor": "grabbing" if dragging else "grab"
        }}
        onPointerDown={down}
        onPointerMove={move}
        onPointerUp={up}
        onPointerLeave={up}
    >
        {[
            <img
                key={t["key"]}
                src={TILE_URL + t["key"] + ".png"}
                alt=""
                draggable={False}
                style={{
                    "position": "absolute",
                    "left": f"{t['left']}px",
                    "top": f"{t['top']}px",
                    "width": f"{TILE}px",
                    "height": f"{TILE}px",
                    "pointerEvents": "none"
                }}
            /> for t in tiles
        ]
            if ready
            else None}
        {[
            <MapPin
                key={x["pin"]["key"]}
                label={x["pin"]["label"]}
                href={x["pin"]["href"]}
                state={x["pin"]["state"]}
                count={x["pin"].get("count", 0)}
                left={x["left"]}
                top={x["top"]}
            /> for x in placed
        ]
            if ready
            else None}
        <div
            style={{
                "position": "absolute",
                "right": space("2"),
                "top": space("2"),
                "display": "flex",
                "flexDirection": "column",
                "gap": space("1"),
                "zIndex": "3"
            }}
        >
            <MapControl label="Zoom in" text="+" onPress={lambda { zoomBy(1); }}/>
            <MapControl label="Zoom out" text="−" onPress={lambda { zoomBy(-1); }}/>
            <MapControl label="Back to campus" text="⌂" onPress={recenter}/>
        </div>
        <span
            style={{
                "position": "absolute",
                "right": "0",
                "bottom": "0",
                "padding": "1px 6px",
                "background": color("card"),
                "color": color("sub"),
                "fontSize": "11px",
                "zIndex": "3"
            }}
        >
            © OpenStreetMap contributors
        </span>
    </div>
}
