"""The component inventory from the UMadeIt Figma file (Whole workflow + Phase 2).

One ComponentSpec per variant, resolved against ui/tokens.jac. `built` names the Jac component
that implements it today (ui/components/base.jac or blocks.jac); an empty `built` is still to do.
"""

import from ui.tokens { color, text_style, RADIUS, SIZE }
import from ui.components.specs { ComponentSpec, make_spec }

glob component_specs: list[ComponentSpec] = [
         make_spec(
             "Button",
             "primitive",
             "primary",
             "Full-width primary action.",
             {"width": "100%", "minHeight": f"{SIZE['button-h']}px"},
             {
                 "backgroundColor": color("action"),
                 "color": color("on-action"),
                 "fontSize": text_style("button")["fontSize"],
                 "borderRadius": f"{RADIUS['button']}px"
             },
             ["default", "disabled", "loading"]
         ),
         make_spec(
             "Button",
             "primitive",
             "secondary",
             "Secondary action.",
             {"minHeight": "44px"},
             {
                 "backgroundColor": color("card"),
                 "color": color("action"),
                 "borderColor": color("action-line")
             }
         ),
         make_spec(
             "Button",
             "primitive",
             "compact",
             "Compact map action with an accessible hit area.",
             {"visualHeight": "35px", "minHeight": "44px"},
             {"backgroundColor": color("action"), "color": color("on-action")}
         ),
         make_spec(
             "Button",
             "primitive",
             "text",
             "Low-emphasis text action.",
             {"minHeight": "44px"},
             {"backgroundColor": "transparent", "color": color("action")}
         ),
         make_spec(
             "IconButton",
             "primitive",
             "round-back",
             "Circular back navigation.",
             {"shape": "circle", "minHeight": "44px", "icon": "chevron-left"},
             {
                 "backgroundColor": color("card"),
                 "color": color("text"),
                 "borderColor": color("border-strong")
             }
         ),
         make_spec(
             "Checkbox",
             "primitive",
             "24",
             "Large checklist control.",
             {"size": "24px", "minHeight": "44px"},
             {"accentColor": color("action"), "radius": f"{RADIUS['check']}px"}
         ),
         make_spec(
             "Checkbox",
             "primitive",
             "20",
             "Standard checklist control.",
             {"size": "20px", "minHeight": "44px"},
             {"accentColor": color("action")}
         ),
         make_spec(
             "Checkbox",
             "primitive",
             "18",
             "Compact checklist control.",
             {"size": "18px", "minHeight": "44px"},
             {"accentColor": color("action")}
         ),
         make_spec(
             "Radio",
             "primitive",
             "housing",
             "Radio indicator inside a selectable card.",
             {"size": "20px"},
             {"accentColor": color("action")}
         ),
         make_spec(
             "Chip",
             "primitive",
             "document",
             "Document label chip.",
             {
                 "items": "Passport, I-20, MCard, US phone, Proof of address",
                 "minHeight": "44px"
             },
             {"backgroundColor": color("panel"), "color": color("text-2")},
             ["static", "selected"]
         ),
         make_spec(
             "Badge",
             "primitive",
             "status",
             "Status and metadata pill.",
             {
                 "items": "NEXT ESSENTIAL, RECOMMENDED QUEST, ACTIVE CHALLENGE, Required, 5 min, LVL 2"
             },
             {
                 "backgroundColor": color("action-soft"),
                 "color": color("action"),
                 "fontSize": text_style("badge")["fontSize"],
                 "radius": f"{RADIUS['sm']}px"
             }
         ),
         make_spec(
             "RewardPill",
             "gamification",
             "xp",
             "Experience reward label, text-based with no emoji dependency.",
             {"example": "+50 XP"},
             {
                 "backgroundColor": "transparent",
                 "color": color("progress"),
                 "fontSize": text_style("meta")["fontSize"]
             }
         ),
         make_spec(
             "ProgressBar",
             "primitive",
             "labeled",
             "Progress indicator with optional label row.",
             {"showLabel": "optional", "minHeight": "8px"},
             {"backgroundColor": color("border"), "fillColor": color("action")}
         ),
         make_spec(
             "ProgressDots",
             "primitive",
             "onboarding",
             "Four-step onboarding indicator.",
             {"steps": "4", "activeIndex": "0-based"},
             {"activeColor": color("action"), "inactiveColor": color("border")}
         ),
         make_spec(
             "Avatar",
             "primitive",
             "initials",
             "Initials avatar.",
             {"example": "UM", "size": "40px"},
             {"backgroundColor": color("action-soft"), "color": color("action")}
         ),
         make_spec(
             "Divider",
             "primitive",
             "plain",
             "Subtle horizontal separator.",
             {},
             {"borderColor": color("border")}
         ),
         make_spec(
             "Divider",
             "primitive",
             "labeled",
             "Separator with centered label such as or.",
             {"label": "or"},
             {"borderColor": color("border"), "color": color("sub")}
         ),
         make_spec(
             "SectionLabel",
             "primitive",
             "eyebrow",
             "Uppercase content-region label.",
             {"transform": "uppercase"},
             {"color": color("sub"), "fontSize": text_style("label")["fontSize"]}
         ),
         make_spec(
             "SectionLabel",
             "primitive",
             "step-eyebrow",
             "Indigo, tracked uppercase step label (STEP 2).",
             {"transform": "uppercase", "letterSpacing": "0.15em"},
             {"color": color("action"), "fontSize": text_style("eyebrow")["fontSize"]}
         ),
         make_spec(
             "TextInput",
             "form",
             "with-icon",
             "Labeled text input with a leading icon.",
             {
                 "example": "Flight number",
                 "icon": "plane",
                 "minHeight": f"{SIZE['button-h']}px"
             },
             {
                 "backgroundColor": color("card"),
                 "borderColor": color("border"),
                 "radius": f"{RADIUS['field']}px"
             },
             ["idle", "focused", "invalid"]
         ),
         make_spec(
             "WeekDatePicker",
             "form",
             "seven-day",
             "Date header with edit action and a seven-day strip.",
             {"days": "7", "editAction": "Edit", "minHeight": "44px"},
             {"backgroundColor": color("card"), "accentColor": color("action")}
         ),
         make_spec(
             "SelectableCard",
             "form",
             "radio-option",
             "Housing option with radio, title and description.",
             {"minHeight": "74px"},
             {
                 "backgroundColor": color("card"),
                 "borderColor": color("border"),
                 "selectedBorderColor": color("action")
             },
             ["selected", "unselected"]
         ),
         make_spec(
             "OptionTile",
             "form",
             "language",
             "Large glyph, title and caption for language choice.",
             {"examples": "中文 / EN", "minHeight": "88px"},
             {"backgroundColor": color("card"), "borderColor": color("border")},
             ["selected", "unselected"]
         ),
         make_spec(
             "ChecklistRow",
             "list",
             "task",
             "Checkbox and label with optional XP reward.",
             {"reward": "optional", "minHeight": "56px"},
             {
                 "backgroundColor": color("card"),
                 "color": color("text"),
                 "doneBorderColor": color("action-line")
             },
             ["open", "done"]
         ),
         make_spec(
             "SegmentedControl",
             "form",
             "travel-mode",
             "Travel mode picker.",
             {"options": "Walk, Bus, Bike", "minHeight": "44px"},
             {"backgroundColor": color("panel"), "selectedColor": color("action")}
         ),
         make_spec(
             "OnboardingHeader",
             "layout",
             "welcome",
             "Welcome line, step dots and divider.",
             {"includes": "welcome, progress dots, divider"},
             {"backgroundColor": color("ground"), "color": color("text")}
         ),
         make_spec(
             "QuestionBlock",
             "layout",
             "question",
             "Eyebrow, question title and optional subtitle.",
             {"subtitle": "optional"},
             {
                 "titleFont": text_style("screen-title")["fontFamily"],
                 "color": color("text")
             }
         ),
         make_spec(
             "StickyFooter",
             "layout",
             "primary-action",
             "Pinned primary action with bottom safe-area spacing.",
             {"safeArea": "env(safe-area-inset-bottom)", "minHeight": "64px"},
             {"backgroundColor": color("ground")}
         ),
         make_spec(
             "TopBar",
             "navigation",
             "back-language",
             "Back link and language toggle.",
             {"languageLabel": "中文", "minHeight": "44px"},
             {"backgroundColor": color("ground"), "color": color("text")}
         ),
         make_spec(
             "BottomTabBar",
             "navigation",
             "four-tabs",
             "Primary app navigation.",
             {"items": "Landing Plan, My Guide, Support, Profile", "minHeight": "56px"},
             {"backgroundColor": color("card"), "borderColor": color("border")}
         ),
         make_spec(
             "NavItem",
             "navigation",
             "tab",
             "Label and icon for one bottom navigation destination.",
             {"minHeight": "44px"},
             {"color": color("sub")},
             ["active", "inactive"]
         ),
         make_spec(
             "BottomSheet",
             "layout",
             "map-sheet",
             "Map overlay sheet with grabber and content.",
             {"grabber": "visible", "minHeight": "44px"},
             {"backgroundColor": color("card"), "borderColor": color("border")}
         ),
         make_spec(
             "PageHeader",
             "layout",
             "day",
             "Day title, date and avatar; optional level and XP for maps.",
             {"example": "Day 3 in Ann Arbor", "mapMeta": "optional"},
             {"backgroundColor": color("ground"), "color": color("text")}
         ),
         make_spec(
             "InfoCard",
             "card",
             "plain",
             "Label and explanatory body.",
             {},
             {"backgroundColor": color("card"), "borderColor": color("border")}
         ),
         make_spec(
             "InfoCard",
             "card",
             "map",
             "Where-and-when detail card.",
             {},
             {"backgroundColor": color("card"), "borderColor": color("border")}
         ),
         make_spec(
             "InfoCard",
             "card",
             "advice",
             "Advice card with alert icon.",
             {"icon": "alert"},
             {
                 "backgroundColor": color("warning-bg"),
                 "color": color("warning"),
                 "borderColor": color("accent")
             }
         ),
         make_spec(
             "InfoCard",
             "card",
             "summary",
             "Trip rewards summary box.",
             {},
             {"backgroundColor": color("progress-bg"), "color": color("progress")}
         ),
         make_spec(
             "TaskListItem",
             "list",
             "upcoming",
             "Icon, title, due line and trailing chevron.",
             {"minHeight": "64px"},
             {"backgroundColor": color("card"), "borderColor": color("border")}
         ),
         make_spec(
             "HeroTaskCard",
             "card",
             "next-essential",
             "Featured task with badge, location, bring-list chips and action.",
             {"includes": "badges, title, location, chips, button"},
             {
                 "backgroundColor": color("action"),
                 "color": color("on-action"),
                 "radius": "24px"
             }
         ),
         make_spec(
             "Timeline",
             "list",
             "landing-plan",
             "Vertical route of task stops and walking legs.",
             {"connector": "vertical"},
             {"connectorColor": color("border")}
         ),
         make_spec(
             "TimelineItem",
             "list",
             "stop",
             "Status circle, connector and stop card with duration.",
             {"durationBadge": "optional"},
             {"backgroundColor": color("card"), "borderColor": color("border")},
             ["done", "next"]
         ),
         make_spec(
             "KeyValueRow",
             "list",
             "summary",
             "Aligned label and value row.",
             {"examples": "loot rows, Arrive by, Total XP"},
             {"color": color("text-2"), "borderColor": color("border")}
         ),
         make_spec(
             "MetaRow",
             "list",
             "icon-text",
             "Icon paired with supporting metadata.",
             {"example": "Arriving Aug 28"},
             {"color": color("sub")}
         ),
         make_spec(
             "MapPin",
             "map",
             "states",
             "Map marker for route progress.",
             {"states": "done, active, locked, numbered", "rewardTag": "active only"},
             {
                 "doneColor": color("progress"),
                 "activeColor": color("action"),
                 "lockedColor": color("sub")
             },
             ["done", "active", "locked", "numbered"]
         ),
         make_spec(
             "MapCanvas",
             "map",
             "placeholder",
             "Styled map background placeholder.",
             {"responsive": "true", "minHeight": "280px"},
             {"backgroundColor": color("panel")}
         ),
         make_spec(
             "LocationPill",
             "map",
             "location",
             "Compact current-location indicator.",
             {"minHeight": "44px"},
             {"backgroundColor": color("card"), "color": color("text-2")}
         ),
         make_spec(
             "FromToCard",
             "map",
             "directions",
             "Origin and destination summary.",
             {},
             {"backgroundColor": color("card"), "borderColor": color("border")}
         ),
         make_spec(
             "InstructionBanner",
             "map",
             "turn",
             "Current direction and next-step hint.",
             {"includes": "current turn, next step"},
             {"backgroundColor": color("text"), "color": color("card")}
         ),
         make_spec(
             "LandmarkCard",
             "map",
             "bonus",
             "Landmark photo placeholder, name and bonus.",
             {"photo": "placeholder"},
             {"backgroundColor": color("card"), "borderColor": color("border")}
         ),
         make_spec(
             "ETACard",
             "map",
             "arrival",
             "ETA with end-route and arrived actions.",
             {"actions": "End, I'm here", "minHeight": "44px"},
             {"backgroundColor": color("card"), "color": color("text")}
         ),
         make_spec(
             "StatusPill",
             "map",
             "arrived",
             "Arrival confirmation status.",
             {"label": "You've arrived"},
             {"backgroundColor": color("progress-bg"), "color": color("progress")}
         ),
         make_spec(
             "ImageHeader",
             "map",
             "entrance",
             "Photo placeholder for destination entrance.",
             {"image": "placeholder", "aspectRatio": "16/9"},
             {"backgroundColor": color("panel")}
         ),
         make_spec(
             "NextStopCard",
             "map",
             "next-stop",
             "Next destination and action summary.",
             {},
             {"backgroundColor": color("card"), "borderColor": color("border")}
         ),
         make_spec(
             "StreakIndicator",
             "gamification",
             "days",
             "Text-and-icon streak status, never emoji-only.",
             {"icon": "flame-outline"},
             {"backgroundColor": color("warning-bg"), "color": color("accent-ink")}
         ),
         make_spec(
             "LevelBadge",
             "gamification",
             "level",
             "Current player level pill.",
             {"example": "LVL 2"},
             {"backgroundColor": color("action"), "color": color("on-action")}
         ),
         make_spec(
             "Modal",
             "overlay",
             "scrim",
             "Dialog surface over a scrim.",
             {"role": "dialog", "minHeight": "44px"},
             {"scrimColor": color("scrim"), "backgroundColor": color("card")},
             ["open", "closed"]
         ),
         make_spec(
             "BadgeCelebration",
             "gamification",
             "dialog",
             "Full dialog celebrating a badge unlock.",
             {"presentation": "dialog"},
             {"backgroundColor": color("card"), "accentColor": color("action")}
         ),
         make_spec(
             "BadgeCelebration",
             "gamification",
             "inline",
             "Compact inline badge-unlocked celebration.",
             {"presentation": "inline"},
             {"backgroundColor": color("progress-bg"), "color": color("progress")}
         ),
         make_spec(
             "OfficialBadge",
             "trust",
             "publisher-review",
             "Publisher, review date and shield icon for official guidance.",
             {"icon": "shield", "publisher": "required", "reviewDate": "required"},
             {"backgroundColor": color("official-bg"), "color": color("official")}
         ),
         make_spec(
             "AIGeneratedLabel",
             "trust",
             "ai-generated",
             "Explicit label for AI-generated content.",
             {"label": "AI-generated"},
             {"backgroundColor": color("ai-bg"), "color": color("ai")}
         ),
         make_spec(
             "UrgentHelpPill",
             "navigation",
             "top-bar",
             "Persistent urgent-help action for top bars.",
             {"label": "Urgent help", "minHeight": "44px"},
             {"backgroundColor": color("urgent"), "color": color("on-urgent")}
         )
     ],
     BUILT: dict[str, str] = {
         "Button": "base.Button",
         "Badge": "base.Badge",
         "OfficialBadge": "base.Badge",
         "AIGeneratedLabel": "base.Badge",
         "TextInput": "base.Field",
         "BottomTabBar": "base.AppShell",
         "NavItem": "base.AppShell",
         "SectionLabel": "blocks.SectionLabel",
         "QuestionBlock": "blocks.QuestionBlock",
         "ProgressDots": "blocks.ProgressDots",
         "ProgressBar": "blocks.ProgressBar",
         "Radio": "blocks.SelectableCard",
         "SelectableCard": "blocks.SelectableCard",
         "OptionTile": "blocks.OptionTile",
         "Checkbox": "blocks.ChecklistRow",
         "ChecklistRow": "blocks.ChecklistRow",
         "RewardPill": "blocks.RewardPill",
         "Avatar": "blocks.Avatar",
         "InfoCard": "blocks.InfoCard",
         "Timeline": "blocks.TimelineItem",
         "TimelineItem": "blocks.TimelineItem",
         "Chip": "blocks.Chip",
         "SegmentedControl": "blocks.SegmentedControl",
         "KeyValueRow": "blocks.KeyValueRow",
         "LevelBadge": "blocks.LevelBadge",
         "TopBar": "blocks.TopBar",
         "MapPin": "map.MapPin",
         "MapCanvas": "map.MapCanvas"
     };

# Figma component name -> the Jac component that implements it.
"""Component names from the Figma inventory that no Jac component implements yet."""
def todo_components -> list[str] {
    names: list[str] = [];
    for spec in component_specs {
        if spec.name not in BUILT and spec.name not in names {
            names.append(spec.name);
        }
    }
    return names;
}

def get_component_specs(family: str = "") -> list[ComponentSpec] {
    if family == "" {
        return component_specs;
    }
    return [
        spec
        for spec in component_specs
        if spec.family == family
    ];
}

test "every built component is in the Figma inventory" {
    names = [spec.name for spec in component_specs];
    for name in BUILT {
        assert name in names , name;
    }
}

test "specs resolve to the default theme's tokens" {
    button = [
        s
        for s in component_specs
        if s.name == "Button" and s.variant == "primary"
    ][0];
    assert button.styles["backgroundColor"] == color("action");
    assert button.props["minHeight"] == "52px";
    assert len(get_component_specs("trust")) == 2;
}

test "the to-do list skips built components" {
    todo = todo_components();
    assert "Button" not in todo;
    assert "MapPin" not in todo;
    assert "BottomSheet" in todo;
}
