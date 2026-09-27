---
date: 2026-09-27
topic: personalized-events-tab
status: ready-for-planning
---

# Personalized Events tab

## Summary

Promote the campus events feed to its own bottom-nav tab in place of the currently-dead Housing
slot, keep its data current with a scheduled refresh from U-M's public events feed, and make it feel
personal: a one-time onboarding interest pick drives a "today's pick" hero and "for you" tags on the
existing day-grouped list, alongside a lightweight "I'm interested" social-proof count.

---

## Problem Frame

`journey/screens/events.jac` already has a working events feed — category filters, a free-only
toggle, list/map view — nested under Journey's sub-tabs. It's fed by `journey/umich_event_data`, a
1.1MB static export taken once from U-M's Happening events platform, with no refresh mechanism:
left alone, it will silently go stale.

Separately, `ui/components/base.jac` declares a "Housing" bottom-nav tab that no screen has ever
routed to — housing lives only as a category inside `market/`. A navigation review flagged this as
dead nav real estate, and the previously-recommended "give Housing its own screen" direction has
been dropped in favor of reclaiming that slot for Events.

The events feed itself is also undifferentiated: every student sees the exact identical list, with
no notion of what they personally care about. For a newly arrived international student with no
other trusted source for campus events, that's a missed chance to make the app feel like a live,
exciting part of settling in rather than a plain reference list.

---

## Requirements

**Refresh pipeline**
- R1. `journey/events.jac`'s event data is refreshable on a recurring schedule from a live source,
  without needing any change to the parsing/caching logic in `all_events()` (its mtime-based cache
  should pick up a refreshed file automatically).
- R2. The refresh pulls from events.umich.edu's public Localist-powered JSON feed (documented at
  events.umich.edu/feeds), not a manual or ad hoc export.

**Navigation**
- R3. The bottom nav's "Housing" entry (`NAV_ITEMS` in `ui/components/base.jac`) is replaced by an
  "Events" entry routed to the events feed.
- R4. Housing is not given any dedicated screen; it continues to live only as a category inside
  `market/`, unchanged.

