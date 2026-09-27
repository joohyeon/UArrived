---
date: 2026-09-26
topic: arrival-story-native-language-market
extends: docs/brainstorms/2026-09-26-001-drop-a-message-marketplace-requirements.md
---

# Arrival Story: Ji-woo's First Two Weeks (and Native-Language Posting)

## Summary

A judge-facing user story that follows one international transfer student from two weeks before
their DTW landing to the end of their first week in Ann Arbor, using the drop-a-message marketplace
for a shared ride, a sublet and used furniture. The story adds one capability to the marketplace
spec: students write posts and chat in their own language, and the AI keeps the key facts safe
across languages. It ships with a storyboard and a clickable phone prototype built on the UArrived
design system.

---

## Problem Frame

**Ji-woo Han** (fictional composite; she/her) is 21, transferring from a university in Seoul into
the University of Michigan as a junior in Computer Science. Transfer students are not required to
live in residence halls, so she has to find her own housing. She has never been to Michigan, has no
US phone number until she buys a SIM, no car, and no friends in Ann Arbor. Her English is good for
class but slow and tiring for negotiating a lease or haggling over a used desk.

Two weeks before her flight (landing DTW **Aug 20, 3:10pm**), this is her situation:

- **Ride.** DTW is about 40 minutes from campus. A rideshare is roughly $60–90 alone; the airport
  bus needs a transfer and she will have two 23kg suitcases. A Korean Student Association KakaoTalk
  group has 400 members and a pinned "who's arriving when?" thread that scrolls past in a day.
- **Housing.** She needs a room from Aug 20 through the spring. Group-chat sublet posts are photos
  and a price, often missing lease dates. A friend of a friend lost a $1,200 "deposit" wired to a
  stranger for a sublet that didn't exist. She can't view any place in person.
- **Stuff.** The room is unfurnished. Departing seniors are dumping desks, bed frames and lamps on
  the curb or in WeChat groups the week she lands, and the good ones go within hours.

Each need lives in a different group chat, in a mix of Korean and English, and every one depends on
being online at the right hour. The marketplace spec (001) already solves the matching and safety
shape. What it doesn't cover is that Ji-woo's most natural way to write "I need a room near North
Campus from Aug 20, under $900, no smoking" is in Korean.

---

## Actors

- A1. Ji-woo (arriving student): international transfer junior; posts in Korean, reads English slowly.
- A2. Marcus (ride match): domestic grad student landing DTW 3:45pm the same day, also heading to North Campus.
- A3. Priya (sublet poster): a senior leaving for a co-op; subletting her room in a 3-bedroom near North Campus, posts in English.
- A4. Wei (furniture seller): a departing Chinese PhD student selling a desk, chair and lamp; posts in Chinese.
- A5. AI assistant: drafts, translates, explains matches, flags missing info and risk patterns. Never decides who matches.

---

## The Story (storyboard scenes)

Each scene is one storyboard panel and maps to one prototype screen.

1. **Aug 6, Seoul, 11pm. Three group chats, zero answers.** Ji-woo scrolls three chats looking for
   a ride, a room and a desk. Her own "anyone landing DTW Aug 20?" message was buried by 60 new ones.
2. **Aug 6. One message, in Korean.** In UArrived, the journey's "Plan your ride from DTW" task
   offers to find students arriving the same day. She types instead, in Korean: *"8월 20일 오후 3시
   DTW 도착, 짐 2개. 노스캠퍼스로 같이 갈 사람? 그리고 8월 20일부터 방 구해요, 900불 이하, 노스
   근처. 책상이랑 침대도 필요해요."* (Arriving DTW Aug 20 3pm, 2 bags, anyone going to North
   Campus? Also need a room from Aug 20 under $900 near North, and a desk and bed.)
3. **The AI splits it into three drafts, shown in both languages.** A ride request, a housing
   request, and a furniture request. Each draft shows price, dates and area as fields labeled in
   Korean, with the English post text underneath and an "AI-generated" label. The AI marks
   "move-out date" as guessed ("through April?"). She fixes it to May 1 and taps Post on all three.
4. **Aug 8. Two sublets, one warning.** Her matches inbox has two sublet suggestions. She taps
   *Help me decide*. Side by side, in Korean: Priya's room lists lease dates, landlord name and a
   video tour. The other has no dates and asks for a deposit by wire before a viewing. The AI flags
   "deposit before viewing is a common scam pattern" and suggests three questions to ask. It does not
   say either post is safe.
5. **Aug 9. Connect, and a chat that speaks both languages.** Both Ji-woo and Priya tap Connect.
   Ji-woo writes in Korean; Priya reads English and replies in English; Ji-woo reads Korean. Every
   translated message is labeled and has "See original". Dollar amounts and dates show exactly as
   typed. They agree on a video call with the landlord.
6. **Aug 17. "Lands 35 minutes after you."** Marcus posts a ride request for the same afternoon.
   Both get the suggestion: *"Lands 35 min after you at DTW, both going to North Campus."* They
   connect, agree to split a rideshare in person, and the app shows ride safety guidance.
7. **Aug 20, 4:20pm. DTW baggage claim.** They meet at the carousel, share the ride, and Ji-woo
   marks her ride post Done. Total cost for her: half of one rideshare.
8. **Aug 22. A desk in Chinese, bought in Korean.** Wei's post was written in Chinese: desk, chair
   and lamp for $40, pickup Aug 21–25. It matched Ji-woo's furniture request: *"Within your budget,
   pickup overlaps your move-in, 10 min from your area."* Wei's Chinese and Ji-woo's Korean are each
   translated for the other. Ji-woo picks it up with Marcus's help, pays cash, and Wei marks the post
   Done. The bed request stays live.

