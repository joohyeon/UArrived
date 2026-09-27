---
date: 2026-09-27
topic: themed-group-chats
status: ready-for-planning
replaces: docs/plans/2026-09-26-004-feat-cohort-groups-market-plan.md (group structure), docs/brainstorms/2026-09-27-003-topic-grouping-mvp-requirements.md (topic groups)
---

# Themed group chats with Buying and Selling messages

## Summary

The marketplace is a small, fixed set of themed group chats (Furniture, Electronics, Textbooks,
Kitchen & essentials, Bikes & vehicles, Housing & sublets, Move-out sales, Rides) that verified
students browse, preview and join. Students chat normally. A buy or sell message stays in the
conversation, tagged **Buying** or **Selling**. The AI then connects buyers and sellers in three
ways:

- a labelled note under the message listing the matches in that group;
- private notifications to matching students anywhere;
- one tap to open a private chat.

---

## Problem Frame

The shipped design (plan 004 and PR #49) auto-places each student in an arrival-month group. It
then moves any market message out of the chat into an AI-made topic group ("Desks near campus")
that others enter only by invitation.

That works mechanically, but it doesn't feel like the group chat students already use. Buying and
selling happens somewhere else, groups appear and multiply without anyone choosing them, and
there's no way to find or browse the groups where people trade a kind of thing. Students expect
to pick a few interest groups (furniture, textbooks, move-out sales), post "Selling my bike for
$80" as easily as any message, and see it sit in the conversation. They want help reaching the
people who want it, not a separate listing flow.

---

## Actors

- A1. **Student:** a verified UMich student. Chats in groups, posts Buying/Selling messages and
  replies.
- A2. **Assistant:** the AI. Recognizes buy/sell intent, tags the message, asks at most one private
  question, matches, notes matches in the thread, and notifies. It is always labelled as
  automated.
- A3. **Moderator:** the existing moderator role for reports, hiding and suspensions (unchanged).

---

## Key Flows

- **F1. Join groups.** A new student opens the market and sees the list of themed groups, each with
  a short description, member count, latest activity and a few suggested groups. They open any
  group read-only, then tap Join to post.
- **F2. Drop a market message.** In a group they've joined, a student sends "Selling my bike for
  $80". The message appears in the chat immediately.
  - If the assistant recognizes a buy/sell intent, the message gets a **Selling** tag and its
    facts (item, price, area, dates) show on the message.
  - If intent is unclear, the sender alone gets one quick question ("Are you selling this or
    looking for it?"), and the tag appears once they answer.
  - Plain chat gets no tag and no assistant reply.
- **F3. Connect.** Once tagged:
  - the assistant adds a labelled note under the message listing Buying/Selling messages in *that
    group* that fit, each with its reason;
  - students elsewhere whose own open messages fit get a private notification (in-app badge and
    email digest) with the reason and a link to the message;
  - from the message, the other side taps **Message privately** to open a private chat with the
    poster.
- **F4. Close the loop.** The poster marks the message **Sold**, **Found** or **No longer
  available**, or removes the tag ("it's just chat"). The tag updates in place, and it stops
  matching and notifying.

---

## Requirements

**Groups**
- R1. There is a fixed, curated set of themed groups: Furniture, Electronics, Textbooks, Kitchen &
  essentials, Bikes & vehicles, Housing & sublets, Move-out sales, Rides. Each has a name, a
  one-line description and an icon. Students can't create groups.
- R2. Any verified student can browse all groups and read any group without joining (read-only
  preview). Joining is one tap. Only members can post. Members can leave any group.
- R3. The group list shows the student's joined groups first (by latest activity), then the rest.
  Up to three groups are marked "Suggested for you", based on the profile: Housing & sublets if
  they're looking for housing, Rides if they need an airport ride, and Move-out sales and Furniture
  for everyone. Nothing is joined automatically.
- R4. Arrival-month cohort groups and AI-made per-item topic groups are retired, along with their
  invites.

**Messages**
- R5. Any message can be sent in a joined group, like an ordinary group chat. Ordinary chat gets no
  assistant reply.
- R6. When the assistant recognizes a message as buying or selling (including giving away, renting,
  housing and rides), the message stays where it was written, gets a **Buying** or **Selling** tag,
  and shows its key facts. The sender fills in no form.
- R7. A message about several items becomes one tagged entry per item under the original message.
- R8. If intent is unclear, the sender alone sees one quick question, and the tag appears after
  they answer. A sentence the assistant can't place stays plain chat.
- R9. The poster can remove the tag, or mark the message Sold, Found or No longer available. The
  tag then updates in place (e.g. "Sold") and stops matching and notifying. Tagged messages
  expire under the existing post expiry rules and show "Expired".
- R10. Tags and assistant notes are visually distinct from ordinary chat. Assistant content is
  always labelled as automated.

**Connecting buyers and sellers**
- R11. After tagging, the assistant adds one labelled note under the message listing up to three
  open Buying/Selling messages *in the same group* that fit, each with a factual reason ("$30 is
  within the $40 budget"). If none fit, it adds no note. It never invents people, items or counts.
- R12. Students anywhere whose own open tagged messages fit are notified privately, in-app and in
  the email digest, with the reason and a link to the message. Each match is notified once. Blocks
  and suspensions are respected.
- R13. From any tagged message, another student can tap **Message privately** to open a private
  chat with the poster (reusing the existing private chats). The poster is told who started it.
- R14. Matching uses the existing standard items and fact-based rules. Matching on the same kind of
  thing alone, without a stated fact, doesn't notify.

**Carried over unchanged:** verified UMich students only, reports, blocks, moderation and safety
tips; posting in any language with English copies (#46); standard items (#49).

---

## Acceptance Examples

- AE1. **Covers R6, R11.** In Furniture, Mina has an open "Looking for a desk, up to $40". Jae posts
  "Selling my IKEA desk $30". Jae's message shows **Selling** · Desk · $30. Under it, an assistant
  note says "Mina is looking for this: $30 is within the $40 budget", linking Mina's message.
- AE2. **Covers R12.** Kai posts "Looking for a bike" in Bikes & vehicles. Later Lee posts
  "Selling my bike for $80" in Move-out sales. Kai gets a private notification naming Lee's message
  and the reason, with a link, even though Kai isn't in Move-out sales. Lee's message doesn't show
  a note about Kai, because Kai's message is in another group.
- AE3. **Covers R8.** A student posts "desk" in Furniture. Only they see "Are you selling this or
  looking for it?". Other members see a plain message until they answer, then it shows the tag.
- AE4. **Covers R5, R8.** "Anyone else arriving on the 20th?" in Move-out sales stays plain chat,
  with no tag and no assistant note.
- AE5. **Covers R9.** Jae marks the desk sold. The tag becomes **Sold**, it drops out of matching,
  and no further notifications go out about it.
- AE6. **Covers R2.** A student who hasn't joined Textbooks opens it, reads the conversation and
  sees tags and notes, but has no composer until they tap Join.

---

## Success Criteria

- With the real model, a first-time student can join a group and post "Selling my bike for $80". It
  appears tagged within a few seconds, with no form.
- AE1–AE6 hold in served tests and in a browser walk-through.
- Chat messages ("hi", questions about campus) are not tagged in the validation set.
- The demo shows chat and marketplace in one conversation: a student reads Move-out sales, joins,
  posts, and gets matched.

---

## Scope Boundaries

- No cross-posting a message into another themed group. It reaches other groups' students only
  through notifications (R12).
- No student-created or AI-proposed groups, and no per-item or per-date sub-groups.
- No in-group negotiation features (offers, holds). Negotiation happens in the private chat.
- The Housing Hub is paused. Its checklist could later post Buying messages into these groups.
- Payments and lease signing are out.

---

## Key Decisions

- **Themes replace cohort and topic groups** (user choice). This is simpler to understand, and the
  groups match what students trade.
- **Messages stay in the conversation.** Market activity is visible where people chat. The cost is
  that reach beyond the group depends on notifications.
- **Routing is in-thread matches, private notifications and one-tap private chat.** Cross-posting
  was considered and rejected.
- **The theme set is fixed and curated,** for a clean demo with no naming or moderation rules for
  new groups.
- **Groups are open for read-only preview.** This helps discovery, and it makes group content
  visible to every verified student, which the in-thread match note relies on.

---

## Dependencies / Assumptions

- Reuses the drafting pipeline (several drafts per message, any language), standard items,
  matching, notifications, private chats, moderation and blocks.
- Retires the topic-group, invite and cohort code from #42/#43/#49. Dev data for old groups can be
  reset (hackathon database).
- The existing suggestion model and feed may be simplified or folded into the new matching.
  Planning decides.

---

## Outstanding Questions

- **Deferred to planning:** what happens to the Matches tab and the ranked "For you" feed once
  matches arrive as thread notes and notifications. Keep, merge or drop them.
- **Deferred to planning:** whether a tagged message posted in an off-theme group (a bike in
  Textbooks) gets any hint. Recommended default: no.
