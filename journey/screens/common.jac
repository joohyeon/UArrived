"""Shared pieces of the journey screens: the Tasks tab strip, URL helpers, the status badge and the
task map. journey/ never imports market/, so the small URL helpers live here too.

Events used to be a second tab here, but it's its own bottom-nav tab now (U4, plan
2026-09-27-003), so the strip is just Tasks -- kept as a strip (not a bare heading) in case a
Journey sub-page is added later."""

import from ui.tokens { color, space, text_style, SIZE }
import from ui.components.base { Badge }
import from ui.components.blocks { TabStrip }
import from ui.components.map { MapCanvas }
import from journey.constants { STATUS_LABELS, ANN_ARBOR_BOUNDS, CAMPUS_CENTER }
import from journey.walkers { TaskView }

glob JOURNEY_TABS: list[tuple[str, str]] = [("/journey", "Tasks")];

"""A query-string parameter from the current URL, or ""."""
def:pub query_param(name: str) -> str {
    params = new(URLSearchParams, window.location.search);  # jac:ignore[E1053]
    return params.get(name) or "";  # jac:ignore[E1032,E1002]
}

"""Full-page client navigation (a hard redirect, not a client-side route change)."""
def:pub go(path: str) {
    window.location.assign(path);  # jac:ignore[E1032,W2001]
}

def:pub JourneyTabs(active: str) -> JsxElement {
    <TabStrip items={JOURNEY_TABS} active={active} label="Journey"/>
}

"""The status chip for a task: done is always "Marked done by you", never official-sounding."""
def:pub StatusBadge(status: str) -> JsxElement {
    kind = "progress"
        if status == "done"
        else ("action" if status == "started" else "neutral");
    <Badge kind={kind} label={STATUS_LABELS.get(status, status)}/>
}

"""The tasks on the Ann Arbor map: one pin per place that has coordinates. `center` is where the
map starts (world px at zoom 18); the campus when empty."""
def:pub TaskMap(
    views: list[TaskView],
    tx: Callable[[str], str],
    center: list[float],
    height: int = 460,
    zoom: int = 16,
    max_width: int = 1168
) -> JsxElement {
    pins: list[dict[str, any]] = [];
    for v in views {
        state = "done"
            if v.status == "done"
            else ("active" if v.task.required else "optional");
        many = len(v.task.places) > 1;
        for (i, p) in enumerate(v.task.places) {
            if p.lat != 0.0 {
                pins.append(
                    {
                        "key": v.task.tid + "-" + str(i),
                        "wx": p.wx,
                        "wy": p.wy,
                        "label": tx(v.task.short)
                            + ((": " + p.label) if many and p.label else ""),
                        "href": "/journey/task?id=" + v.task.tid,
                        "state": state
                    }
                );
            }
        }
    }
    <MapCanvas
        pins={pins}
        center={center if len(center) == 2 else CAMPUS_CENTER}
        bounds={ANN_ARBOR_BOUNDS}
        start_zoom={zoom}
        height={height}
        max_width={max_width}
    />
}

"""Small print: where the task information comes from and when it was checked."""
def:pub SourceNote(verified: str) -> JsxElement {
    style = text_style("caption");
    <p style={{** style, "color": color("sub"), "margin": "0"}}>
        {("Official information checked on " + verified + ". " if verified else "")
            + "Hours and rules change: re-check the official page on the day you go."}
    </p>
}
