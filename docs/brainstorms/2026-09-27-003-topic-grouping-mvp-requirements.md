---
date: 2026-09-27
topic: topic-grouping-mvp
status: ready-for-planning
builds-on: docs/plans/2026-09-26-004-feat-cohort-groups-market-plan.md
---

# Topic grouping MVP: how the AI files market messages into groups

## Problem

Cohort groups plus AI-made topic groups (plan 004, shipped in #42/#43) work, but a run against the
real model showed four weak spots:

1. **Too literal.** "study table" and "desk" land in different groups.
2. **One message, many items.** "Selling a bike, a lamp and a mattress" became one post filed under
   "Mattresses".
3. **Rides split by exact date.** A student riding Oct 2 and one riding Oct 3 from DTW never meet.
4. **Groups pile up.** The group list has no order by activity and no way to leave a topic group.

## Decision

Keep the current shape. Students chat in their cohort (arrival month); the AI files market messages into
**flat, campus-wide topic groups**. Fix only the four weak spots. No hubs, no automatic splitting or
merging.

Topic groups stay campus-wide on purpose: sellers are mostly students moving out and buyers mostly
students arriving, so they are in different cohorts. Flat groups also work with few users.

## Requirements

- **T-R1 Standard item names.** The AI picks the item from a short fixed list per category. For example,
  furniture: desk, chair, bed, mattress, sofa, shelf, table, dresser; essentials: lamp, fridge, microwave,
  kitchenware, bedding. Synonyms map to one name ("study table" → desk, "mini fridge" → fridge). An item
  not on the list files under the category ("Other furniture"). The topic group is chosen by the standard
  name, not by the words in the title.
- **T-R2 Multi-item messages become several posts.** A message offering or seeking several items becomes
  one post per item, up to 5, each filed in its own topic group with its own invites. The student's
  message appears once in the cohort. One assistant reply lists where each item went. Shared facts
  (area, dates, "all cheap") apply to every item; a price attached to one item stays with that item.
  With more than 5 items, the first 5 are filed and the reply says the rest weren't.
- **T-R3 Ride groups by route and week.** Ride topic groups are keyed by route (from → to, or "from X"
  when there is no destination) and the week of travel ("Rides from DTW · week of Sep 28"). Ride posts
  inside the group are listed in date order.
- **T-R4 Tidy group list.** The group list shows the cohort first, then topic groups by most recent
  message. A member can leave a topic group (not their cohort); leaving hides it from their list and
  stops notifications, and they can rejoin through a later invite. A topic group with no open posts
  shows "Nothing open right now" (already true).
- **Carried from plan 004:** the AI decides chat vs market, asks at most one question and only the
  sender sees it, invites need a factual reason (same item; housing and rides may match on stated
  facts), invites are opt-in and sent once, and the AI never invents people, items or counts.

## How the AI assists (MVP)

| Step | What the AI does | What it must not do |
|---|---|---|
| Intake | Decides whether a cohort message is about the market | Reply to plain chat |
| Extraction | Pulls the facts (kind, item, price, dates, area) | Add facts the student didn't write |
| Normalizing | Maps each item to a standard name | Invent an item the list doesn't have; use "Other <category>" instead |
| Splitting | Turns a multi-item message into one post per item | Merge separate items or duplicate one |
| Clarifying | Asks one question when kind is unclear | Ask about details that don't change where it's filed |
| Inviting | Invites students whose posts match, with the reason | Invite on category or date overlap alone |

## Success criteria

- Re-running the validation scenario with the real model: "study table" and "desk" requests share a
  group; the bike/lamp/mattress message produces three posts in three groups; DTW riders on Oct 2 and
  Oct 3 share a group.
- No regression in the plan 004 scenario tests.

## Scope boundaries

**Deferred for later:**
- Category hubs with threads (Furniture / Housing / Rides / Essentials).
- AI-proposed splits or merges of busy groups.
- Location sub-groups (North vs Central campus, Kerrytown).
- Per-cohort topic groups; archiving stale groups.

**Out of scope:** payments, a public browsable list of all topic groups (discovery stays through
invites and the cohort reply).

## Open questions (for planning)

- The exact standard item list per category (a small data file others can review), and how rides and
  housing fit in (they already group by route and arrangement).
- How a multi-item split is shown to the sender when it only partly succeeds (e.g. one item has a past
  date).
