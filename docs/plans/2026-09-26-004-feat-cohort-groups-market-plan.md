---
title: "feat: Cohort groups with AI-made topic groups for the secondhand market"
type: feat
status: active
date: 2026-09-26
origin: docs/plans/2026-09-26-003-feat-chat-first-market-plan.md
---

# feat: Cohort groups with AI-made topic groups for the secondhand market

## Summary

Students chat in their **cohort group** (arrival month), the way they already use a WeChat group.
When someone drops a message about the secondhand market (buy, sell, give away, rent, housing,
rides), the AI assistant picks it up: it extracts the facts, creates or reuses a **topic group**
("Desks & chairs · move-in week"), puts the poster in it, and **invites** students who are likely
interested (their own posts match, or their profile fits), each with a one-line reason. Invitees
tap Join to enter; nobody is added without accepting. The assistant replies in the cohort group
so everyone sees where the topic moved.

## Decisions (confirmed with the user, 2026-09-26)

- **Cohort groups** are the main groups. Default cohort: arrival month from the profile ("Arriving
  Aug 2026"); students without an arrival date go to "New arrivals". (One function; easy to
  change to program or term.)
- **Invites are opt-in**: matched students get an invite with the reason; Join to enter, Dismiss to
  ignore. The poster is a member from the start.
- **Reuse one topic group** when several students want the same kind of thing: a new market message
  joins an open topic group on the same topic instead of creating another.
- Plan 003's personal stream and private threads (PR #40) are dropped; its engine (#39: AI
  extraction, deterministic two-way matching, assistant notes, availability, limitations,
  moderation, notifications) is reused.

## Requirements

- G-R1. A verified student is a member of their cohort group automatically (joined on verification
  and when their arrival date changes) and can read and post there.
- G-R2. Any message can be posted in a cohort group. The AI decides whether it is about the
  secondhand market; other messages are just chat (no AI reply).
- G-R3. A market message becomes a post (existing rules: offer/request, category, facts, expiry,
  matching) without any form; if intent is unclear the assistant asks one question in the group,
  visible to the poster only, with quick-reply answers.
- G-R4. The assistant files the post into a topic group: reuse an open topic group with the same
  topic key (category + item word, e.g. `furniture:desk`), else create one named from the facts.
  The poster joins it; the assistant replies in the cohort group: "Moved to 'Desks · near campus'
  and invited N students who may be interested" (never inventing people or counts).
- G-R5. Invites go to students whose own live posts match (existing two-way matching) or, for
  rides, who arrive the same day and need an airport ride; each invite states why. Invites respect
  blocks and suspensions and are sent once per student per topic group.
- G-R6. Topic group members see all its messages and the assistant's summary card of the live
  offers and requests filed there (facts, availability, limitations); members can post, and each
  post's owner can mark it sold/found/withdrawn.
- G-R7. Non-members can't read a topic group's messages; invitees see only its name, reason and
  a count until they join.
- G-R8. Notifications: invites join the in-app badge and the email digest; group chat messages do
  not email.
- Carried: verified UMich only, blocks hide each other's messages, reports and moderation.

## Implementation Units

- **G1 Groups model** (`market/groups.jac`): `ChatGroup` (kind cohort|topic, name, key, created),
  `MemberOf` edge (Root → ChatGroup) with Jac `allow_group` so members read and write, `GroupMessage`
  (author, text, created, ai flag, post_id), `Invite` (group, invitee, reason, status). Pure
  helpers: `cohort_key(profile)`, `cohort_name(key)`, `topic_key(post)`, `topic_name(post)`.
- **G2 Cohorts**: `ensure_cohort_membership()` on verification and profile update; `my_groups()`.
- **G3 Posting**: `post_to_group(group_id, text, answers)`; market classification via a new
  `about_market` field on the AI draft; publish post; topic group reuse or create; assistant reply
  in the cohort group; poster-only follow-up questions.
- **G4 Invites**: candidates from matching suggestions and ride profiles; `my_invites()`,
  `join_group(invite)`, `dismiss_invite(invite)`; new matches keep inviting into the same group.
- **G5 Topic groups**: `group_view(group_id)` (messages, members count, assistant summary of posts),
  `close_post` from the group.
- **G6 Screens**: `/groups` (my cohort, my topic groups, invites) and `/g?id=` (group chat with the
  composer, labeled assistant messages, invite banner for non-members, topic summary card).
- **G7 Validation**: cohort chat, market message → topic group + invites, second similar request
  reuses the group, invitee joins and replies, ambiguous message, sold item leaves the summary,
  blocked student not invited, non-member can't read.

## Scope Boundaries

- No public listing of topic groups beyond invites (discovery is through the AI's invites).
- No AI replies to non-market chat.
- Payments, lease signing: still out.
