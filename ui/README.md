# ui/ — design system (single source of UI truth, owned by the UI lead / both feature leads)

```
ui/
├── tokens.jac      # the ONLY place colors, spacing, radii, font sizes and breakpoints are defined
├── components/     # Button, Card, TaskCard, ListingCard, Field, Badge, Layout, Nav, LogoutButton...
└── copy/           # shared strings (labels, safety text, "AI-generated" label) for translation
```

`tokens.jac` follows the **UMadeIt Figma file**
(https://www.figma.com/design/jw2I3dqHMAnZGqKBvDlmyl/UArrived) — change both together. The default
theme `campus` is the Figma look: stone neutrals (`#F5F5F3` ground, `#1C1917` text, `#E7E5E4`
hairlines), indigo `#3730A3` action, **Outfit** headings over **Manrope** text, 16px card and button
radius, 52px primary buttons. One deliberate difference: Figma's secondary gray `#87807B` fails WCAG
AA on the ground, so `sub` is darkened to `#716A64`. The earlier Design System artifact themes
(`harbor`, `arboretum`, `nightfall`) stay as alternates with the same color names. API:
`color("action", theme)`, `text_style("body")`, `space("4")`, `RADIUS`, `SIZE`, `FONTS`, and
`contrast(fg, bg)`; a test keeps every reading-text pair at WCAG AA 4.5:1 in every theme.

Feature screens compose `ui/components` and read `ui/tokens`. If a screen needs something that is
not there, add it here in its own PR first. Web is the primary target: **mobile-first responsive**
layouts, then scale up to desktop.

## Base components (`ui/components/base.jac`)

| Component | Use |
|---|---|
| `AppShell(title, active, children, wide)` | Every screen: top bar with wordmark + Log out, content column, bottom nav (`today`, `journey`, `housing`, `market`, `profile`). `wide` raises the column from 720px to `SIZE["content-max"]` for card-grid or list+detail screens |
| `Button(label, onClick, variant, disabled, button_type, full)` | `primary` = the one filled action per screen; `secondary`; `text` |
| `Card(children)` | Content surface: card background, hairline, card radius |
| `ResponsiveGrid(children, min)` | Card list that reflows by available width: 1 column on phone, more `min`-wide columns as space allows |
| `Badge(kind, label)` | `official`, `ai`, `progress`, `warning`: always with a word |
| `Field(label, value, onChange, input_type, hint, multiline, placeholder)` | Labeled input or textarea, 16px text, 44px tall |
| `LogoutButton` | Always-visible sign-out control in the header |

Badge kinds also include `action` (NEXT ESSENTIAL, "20 min") and `neutral`.

## Figma blocks (`ui/components/blocks.jac`)

| Component | Figma use |
|---|---|
| `SectionLabel(label, tone)` | WHY YOU NEED IT, WHAT TO BRING |
| `QuestionBlock(eyebrow, title, subtitle)` | Onboarding STEP N + question |
| `ProgressDots(steps, current)` | 4-step onboarding indicator |
| `ProgressBar(done, total, label)` | "3 of 6 essentials done", level progress |
| `SelectableCard(title, description, selected, onSelect)` | Housing radio cards |
| `OptionTile(glyph, title, caption, selected, onSelect)` | 中文 / EN language choice |
| `ChecklistRow(label, checked, onToggle, reward)` | Onboarding checklist, document challenge |
| `RewardPill(label)` | "+50 XP" (text, never emoji-only) |
| `Avatar(initials)` | "UM" |
| `InfoCard(label, variant, children)` | `plain` info, `advice` (older students, amber) |
| `TimelineItem(title, meta, duration, status)` | Landing plan stops (`done` / `next`) |
| `Chip(label, selected, onSelect)` | Document chips (static) or filter chips (with `onSelect`, 44px, ✓ when selected) |
| `SegmentedControl(options, value, onChange, label)` | Map / List switch |
| `KeyValueRow(label, value)` | Address, Hours, Cost rows |
| `LevelBadge(level)` | "LVL 2" |
| `TopBar(back_href, back_label)` | Back link above a detail screen |

## Map (`ui/components/map.jac`)

| Component | Use |
|---|---|
| `MapCanvas(pins, center, bounds, start_zoom, height)` | Pannable OpenStreetMap view (drag, +/−, back to campus). Pins come pre-projected to Web Mercator world pixels at zoom 18 (`wx`, `wy`), so the client needs no map library or key |
| `MapPin(label, href, state, left, top, count)` | A labelled link pin: `done` (green, ✓), `active` (indigo), `optional` (stone), `event` (indigo with a count) |

## Figma inventory (`ui/components/catalog.jac`)

Every component the Figma screens use, one token-resolved `ComponentSpec` per variant.
`BUILT` maps each to its Jac component; `todo_components()` lists what is still to build (map
pins, bottom sheet, sticky footer, top bar, hero task card, badge celebration, ...).

### Where the Figma file and the design rules disagree

- **Official badge, AI-generated label** are required by the design rules but are not drawn in
  Figma. Task detail and "Advice from older students" are where Official vs. student advice
  matters most.
- **Emoji** (🔥 streak, 🏦 badge) carry meaning in Figma; components use words plus stroke icons.
- **Tap targets under 44px** in Figma (Go 35px, back icon 28px, challenge rows 38px, chips 23–30px);
  components keep a 44px minimum.
- **Frame width** is 402px in Figma; the rule is design at 360px first.
- **Completion wording:** a done task reads "Marked done by you", never something that sounds official.
| `BaseStyles` | Page background, fonts, focus ring, reduced motion (included by `AppShell`) |

See them all at `/ui` in the running app (`UARRIVED_DEV_MODE=1 jac run main.jac`).
Don't name a prop `type`: in client code it breaks the rendered attribute (use `input_type` / `button_type`).
