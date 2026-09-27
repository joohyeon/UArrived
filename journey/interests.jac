"""A student's picked interest categories for personalized events (U2, plan 2026-09-27-003).

One `Interests` node per student on their own root, following journey/walkers.jac's `TaskProgress`
shape: set once at the post-signup interest gate (U3) and read by the events screen's
personalization (U5). Categories come from journey.constants.INTEREST_CATEGORIES -- the same list
the picker screen offers -- so a saved interest can always match a real event's category.
"""

import from journey.constants { INTEREST_CATEGORIES }

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
def:protect my_interests -> list[str] {
    rec = my_interests_node();
    return rec.categories if rec else [];
}

"""True once the caller has picked interests."""
def:protect has_interests -> bool {
    return my_interests_node() is not None;
}

"""Set the caller's interests to `categories` (filtered to INTEREST_CATEGORIES and de-duplicated,
order preserved), overwriting any previous pick rather than accumulating a second node. Returns
what was actually saved."""
def:protect set_interests(categories: list[str]) -> list[str] {
    valid: list[str] = [];
    for c in categories {
        if c in INTEREST_CATEGORIES and c not in valid {
            valid.append(c);
        }
    }
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

test "'All' and 'Other' are rejected -- they can never match a real event's category" {
    saved = set_interests(["All", "Arts", "Other"]);
    assert saved == ["Arts"];
}

test "duplicate picks are collapsed, order preserved" {
    saved = set_interests(["Arts", "Social", "Arts"]);
    assert saved == ["Arts", "Social"];
}

test "skipping with no picks still persists has_interests() -- the whole point of a one-time gate" {
    assert not has_interests();
    saved = set_interests([]);
    assert saved == [];
    assert has_interests() , (
        "a student who skips must not be re-prompted on every future visit to Today"
    );
    assert my_interests() == [];
}
