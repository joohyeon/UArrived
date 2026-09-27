"""A student's picked interest categories for personalized events (U2, plan 2026-09-27-003).

One `Interests` node per student on their own root, following journey/walkers.jac's `TaskProgress`
shape: set once at the post-signup interest gate (U3) and read by the events screen's
personalization (U5). Categories come from journey.constants.EVENT_CATEGORIES -- the same taxonomy
the events screen already filters by -- so the picker and the filter never drift apart.
"""

import from journey.constants { EVENT_CATEGORIES }

node Interests {
    has categories: list[str] = [];
}

"""The caller's own Interests node, or None if they've never set any."""
def my_interests_node -> Interests | None {
    for i in [root-->][?:Interests] {
        return i;
    }
    return None;
}

"""The caller's picked interest categories, or [] if they've never set any."""
def my_interests -> list[str] {
    rec = my_interests_node();
    return rec.categories if rec else [];
}

"""True once the caller has picked interests."""
def has_interests -> bool {
    return my_interests_node() is not None;
}

"""Set the caller's interests to `categories` (filtered to known EVENT_CATEGORIES), overwriting
any previous pick rather than accumulating a second node. Returns what was actually saved."""
def set_interests(categories: list[str]) -> list[str] {
    valid = [
        c
        for c in categories
        if c in EVENT_CATEGORIES
    ];
    existing = my_interests_node();
    if existing {
        existing.categories = valid;
    } else {
        root ++> Interests(categories=valid);
    }
    return valid;
}

test "an unset student has no interests" {
    assert my_interests_node() is None;
}

test "setting interests filters out unknown categories and can be read back" {
    saved = set_interests(["Arts", "Social", "Not-A-Real-Category"]);
    assert saved == ["Arts", "Social"];
    assert my_interests() == ["Arts", "Social"];
    assert has_interests();
}

test "setting interests a second time overwrites rather than accumulating a node" {
    set_interests(["Arts"]);
    set_interests(["Sports", "Careers"]);
    assert my_interests() == ["Sports", "Careers"];
    assert len([i for i in [root-->][?:Interests]]) == 1;
}
