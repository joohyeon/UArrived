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
layouts, then scale up to desktop.

## Base components (`ui/components/base.jac`)

| Component | Use |
|---|---|
| `AppShell(title, active, children)` | Every screen: top bar with wordmark + Urgent help, content column, bottom nav (`today`, `journey`, `housing`, `market`, `profile`) |
| `Button(label, onClick, variant, disabled, button_type, full)` | `primary` = the one filled action per screen; `secondary`; `text` |
| `Card(children)` | Content surface: card background, hairline, card radius |
| `Badge(kind, label)` | `official`, `ai`, `progress`, `warning`: always with a word |
| `Field(label, value, onChange, input_type, hint, multiline, placeholder)` | Labeled input or textarea, 16px text, 44px tall |
| `HelpButton` | Urgent help; `urgent` color means nothing else |
| `BaseStyles` | Page background, fonts, focus ring, reduced motion (included by `AppShell`) |

See them all at `/ui` in the running app (`UARRIVED_DEV_MODE=1 jac run main.jac`).
Don't name a prop `type`: in client code it breaks the rendered attribute (use `input_type` / `button_type`).
