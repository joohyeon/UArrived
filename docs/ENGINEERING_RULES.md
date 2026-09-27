# Engineering rules (hard rules — enforced by `scripts/check_rules.sh` in CI)

UMadeIt is a **web app first** (mobile-first responsive, runs in any phone or desktop browser),
built with **Jac** end to end: the graph, the walkers *and* the UI (`.jac` JSX). A native mobile app
is out of scope for the MVP.

## The rules

| # | Rule | Enforced by |
|---|------|-------------|
| 1 | **Jac ≥ 40% of hand-written source, by bytes** (team target 60%). Counted: `.jac`, `.py`, `.js/.jsx/.ts/.tsx`, `.css`, `.html`. Not counted: `data/`, `docs/`, `public/`, `scripts/`, `.github/`, lockfiles, `node_modules`, generated files. | CI fails under 40%, warns under 50% |
| 2 | **Non-Jac source lives only in `interop/`**. No hand-written `.py/.js/.ts/.css/.html` anywhere else. Styling is Jac + tokens, not stylesheets. | CI |
| 3 | **Journey (A) and Market (B) never import each other.** Shared things go in `core/`, `ui/`, or `ai/`. | CI |
| 4 | **One design language.** No raw colors (`"#…"`, `rgb()`, `hsl()`) in features; colors, spacing, radii, type scale and breakpoints come from `ui/tokens.jac`. Screens compose `ui/components`; missing component → add it to `ui/` in its own PR. | CI (colors) + review |
| 5 | **Rules are deterministic.** Task applicability, prerequisites and eligibility live in `journey/walkers.jac` + `data/`; they never import `ai/`. AI only explains, summarizes, translates and drafts, and is always labeled. | CI (imports) + review |
| 6 | **Contracts first.** `core/` (graph model) and `ui/` (tokens + components) change in their own small PR, approved by **both** feature owners, before feature code depends on them. | CODEOWNERS |
| 7 | **Every behaviour has a test** (`test "what it proves" { ... }`, run with `jac test <files>`). Required suites: task applicability, prerequisite order, listing matching, and user progress ≠ official completion. | review + CI |
| 8 | **Official guidance carries a publisher and a review date**; changes to `data/tasks` and `data/resources` need the trust/content owner. | CODEOWNERS |
| 9 | **Mobile-first web.** Design at ~360 px wide first, then scale up; touch targets ≥ 44 px; every screen usable one-handed. | review (screenshot in PR) |
| 10 | **No payments, lease signing, or precise-location collection** in the MVP. | review |

To keep the Jac share healthy: write logic in Jac before reaching for Python, use `jac guide` for
current syntax (`jac guide jac-essentials`), and treat an `interop/` file as debt to shrink.

## Who owns what

| Area | Folder(s) | Owner |
|---|---|---|
| Feature A — First-Week Journey | `journey/`, `data/tasks`, `data/resources` | Feature A lead |
| Feature B — Marketplace | `market/` | Feature B lead |
| Shared graph model | `core/` | both leads |
| Design system | `ui/` | UI lead (both leads review) |
| AI helpers | `ai/` | whoever needs it; both review |

Work split: A and B can build in parallel once M1 lands the shared model and design system.
Each feature ships its own screens end to end (graph → walkers → screens → tests), so nobody waits
on a "backend person" or a "frontend person".

## Milestones

1. **M1 Foundations** — `jac create --kind web-app` shell at the repo root, `core/` model, `ui/tokens` + 6 base components, sample data. *Blocks both features; do it together, first.*
2. **M2 Vertical slice** — A: onboarding → personalized tasks → milestone completion. B: Housing Hub → post + match a furniture item. In parallel.
3. **M3 Pilot hardening** — reporting/moderation/expiry, urgent-help entry, safety copy, translations.