**The end card:** one Korean message in Seoul → a ride partner, a verified sublet, a furnished
desk, without scrolling a group chat.

---

## Requirements

These extend the marketplace spec (001). R-IDs continue from it.

**Posting in your own language**
- R22. A student can write their message in any language; the AI detects it and drafts the post
  without asking the student to choose a language first.
- R23. The draft card shows the structured fields (category, offer or request, price, dates, area)
  with labels in the poster's language, and the post text in both the poster's language and English.
  The poster confirms the draft as today (R3).
- R24. Prices, dates, times and areas are shown as structured values everywhere a post appears, not
  as translated prose, so a translation cannot change them.
- R25. One message that describes several needs becomes separate drafts, one per post; the poster
  confirms or discards each one.

**Reading and chatting across languages**
- R26. Every viewer sees posts in their own language, with a "See original" control and an
  "AI-translated" label.
- R27. Chat messages are translated into each reader's language, labeled "AI-translated", with a
  "See original" control on every translated message. The sender always sees their own words.
- R28. Match reasons (R7) and Help me decide results (R14) are shown in the reader's language.
- R29. A student sets their language in Profile; the first-run default is the language of their
  first message.

**Demo artifact**
- R30. A storyboard strip of the eight scenes above, each with a one-line caption and a small
  picture of the moment.
- R31. A clickable phone prototype that walks scenes 2–8: drop a message, bilingual drafts, matches
  inbox, Help me decide, Connect, translated chat, mark Done.
- R32. The prototype uses only the Harbor theme tokens and the component specs from the
  design-components branch (Button, Badge, Chip, InfoCard, TaskListItem, BottomTabBar, StickyFooter,
  AIGeneratedLabel, OfficialBadge, UrgentHelpPill, and so on). Marketplace pieces missing from the
  set are built from tokens and listed as proposed components.

---

## Acceptance Examples

- AE8. **Covers R22, R23, R25.** Given Ji-woo types scene 2's Korean message, when the drafts appear,
  there are three drafts (ride request, housing request, furniture request), each with Korean field
  labels, Korean and English text, and the housing end date marked as guessed.
- AE9. **Covers R24, R26.** Given Wei's Chinese post says "书桌椅子台灯 $40, 8月21–25日自取", when
  Ji-woo views it, the price reads $40 and the dates Aug 21–25 as fields, with the description in
  Korean and a "See original" control.
- AE10. **Covers R27.** Given Priya sends "Can you do a video call Thursday 7pm EST?", when Ji-woo
  reads it, she sees a Korean translation labeled AI-translated, and tapping "See original" shows the
  English text; Priya's own view shows only her English.
- AE11. **Covers R28, R14.** Given the two sublets in scene 4, when Ji-woo asks Help me decide, the
  comparison and the "deposit before viewing" warning are in Korean, and neither post is called safe.

---

## Success Criteria

- A judge who watches the storyboard and taps through the prototype can retell the story in one
  sentence: one message in your own language gets you a ride, a room and a desk, without a group chat.
- Every prototype screen is built from the design-system tokens and components, and any new
  component is named so the UI lead can add it.
- Planning can add native-language posting and chat to the existing marketplace engine without
  inventing behavior for translation labels, key-fact handling or language defaults.

---

## Scope Boundaries

- Matching stays language-blind: rules match on structured fields, never on the text's language.
- No voice input or live call translation.
- No translation of photos or images (e.g. a lease screenshot) in v1.
- No payments, lease signing or ratings (unchanged from 001).
- Ji-woo, Marcus, Priya and Wei are fictional; no real student's data or story appears.
- The prototype is a static demo with scripted data, not the running Jac app.

---

## Key Decisions

- Story starts two weeks before landing: finding housing from abroad, with a scam check, is the
  realistic and safe path, and it keeps the app from reading as a crisis tool.
- Native-language posting is the hero AI moment: it is what an international student can't get from
  a group chat, and it reuses the draft-then-confirm step the spec already requires.
- Key facts stay as structured fields across languages: a mistranslated price or date is the most
  harmful translation error in a marketplace.
- Transfer student, not a freshman: freshmen usually live in residence halls, which would remove the
  housing scene.
- Proposed as additions (R22–R32) in a companion doc rather than edits to 001, so the marketplace
  spec stays stable while the team decides.

---

## Dependencies / Assumptions

- Assumes (as 001 does, unverified) that admitted transfer students can verify an @umich.edu address
  before arriving. The story shows Ji-woo already verified.
- Translation is not built yet: `ai/README.md` names translate as a planned helper, but no Jac code
  implements it (checked 2026-09-26).
- The design-components branch specs were drawn for the journey feature; marketplace-specific pieces
  (draft card, match card, chat bubble, compare table) are not in it.

---

## Outstanding Questions

### Resolve Before Planning

- (none)

### Deferred to Planning

- [Affects R22, R27][Technical] Which model does translation, and how is a translation cached so a
  message isn't retranslated on every read?
- [Affects R24][Technical] How key-fact fields are extracted from other languages (e.g. "900불",
  "8月21日") and checked against the text before the poster confirms.
- [Affects R29][User decision, can wait] Which languages the pilot supports and advertises (Korean,
  Chinese and English at minimum for the demo).
- [Affects R32][Needs research] Whether the proposed marketplace components go into `ui/` in the
  design-components branch or a follow-up PR.