**Personalization**
- R5. A student picks a small set of interest categories once, using the same taxonomy events
  already use (Learning, Arts, Sports, Careers, Social, Well-being, Tours, Community — from
  `journey/events.jac`'s `CATEGORY_RULES`).
- R6. Matching a student's picked interests against event categories is deterministic tag matching —
  no AI/LLM ranking — consistent with the project's rule that non-AI logic stays deterministic.
- R7. The Events screen leads with a single hero: the soonest upcoming event that matches the
  student's interests. When no upcoming event matches any picked interest, the hero falls back to
  the soonest upcoming event overall, shown without a "for you" tag.
- R8. Below the hero, events stay grouped by day (Today / Tomorrow / This week / Later) as a list,
  with a "for you" tag on entries that match the student's interests.
- R9. Existing category/free filters and the list/map toggle in `journey/screens/events.jac` are
  preserved unchanged.

**Excitement additions**
- R10. Each event, hero or list, shows an "N students interested" count.
- R11. A student can mark "I'm interested" on the hero event at minimum; doing so increments that
  event's count. This is a throwaway tally — it has no memory of which student clicked, and does not
  need to be reversible or shown back to that student elsewhere.

---

## Acceptance Examples

- AE1. **Covers R7.** Given a student whose picked interests are Arts and Social, when they open the
  Events tab, the hero shows the soonest upcoming event tagged Arts or Social, not simply the
  soonest event overall.
- AE2. **Covers R7.** Given a student with no upcoming event matching any picked interest, when they
  open the Events tab, the hero shows the soonest upcoming event of any category, with no "for you"
  tag on it.
- AE3. **Covers R11.** Given an event showing "12 students interested," when a student taps "I'm
  interested" on it, every student who views that event afterward sees "13 students interested."

---

## Success Criteria

- A newly arrived student can find something concrete to do this week from the Events tab without
  first learning any category names or touching a filter.
- The event data refreshes on its own; nobody has to remember to re-export or re-commit
  `journey/umich_event_data`.
- Removing Housing from the nav causes no regression — it's still fully reachable and functional as
  a Market category.
- A downstream planner can implement R1-R11 without inventing the hero's fallback rule, the "I'm
  interested" interaction's shape, or where interest data is modeled — those are pinned down under
  Key Decisions and Dependencies below.

---

## Scope Boundaries

- Implicit/behavioral interest learning (inferring interests from clicks or RSVPs instead of asking)
  — not in this pass; the onboarding pick is the only signal.
- Richer visual treatment (category cover art or icons on cards) — not in this pass.
- A dedicated Housing hub or screen — explicitly not being built; Housing stays a Market category
  only.
- A browsable "past events" / archive view — not requested; expired events simply stop appearing,
  as they do today.
- Real per-student RSVP memory (a "your interested events" list) — considered and set aside in favor
  of a throwaway tally; would be a meaningfully bigger addition (a new personal list screen,
  per-student edges).
- An "agenda-first" layout, where personalization is folded into the day-grouped list with no
  separate hero — reviewed as one of five visual directions and set aside in favor of the hero-led
  direction.

---

## Key Decisions

- Chose a "today's pick" hero over a spotlight carousel, an interest-filter rail, or an agenda-only
  layout: reviewed as five visual mockups, and the hero was judged the best fit of engagement value
  to build cost, and closest to the "For You section above the list" shape locked earlier in
  brainstorming.
- Interests are captured once at onboarding rather than learned from behavior, so a brand-new
  student's very first visit to the tab already has something to rank on instead of a generic list.
- Personalization stays rule-based tag matching, never AI-ranked, to stay inside the project's
  "rules must be deterministic" constraint (`docs/ENGINEERING_RULES.md` rule 5).
- Interest data belongs to `journey/` (Feature A), not `core/profile.jac`: `market/` has no use for
  it, and adding it to the shared core model would need both feature leads' sign-off for what is a
  journey-only concern.
- "I'm interested" is a throwaway public tally, not a tracked RSVP, to keep this pass to one new
  lightweight interaction instead of a new personal-list screen and per-student edges.

---

## Dependencies / Assumptions

- events.umich.edu's public JSON feed (documented at events.umich.edu/feeds, Localist-powered, no
  auth per its own documentation) is assumed to be the same style of source the original static
  export came from. This is not confirmed against the original export's actual source — the prior
  prototype's fetch code (`events_source.jac`) isn't in this repo — and a direct fetch attempt from
  this environment returned HTTP 403 (see Outstanding Questions).
- Assumes the existing `CATEGORY_RULES` categories are a workable interest taxonomy for onboarding;
  no new taxonomy is being designed.
- Assumes the current onboarding flow can be extended with one more step without disrupting it; not
  verified against the actual onboarding screen implementation.

---

## Outstanding Questions

### Deferred to Planning

- [Affects R1, R2][Needs research] Confirm the events.umich.edu JSON feed actually returns data
  matching the fields `all_events()`/`parse_events()` expect (`date_start`, `date_end`,
  `combined_title`, `event_type`, `tags`, `location_name`, `sponsors`, `cost`, `permalink`). A direct
  fetch from this environment returned HTTP 403, most likely bot protection rather than a real auth
  wall, but this needs verifying from wherever the refresh script will actually run.
- [Affects R1][Technical] What triggers the refresh (cron, a GitHub Action, a manual command) and how
  often — events don't change hour to hour, so a coarse daily-ish cadence is likely sufficient, but
  the exact mechanism is a planning decision.
- [Affects R5][Technical] Where interest data is modeled (a new `journey/` node vs. a field, and how
  it's threaded to the events screen) is left to planning, per the decision that it lives in
  `journey/`, not `core/`.
- [Affects R11][Technical] The concrete shape of the "I'm interested" tally (likely following the
  pattern of Market's public counter nodes, e.g. `Membership`, per the "each student sees only their
  own edges" rule in this repo) is left to planning.
