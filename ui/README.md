# ui/ — design system (single source of UI truth, owned by the UI lead / both feature leads)

```
ui/
├── tokens.jac      # the ONLY place colors, spacing, radii, font sizes and breakpoints are defined
├── components/     # Button, Card, TaskCard, ListingCard, Field, Badge, Layout, Nav, HelpButton...
└── copy/           # shared strings (labels, safety text, "AI-generated" label) for translation
```

`tokens.jac` mirrors the **UArrived Design System** artifact
(https://claude.ai/artifact/JkrWSa8iv9NXiRKsj9s2Wh) — change both together. Themes: `harbor`
(default), `arboretum`, `nightfall`, all with the same color names. API:
`color("action", theme)`, `text_style("body")`, `space("4")`, `RADIUS`, `SIZE`, `FONTS`, and
`contrast(fg, bg)`; a test keeps every reading-text pair at WCAG AA 4.5:1 in every theme.

Feature screens compose `ui/components` and read `ui/tokens`. If a screen needs something that is
not there, add it here in its own PR first. Web is the primary target: **mobile-first responsive**
layouts, then sPrimitives
Button: primary full-width (Next question, Build my plan, Mark as done, Start directions, Continue Journey), secondary (Directions, See whole trip, End), compact (Go, I'm here), and text (Back to Home).
IconButton: the round Back button and the back chevron in the map header.
Checkbox and Radio: checkboxes appear at 24, 20 and 18px. The radio is the dot inside the housing cards.
Chip: document chips (Passport, I-20, MCard, US phone, Proof of address), with static and selectable versions.
Badge: status and label pills (NEXT ESSENTIAL, RECOMMENDED QUEST, ACTIVE CHALLENGE, Required, "5 min" durations, LVL 2).
RewardPill: "+50 XP" and similar. It appears on almost every gamified screen, so it's worth its own component.
ProgressBar: essentials done, the XP tracker, and level progress (with or without a label row).
ProgressDots: the 4-step onboarding indicator.
Avatar: initials ("UM").
Divider: plain, and with a label ("or").
SectionLabel: uppercase region names (WHY YOU NEED IT, BRING WITH YOU).
Form controls
TextInput with an icon: the flight number field.
WeekDatePicker: date header with Edit, plus a 7-day strip.
SelectableCard: radio, title and description (housing options).
OptionTile: a large glyph with title and caption (中文 / EN language choice).
ChecklistRow: checkbox and label, optionally with an XP reward on the right. Used in onboarding, task detail and the document challenge.
SegmentedControl: travel mode (Walk, Bus, Bike).
Layout and navigation
OnboardingHeader: welcome line, progress dots and divider.
QuestionBlock: eyebrow, title and optional subtitle.
StickyFooter: primary button plus the bottom safe area. It's on 7 screens.
TopBar: back link and language toggle (the "中文" in task detail).
BottomTabBar and NavItem: Landing Plan, My Guide, Support, Profile.
BottomSheet: grabber and content. It's on 5 map screens.
PageHeader: "Day 3 in Ann Arbor", the date and avatar. The map version adds level and XP.
The status bar and home indicator are just phone frame details and don't need to be built.
Cards and lists
InfoCard: a label and body. Variants: plain (Why you need it), map (Where & when), advice (with an alert icon), and summary (Trip rewards, the bonus box).
TaskListItem: icon, title, due line and chevron (the "Coming up" items).
HeroTaskCard: badge row, title, location, bring-list chips and a button (Next essential).
Timeline and TimelineItem: status circle, connector line and a card with a duration badge (Your landing plan). The numbered stops in "Today's trip" and their walking legs can be a variant of this component.
KeyValueRow: label on the left, value on the right (loot rows, Arrive by, Total XP).
MetaRow: icon plus meta text (calendar with "Arriving Aug 28").
Map and gamification
MapPin: done, active (pulsing, with a reward tag), locked, and numbered.
MapCanvas: the map background placeholder.
LocationPill and FromToCard.
InstructionBanner: current turn plus the next step.
LandmarkCard: photo, landmark text and bonus.
ETACard: ETA with End and I'm here buttons.
StatusPill: "You've arrived".
ImageHeader: the entrance photo placeholder.
NextStopCard.
StreakIndicator and LevelBadge.
Modal with scrim, and BadgeCelebration in two forms: the full dialog on the badge screen, and the inline card on the arrived screen.
Where the wireframes and the design system disagree

These are worth settling before we build:

Missing components the design system requires. The design system calls for an Urgent help pill in the top bar of every screen, an Official badge (shield icon, publisher, review date), and an AI-generated label. None of these are in the wireframes. Task detail and "Advice from older students" are exactly where Official vs. student advice matters.
Emoji. Rewards and streaks use 🔥 and 🏦. The design system specifies stroke icons and says the icon never carries meaning alone.
Tap targets under 44px. The Go button is 35px, the back icon 28px, the challenge checklist rows 38px, and chips 23–30px.
Frame widths. Screens are drawn at 402px and 390px (the N1–N4 screens), while the design system says to design at 360px first.
Completion wording. After a task is done, the status should read "Marked done by you", not something that sounds official.

I'd build the primitives first, then StickyFooter, BottomSheet, ChecklistRow, Timeline and InfoCard. Those five cover most of the screens.cale up to desktop.
