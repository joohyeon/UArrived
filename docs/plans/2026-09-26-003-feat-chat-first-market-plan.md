---
title: "feat: Chat-first marketplace - drop a message, get a response"
type: feat
status: active
date: 2026-09-26
origin: docs/brainstorms/2026-09-26-001-drop-a-message-marketplace-requirements.md
---

# feat: Chat-first marketplace - drop a message, get a response

## Summary

Replace the form-first compose with a chat-style Market: students type a message, it posts
immediately with extracted fact chips, and the AI assistant (labeled) answers in the message's
thread with matches, one follow-up question only when matching is blocked, or "no match yet"
with refine / notify-me options. Relevant students see the message in their own stream and can
react, ask, or make an offer privately; the poster accepts a reply to open a direct chat. The
matching engine, trust model, notifications and chat from #25-#38 stay.

## Problem Frame

Testers said posting felt like filling a listing form or starting a forum thread, not a group chat.
Today a message becomes a 14-field review form before anything is posted, matches appear later in
a separate tab, other students can only tap Connect / Not interested on a suggestion, there is no
way to ask or offer, no "confirmed vs needs checking" availability, and nothing happens when
nobody responds.

## Decisions (confirmed with the user, 2026-09-26)

- **Shape B**: a personal, relevance-filtered stream of chat bubbles, each with a private thread;
  not one public channel (noise, scam audience) and not an AI-only broker (loses people).
- **Thread privacy**: each reply / question / offer is visible only to the poster and its author;
  others see counts only. (Reverses the brainstorm's "no public comment threads" only as far as
  private per-reply threads.)
- **AI nudges once**: one unprompted, labeled AI note about 4 hours after posting if no human has
  replied; otherwise AI speaks only when the user posts or asks.
- **No fabrication**: AI notes are built from real posts and matches; it never invents people,
  reactions, offers or availability.

## Requirements

- C-R1. Posting is one message. It publishes immediately when intent (offer or request) and the item
  category are clear; otherwise the AI asks one short question with quick-reply chips and nothing
  is published until it is answered.
- C-R2. Extracted details show as chips on the bubble (item, price/budget, area, timing, limits);
  missing non-blocking details become optional quick-reply prompts from the assistant.
- C-R3. On posting, the assistant replies in the thread with up to 3 matches (fact-only reasons +
  limitations) or says there is no match and offers "Notify me" and a concrete refinement.
- C-R4. The Market stream shows my messages and other students' live messages that match mine
  (reason shown), falling back to recent live messages when I have none.
- C-R5. On someone else's message I can react (Interested / Still available?), ask a question, or
  make an offer (price + note). Only the poster and I see it; the poster sees counts and all
  replies, and can answer or accept.
- C-R6. Accepting a reply opens a direct chat with that student (existing chat rules: closed when
  the post is done, expired or hidden; block/report available).
- C-R7. Availability: an offer is "confirmed" when the poster posted, edited, replied or tapped
  "Still available" within 3 days; otherwise "needs checking - ask first". Sold, withdrawn,
  expired, hidden and suspended posts never appear.
- C-R8. Every match or stream item states why it is relevant and any limitations (price not stated,
  pickup only, availability unconfirmed, different area).
- C-R9. The assistant nudges once after ~4 hours with no human reply (serve mode), with matches or a
  refinement. AI notes are labeled and only visible to the poster.
- C-R10. Notifications: replies, offers and accepts notify the other party (in-app + batched email);
  reactions and AI notes never email.
- Carried from before: two-way deterministic matching, verified UMich only, blocks, moderation.

## Implementation Units

### C1. Data model: availability, limits, closing reasons, replies, AI notes
- `Post.confirmed_on`, `Post.constraints` (e.g. "pickup only", "must go by 2026-09-10"),
  `Post.closed_reason` ("sold", "withdrawn", "found") alongside `done`.
- `Reply` node (react / question / offer / answer, text, offer price, author, created, accepted),
  on the commons, shared WRITE with exactly the poster and the author.
- `AssistantNote` node (kind: matches / no_match / follow_up / nudge, text, quick replies, created),
  owned by the poster and never shared.
- Pure helpers: `availability(post, today)`, `limitations(post, viewer_post, today)`.
- Tests: availability boundaries, limitation text, reply privacy (served, three students).

### C2. Message intake: `send_market_message(text, reply_to_note?)`
- AI extraction (existing `draft_post`) then rules: blocking gaps (kind or category unclear) return
  a follow-up note with chips and publish nothing; otherwise publish immediately (ai-labeled facts)
  and write the assistant's first note (C4).
- Answering a follow-up chip resends the original text plus the answer.
- No API key: ask kind and category by chips, then publish with the student's own words.
- Tests: clear buy, clear sell, ambiguous ("anyone have a desk?" is a request; "desk" alone asks),
  no-AI fallback.

### C3. Stream and threads
- `market_stream()`: my live messages + matched messages (reason, limitations, availability) +
  recent live fallback; blocked/suspended filtered.
- `message_thread(post_id)`: the post, AI notes (poster only), and the replies the caller may see.
- `react`, `ask`, `make_offer`, `answer_reply`, `accept_reply` (opens a direct chat),
  `confirm_available`, `close_message(reason)`.
- Chat generalization: a Chat keyed by suggestion **or** by accepted reply; open while its post(s)
  are live.
- Tests: privacy (third student sees counts only), accept -> chat, closed post -> read-only,
  confirm refreshes availability.

### C4. Assistant notes and the one-time nudge
- First note on posting: top matches (<= 3) with reasons + limitations, or no-match + refine
  suggestion (LLM-phrased from facts when available, template otherwise) + Notify me / Widen chips.
- Nudge sweep (scheduler, serve mode): once per message, after 4 h with no human reply.
- Tests: note content only references real posts; no nudge when a human replied; exactly once.

### C5. Notifications for replies
- Replies, offers, answers and accepts create inbox items for the other party and join the email
  digest; reactions count only.

### C6. Screens
- `/market`: chat-style stream + composer at the bottom; bubbles with chips and availability badge;
  AI notes as labeled assistant bubbles with quick-reply chips.
- `/market/m?id=`: the thread (poster view: all replies with Answer / Accept; others: their own
  exchange with React / Ask / Offer).
- Keep Chats and My posts; retire the form-first compose (edit details stay available from My posts).

### C7. Validation scenarios (browser + served tests)
Buying, selling, ambiguous request, unavailable (sold/expired) item, no match, delayed human
response (nudge).

## Scope Boundaries

- No public threads; no reactions visible to strangers beyond counts.
- No AI-driven matching or ranking (rules still decide; AI phrases).
- Translation: see Dependencies.

## Dependencies / Assumptions

- `docs/plans/2026-09-26-002-feat-native-language-market-plan.md` (untracked, not yet implemented)
  also changes drafting and chat. Its translation step should plug into C2's intake (translate the
  message before extraction, store translations on the Post) rather than the retired compose form.
- Nudges fire only under `jac run --serve` with the scheduler enabled (like the email digest).
