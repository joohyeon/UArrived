---
title: "feat: Topic grouping MVP — standard items, multi-item split, ride weeks, tidy list"
type: feat
status: completed
date: 2026-09-27
origin: docs/brainstorms/2026-09-27-003-topic-grouping-mvp-requirements.md
---

# feat: Topic grouping MVP — standard items, multi-item split, ride weeks, tidy list

## Summary

Four small units that extend the cohort-group market from plan 004:

- **Standard item names.** The AI draft gains a standard item name, and topic groups key on it.
- **Multi-item split.** The same drafting call also returns extra items, which are filed as separate
  posts.
- **Ride weeks.** Ride groups key on route plus week instead of exact date.
- **Tidy group list.** The list sorts by recent activity, and members can leave a topic group.

No new AI calls, no new services, and no migration of groups that already exist.

---

## Problem Frame

A run against the real model showed four gaps: "study table" and "desk" land in different groups, a
bike/lamp/mattress message becomes one post under "Mattresses", DTW riders a day apart never meet, and the
group list neither sorts by activity nor lets anyone leave (see origin:
docs/brainstorms/2026-09-27-003-topic-grouping-mvp-requirements.md).

---

## Requirements

- T-R1 Standard item names from a fixed per-category list, with synonyms; unknown items file as "Other
  <category>"; the topic group is chosen by the standard name.
- T-R2 A multi-item message becomes one post per item (max 5), each filed and invited separately. The
  student's message shows once, and one assistant reply lists where each item went. Shared facts apply to
  every item; an item's own price stays with that item; items past 5 are reported as not filed.
- T-R3 Ride groups are keyed by route (or "from X") and week of travel; ride posts inside are listed by
  date.
- T-R4 The group list shows the cohort first, then topic groups by most recent message. Members can leave
  a topic group (not the cohort) and can rejoin through a later invite.
- Carried from plan 004: the AI decides chat vs market, asks at most one question and only the sender sees
  it, invites need a factual reason (same item; housing and rides may match on stated facts), invites are
  opt-in and sent once, and the AI never invents people, items or counts.

**Success criteria (origin):** with the real model, "study table" and "desk" requests share a group; the
bike/lamp/mattress message makes three posts in three groups; DTW riders on Oct 2 and Oct 3 share a group;
the plan 004 scenario tests still pass.

---

## Scope Boundaries

