---
title: "feat: From a dropped message to a match and a private thread"
type: feat
status: active
date: 2026-09-27
origin: user brief (2026-09-27), refining docs/plans/2026-09-27-002-feat-themed-group-chats-plan.md
---

# feat: From a dropped message to a match and a private thread

## Summary

This plan makes each step from a dropped message to a transaction visible, and makes the AI's
role explicit:

1. **Drop.** The message is tagged Buying or Selling in the group feed.
2. **Clarify.** The sender alone gets focused questions about missing or guessed details, each
   answered with a tap or a word.
3. **Match.** The sender alone sees matches: why each fits (confirmed facts), what's still unknown
   or only guessed, and **I'm interested**.
4. **Thread.** Tapping I'm interested opens a private buyer–seller thread linked to the original
   message. The thread states that only the two of them can see it, and only they can (server
   grants plus checks).
5. **Help.** Inside the thread, a labelled assistant panel summarizes the request and offer, lists
   open questions, and offers suggested replies. Suggestions only fill the composer. Reserving and
   marking sold always ask for confirmation.
6. **Progress.** A post moves through Finding matches → Match found → Awaiting response → Reserved
   → Completed, plus Unavailable, and several interested buyers are handled.

The group feed stays a focused marketplace feed: the public note that named matching students is
removed.

---

## Problem Frame (review of the current build, #55)

| Step | Today | Break |
|---|---|---|
| Drop | Tag with facts | Model guesses show as facts; a drafting failure silently leaves plain chat |
| Clarify | Only "selling or looking?" | Condition, location, availability and pickup are never asked; nothing is editable without a form |
| Match | A public note naming students, written once | Clutters the feed, exposes who wants what, goes stale, never states unknowns |
| Thread | "Message privately" opens a bare chat titled with the item | No link to the message, no "who can see this", no AI help |
| Progress | Sold / Found only | No match, awaiting, reserved or completed states; several buyers unhandled |

---

## Requirements

- **M-R1 Confirmed vs guessed.** Posts keep the fields the AI inferred (`inferred`). Tags, match
  cards and thread summaries mark guessed values "AI guess". The sender confirms or corrects them
  with one tap. The AI never fills a missing detail; missing ones show as unknown.
- **M-R2 Clarify.** After filing, the sender privately sees up to 3 focused questions for their
  post, covering missing or guessed useful details:
  - price or budget;
  - condition, for goods offers;
  - area;
  - availability ("available until" or "needed by");
  - pickup (pickup only / can deliver / flexible).

  Each answer is a quick choice or one short input. Answering confirms the detail and re-runs
  matching. "Skip" hides a question.
- **M-R3 Matches, private to the owner.** Under the owner's own tagged message, a "Your matches"
  panel (visible only to them) lists up to 5 compatible live posts. Each shows:
  - the other item and poster;
  - reasons from confirmed facts;
  - unknowns ("Condition not stated") and AI guesses;
  - **I'm interested**.

  With no matches, it shows "Finding matches — nothing fits yet. You'll get a notification when
  something does." Other members never see the panel.
- **M-R4 Trigger and privacy notice.** **I'm interested** appears on match cards and on anyone
  else's live tagged message. It opens a confirmation: "Start a private thread with <name> about
  "<item>". Only you and <name> can see it — other group members and other interested students
  can't." Confirming creates, or reopens, one thread per buyer–seller pair per post.
- **M-R5 Thread linked to the message.** The thread shows the group and the original message, a
  "Private · you and <name>" banner, and the status.
- **M-R6 Server-side privacy.**
  - Threads and their messages are readable only by the two participants (Jac grants), and every
    endpoint checks participation.
  - A competing buyer, another group member, or someone holding a thread id gets "not available".
  - The feed exposes only the post's public status (Available / Reserved / Sold), never who is
    interested or how many.
- **M-R7 Assistant in the thread.** A labelled panel is visible to each participant for their own
  side:
  - a summary of the offer and the request, with guessed values marked;
  - what fits;
  - open questions (unknown details);
  - 2–4 suggested replies for this participant, from the unknowns and the state.

  Tapping a suggestion fills the composer; nothing is sent until the user taps Send.
