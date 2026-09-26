# ui/ — design system (single source of UI truth, owned by the UI lead / both feature leads)

```
ui/
├── tokens.jac      # the ONLY place colors, spacing, radii, font sizes and breakpoints are defined
├── components/     # Button, Card, TaskCard, ListingCard, Field, Badge, Layout, Nav, HelpButton...
└── copy/           # shared strings (labels, safety text, "AI-generated" label) for translation
```

Feature screens compose `ui/components` and read `ui/tokens`. If a screen needs something that is
not there, add it here in its own PR first. Web is the primary target: **mobile-first responsive**
layouts, then scale up to desktop.