- One kind per message: a multi-item message is all offers or all requests. A mixed message ("selling
  my bike, need a desk") files only the kind the AI chose (confirmed during planning).
- No migration: posts already filed under the old keys stay in their groups (confirmed during planning).
- Unchanged: matching rules, invite rules and notifications.

### Deferred for later (from origin)

- Category hubs with threads; AI-proposed splits or merges of busy groups.
- Location sub-groups (North vs Central campus, Kerrytown); per-cohort topic groups; archiving stale groups.

### Outside this product's identity (from origin)

- Payments; a public browsable list of all topic groups (discovery stays through invites and the cohort
  reply).

### Deferred to Follow-Up Work

- Mixed offer and request items in one message.
- Moving the item list to `data/` if the content owner wants to review it.

---

## Context & Research

### Relevant Code and Patterns

- `ai/draft.jac`: the `PostDraft` object, its `sem` strings, and the single `draft_post … by drafter()`
  call. New fields go at the end, because fields with defaults must follow required fields.
- `market/drafting.jac`: `DraftCard`, `normalize` and `manual_card`. Every new draft field is carried
  through `normalize`, following the `constraints` / `about_market` pattern.
- `market/topics.jac`:
  - `item_word`, `topic_key`, `topic_name`, `plural`;
  - `file_market`, which runs draft → question → publish → topic group → announcement → invites → cohort
    reply;
  - `invite_matches`, whose same-item check uses `topic_key`;
  - `groups_of_mine`, which currently sorts oldest first;
  - `view`.
- `market/messages.jac`: `blocking_question` and `fields_from`, shared with the stream flow.
- `market/constants.jac`: import-free constants that client screens can also import.
- `core/groups.jac`: `leave(g)` already exists and removes both the `MemberOf` edge and the public
  `Membership` record.
- `market/screens/groups.jac`: `GroupList` and `GroupChat`.
- Tests: `market/topics_tests.jac` holds the served scenarios. It must keep its server-module import so
  `MockLLM` reaches the app (CLAUDE.md).

### Institutional Learnings

These come from CLAUDE.md:

- Client code treats an empty list as truthy, so screens use `len()`.
- An omitted `str | None` parameter arrives as the string "None".
- A student sees only their own edges, so anything others must see needs a public record.

---

## Key Technical Decisions

- **One drafting call returns every item.** `PostDraft` gains a standard `item` and a short list of
  `extra_items`, each with a title, standard item and optional price. The first item stays in the existing
  top-level fields, so single-item messages and the older stream flow are unchanged. No second AI call.
- **The item list lives in market code.** A glob in `market/constants.jac` maps each category to its
  standard items and synonyms. Developers own it (confirmed during planning).
- **Deterministic fallback.** When there is no AI, or the AI's item isn't on the list, the title's words go
  through the same synonym map, and anything unmatched becomes "other". Topic keys never depend on
  free-form model text.
- **The item is stored on the post and checked in one place.** `Post` gains an `item` field, so topic
  keys, matching and invites all read the same value.
  - Every publish path passes the draft's item through `fields_from` / the compose fields.
  - `publish` checks it against the list for the *final* category (after any answers), falling back to
    the title mapper.
  - `item` is not in `EDITABLE`, so a client can't set it directly.
  - `edit` recomputes it whenever the title or category changes.
  - Read-time fallback: `topic_key` uses `p.item` when set and otherwise maps the title, so posts from
    before this change and posts built in tests still key correctly.
- **Ride week = the Monday-start calendar week of the travel date.** It is easy to explain ("week of
  Sep 28"). The known cost is that riders on a Sunday and the Monday after land in different groups;
  that's acceptable for the MVP.
- **Multi-item replies are one cohort message that carries several links.**
  - The group message gains a list of links (item label, post, group); single-item messages keep their
    one `post_id` as the first entry.
  - The view gates each link by the reader's membership.
  - Each item still gets its own announcement in its topic group, plus its own invites.
  - Items that couldn't be filed are named only in the sender's private notice, following the existing
    "only you see this" convention; the public reply lists only what was filed.
- **Leaving allows one later re-invite.**
  - Leaving writes a public, content-free "left" record (group, student, time), like `Membership`.
  - Invite marks gain a created time.
  - The duplicate check ignores marks older than the student's latest "left" record. The first new
    invite after leaving therefore goes through, and its mark blocks any more.

---

## Open Questions

### Resolved During Planning

- Where the item list lives: in market code (see Key Technical Decisions).
- Existing groups: not migrated.
- Mixed kinds in one message: not in this MVP.

### Deferred to Implementation

- The exact items and synonyms per category. Start from the brainstorm examples and tune them against
  the real-model run.
- How to name the result fields that report several filed items (e.g. a list of group ids and titles).
- Whether a fully failed multi-item message should say "couldn't file any of these" or list each reason.
- Extra items get the same validation as the main item (no negative prices, no empty titles), and an extra
  item that repeats the main item is dropped.

---

## Implementation Units

### U1. Standard item names

**Goal:** Every post has a standard item, and goods topic groups key on it.

**Requirements:** T-R1.

**Dependencies:** none.

**Files:**
- Modify:
  - `market/constants.jac` (item list with synonyms per category)
  - `ai/draft.jac` (`item` field and its `sem`)
  - `market/drafting.jac` (carry `item` through `normalize` and `manual_card`)
  - `market/graph.jac` (`Post.item`)
  - `market/messages.jac` (`fields_from` carries the draft's item)
  - `market/lifecycle.jac` (`publish` checks the item against the final category or falls back; `edit` recomputes it when title or category changes; `item` stays out of `EDITABLE`)
  - `market/topics.jac` (`topic_key` / `topic_name` use the standard item, with "Other <category>" names)
- Test:
  - `market/topics.jac` (in-file tests for the mapper)
  - `market/topics_tests.jac`

**Approach:**
- The `sem` tells the model to choose only from the listed items for the category, or "other".
- The server re-checks the model's choice against the list.
- The mapper does lowercase word matching against synonyms, including multi-word synonyms like "mini
  fridge" and "study table".
- Housing and rides keep their current keys. Standard items apply to furniture, essentials and vehicle.
  Non-ride service posts (moving help, storage) keep the title-word key.
- The `sem` carries a hand-copied summary of the item names, because Jac `sem` strings are literals. An
  in-file test asserts every standard name in the constants appears in the `sem`, so the two can't drift.
- The invite reason for same-item matches uses the stored item ("it's about desks too").

**Patterns to follow:**
- `about_market` / `constraints`: a draft field carried through `normalize`.
- `item_word` / `plural`: in-file tests.

**Test scenarios:**
- Mapper: "Study table" → desk; "IKEA MALM desk" → desk; "Mini fridge" → fridge; "Twin mattress" →
  mattress; "Lava lamp" → lamp; "Kayak" in furniture → other.
- Topic name for "other" is "Other furniture"; for desk it is "Desks near campus".
- Served: a request drafted as "Study table" (model `item="desk"`) and an offer drafted as "Wooden
  desk" file into the same topic group, and the buyer is invited when prices fit.
- Served: the model returns an item not on the list ("gizmo") → the post files as other for its category
  and nothing breaks.
- Served, without AI (MockError): "Selling my study table" with answers kind:offer and category:furniture
  → files under desks via the fallback.
- A post from the compose form (`publish_post`) with title "Desk chair" → item is chair.
- Editing a desk post's title to "Floor lamp" → item becomes lamp.
- An answer that changes the category (model said essentials/lamp, student answers furniture) → the item
  is re-checked against furniture and falls back to the title mapper.
- A `Post` with no stored item and title "Solid wood desk" still keys to `furniture:desk` (existing
  in-file test keeps passing).
- Drift test: every standard item name in the constants appears in the `PostDraft.item` sem.

**Verification:** New desk-like posts share one group whatever wording they use. Existing plan 004 tests
still pass.

---

### U2. Multi-item messages become several posts

**Goal:** A message with several items files each one separately and reports them all.

**Requirements:** T-R2.

**Dependencies:** U1.

**Files:**
- Modify:
  - `ai/draft.jac` (`extra_items` list and its `sem`)
  - `market/drafting.jac` (carry the extra items)
  - `core/groups.jac` (group messages carry a list of links; single-item messages keep `post_id` as the first entry)
  - `market/topics.jac` (`file_market` loops over the items; the result reports each one; one cohort reply; `view` returns links gated by membership)
  - `market/screens/groups.jac` (one "Open <group>" link per item the reader can open, stacked as full-width tap targets)
- Test: `market/topics_tests.jac`

**Approach:**
- Build one field set per item. Each starts from the shared facts (kind, dates, area, constraints), then
  applies that item's own title, item and price. The description is the student's full message, not the
  model's, so it never contradicts a single item.
- The blocking question runs once, on the shared facts.
- Each item is published, filed into its group, announced there, and invited.
- The cohort reply is one message, for example: "I filed 3 items: bike → Bikes near campus, lamp → Lamps
  near campus (invited 1), mattress → Mattresses near campus." Items past 5 are listed as not filed.
- If an item fails to publish (e.g. a past date), only the sender's private notice names it and the reason.
- The cohort reply links each filed item's group, shown to readers who are members of that group.

**Test scenarios:**
- A draft with the main item "Bike" plus extra items "Floor lamp" and "Twin mattress" makes three posts
  in three topic groups. The reply names all three, and `list_my_posts` shows three.
- Per-item price: "bike $50, lamp $10" → each post has its own price. A shared area ("Kerrytown")
  applies to all.
- Seven items → five filed; the reply says two weren't filed.
- An unclear kind → one question; answering kind:offer files every item as an offer.
- A buyer whose request matches only the lamp is invited only to the lamps group.
- One item fails to publish → the others still file; the public reply lists only the filed items, and
  the sender's notice names the failed one.
- Reader gating: the sender sees three links; another cohort member who isn't in any of those groups
  sees the reply text but no links.
- A single-item message behaves exactly as before (regression check with a plan 004 test).

**Verification:** The bike/lamp/mattress message produces three posts in three groups, with one assistant
reply in the cohort.

---

### U3. Ride groups by route and week

**Goal:** Riders in the same week on the same route share a group.

**Requirements:** T-R3.

**Dependencies:** none (can land in parallel with U1).

**Files:**
- Modify: `market/topics.jac` (ride `topic_key` / `topic_name` use the Monday of the travel week; the
  topic `view` sorts ride posts by date then time)
- Test: `market/topics.jac` (in-file), `market/topics_tests.jac`

**Approach:**
- Key: route from > route to (or "from X" alone) plus the week's Monday.
- Name: "Rides from DTW to Ann Arbor · week of Sep 28".
- A ride without a date keeps a date-free key: "Rides from DTW".

**Test scenarios:**
- Oct 2 (Fri) and Oct 3 (Sat), DTW → Ann Arbor → same key. Oct 4 (Sun) → same week, same key. Oct 5
  (Mon) → next week, different key.
- No destination → name "Rides from DTW · week of Sep 28".
- No date → "Rides from DTW", and it still files.
- Served: two ride messages two days apart file into one group, and the group view lists them earliest
  first.

**Verification:** DTW riders on Oct 2 and Oct 3 share one group.

---

### U4. Tidy group list and leaving a topic group

**Goal:** The group list sorts by activity, and members can leave topic groups.

**Requirements:** T-R4.

**Dependencies:** none.

**Files:**
- Modify:
  - `core/groups.jac` (public "left" record written on leave)
  - `market/topics.jac` (`groups_of_mine` puts the cohort first, then newest activity; new `leave_topic_group` endpoint that refuses cohorts and non-members; invite marks get a created time; the duplicate check ignores marks older than the invitee's latest leave)
  - `main.jac` (import the endpoint)
  - `market/screens/groups.jac` (a Leave control in the topic group chat that needs a second "Leave group?" tap and sits apart from Withdraw; after leaving, go back to the list)
- Test: `market/topics_tests.jac`

**Approach:**
- Leaving uses `core/groups.jac` `leave`, which already removes the edge and the public membership.
- Re-invite after leaving uses the "left" record and the timed invite marks (see Key Technical
  Decisions). Existing invite records keep their status.
- The leaver's own live posts keep pointing at the group and stay in its summary. They can withdraw
  them as before.

**Test scenarios:**
- A student in a cohort and two topic groups sees the cohort first, then the group with the most recent
  message.
- Leaving a topic group removes it from their list and drops the member count by one. Group view then
  says they're not in the group.
- Trying to leave the cohort is refused with a clear error.
- Trying to leave a group you're not in is refused.
- After leaving, a new matching post in that group invites the student again, and a second new matching
  post doesn't invite them a third time.
- A first tap on Leave only asks "Leave group?"; nothing changes until they confirm.

**Verification:** In the browser, the list shows the most recently active group first, and Leave returns to
the list with the group gone.

---

## System-Wide Impact

- **AI output shape:** `PostDraft` gains two fields at the end.
  - The stream flow (`market/messages.jac`) and the compose draft (`draft_from_message`) ignore
    `extra_items` and only store `item`.
  - Plan 004 and C1–C5 tests that build `PostDraft` without the new fields still work, because both have
    defaults.
- **Matching and invites:** `invite_matches`'s same-item rule gets better automatically once `topic_key`
  uses the standard item. `market/matching.jac` itself doesn't change.
- **Client bundle:** the item list lives in import-free `market/constants.jac`, so screens can use it
  without pulling in server modules.

---

## Risks & Dependencies

- **The model picks a wrong item.** The server-side list check plus the "other" fallback keeps keys
  valid. The worst case is a post filed under "Other furniture", not in a wrong group.
- **Extra items the student didn't mention.** The `sem` says "only items the student names". Tests use
  MockLLM, and the real-model run in U2's verification checks this directly.
- **Old groups keep their names.** Existing "Tables near campus" and similar groups stay alongside the
  new ones until the dev database is reset.

---

## Documentation / Operational Notes

- Add one CLAUDE.md note if implementation turns up a new Jac gotcha (e.g. list-of-object fields in
  `by llm` outputs).
- Re-run the real-model scenario script after U2 and record the result in the PR description.

## Sources & References

- Origin: `docs/brainstorms/2026-09-27-003-topic-grouping-mvp-requirements.md`
- Builds on: `docs/plans/2026-09-26-004-feat-cohort-groups-market-plan.md` (PRs #42, #43)