- **M-R8 Commitments need confirmation.** The seller can **Reserve for <buyer>**, release a
  reservation, and **Mark sold to <buyer>**, each behind a confirmation that says who gets told
  what. The buyer can **Withdraw interest**.
  - A reservation tells the other interested buyers "Reserved for another student" in their
    threads, without naming anyone.
  - Selling completes the chosen thread and marks the others "Sold to another student".
- **M-R9 States.**
  - **Post, owner view:** Finding matches, Match found (n), n interested, Reserved, Completed,
    Unavailable (withdrawn or expired).
  - **Feed, public:** Available, Reserved, Sold / Found, No longer available, Expired.
  - **Thread:** Awaiting response from <name> (since <time>), In conversation, Reserved for you,
    Reserved for another student, Completed, Unavailable.
- **M-R10 No silent failure.** If drafting fails on a message with clear market words, the sender
  gets a private notice ("I couldn't read that as a listing") with Try again.

---

## Key Technical Decisions

- **Suggested replies and summaries are deterministic, built from post data and state, not an LLM
  call.** They are instant, can't invent details, and can be tested. They are still labelled
  "Assistant".
- **Threads reuse `Chat` + `Suggestion`.**
  - "I'm interested" on a match card uses that match's suggestion.
  - On a plain tagged message it creates a "direct" suggestion, as in #55.
  - The suggestion records `message_id` and `group_id` so the thread links back.
- **Reservation lives on the post** (`reserved_for`, `reserved_chat`), together with `sold_to` and
  `sold_chat`. Each thread's state is derived from these, the post status and the message
  history.
- **The public match note is removed.** Matches move to the owner-only panel, and notifications are
  unchanged.
- **Every new endpoint checks participation or ownership on the server.** Thread reads go through
  `my_chat`, and posts change only via `own_post`.

## Scope Boundaries

- No LLM-written replies, no auto-send, no payments.
- No per-thread read receipts; "Awaiting response" means no message from the other side since the
  last message from this side.

---

## Implementation Units

- **U1 Post details and clarification.**
  - Files: `market/graph.jac` (`condition`, `pickup`, `inferred`, `reserved_for`, `reserved_chat`,
    `sold_to`, `sold_chat`), `market/lifecycle.jac` (store `inferred` from the draft; accept the
    `condition` and `pickup` fields), `market/themes.jac` (`detail_questions(post)`,
    `answer_detail` endpoint, silent-failure notice), plus tests.
  - Tests:
    - guessed dates are marked inferred;
    - answering the condition confirms it and removes it from the questions;
    - no more than 3 questions;
    - no questions for a fully detailed post;
    - only the owner can answer;
    - a drafting failure on "Selling my bike $80" gives a notice.
- **U2 Owner match panel.**
  - `market/themes.jac`: `my_matches(post_id)` builds match cards (reasons, unknowns, guesses,
    thread state); the public note is removed. The group view gives the owner, and only the owner,
    their post's panel data and state.
  - Tests:
    - the owner sees matches with reasons and unknowns;
    - another member sees no panel data;
    - no matches → "Finding matches".
- **U3 Interest and private threads.**
  - `market/themes.jac` (`start_thread(post_id, via_post_id)` endpoint), `market/connect.jac`
    (thread view with link, participants, state, assistant panel, suggested replies; reserve /
    release / sell / withdraw endpoints with ownership checks).
  - Tests:
    - one thread per pair, reopened on a second tap;
    - a competing buyer gets a separate thread and can't read the first;
    - a group member with the id is refused;
    - reserving shows "Reserved for another student" to others;
    - selling completes the chosen thread and marks the others unavailable;
    - withdrawing interest;
    - suggested replies never auto-send (they are data only);
    - public status is Reserved / Sold without names.
- **U4 Screens.**
  - `market/screens/groups.jac`: tag guesses, the owner's questions and match panel, I'm interested
    with the privacy confirmation, public status chips.
  - `market/screens/chats.jac`: the thread screen with its banner, link, status, assistant panel,
    suggestion chips filling the composer, and confirmed actions.
  - Also the chat list states and the Matches tab trigger.
- **U5 Validation.** Real-model end-to-end example (group message → clarification → match →
  thread → reserve → sold) plus a browser walk-through. The PR records the example.
