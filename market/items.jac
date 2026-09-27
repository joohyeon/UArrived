"""Standard item names (plan 2026-09-27-001 U1): map a post to one item from STANDARD_ITEMS so
topic groups key on the thing, not the wording. The AI's choice is used when it is on the list
for the post's final category; otherwise the title is matched against the synonyms. Rules code:
no AI here."""

import re;
import from market.constants { STANDARD_ITEMS }

"""The listed item whose synonym ends latest in `text` ("Desk chair" -> chair, the head noun);
ties go to the longer synonym. "" when nothing matches."""
def item_from_text(category: str, text: str) -> str {
    words = " " + " ".join(re.findall(r"[a-z0-9-]+", text.lower())) + " ";
    best = "";
    (best_end, best_len) = (-1, 0);
    for (item, synonyms) in STANDARD_ITEMS.get(category, {}).items() {
        for syn in synonyms {
            at = words.rfind(" " + syn + " ");
            if at < 0 {
                continue;
            }
            end = at + len(syn);
            if end > best_end or (end == best_end and len(syn) > best_len) {
                (best, best_end, best_len) = (item, end, len(syn));
            }
        }
    }
    return best;
}

"""The standard item for a post: `suggested` (the AI's pick) when it is listed for `category`,
else the title's match, else "other". Categories without a list (housing, service) get ""."""
def standard_item(category: str, title: str, suggested: str = "") -> str {
    items = STANDARD_ITEMS.get(category);
    if items is None {
        return "";
    }
    pick = suggested.strip().lower();
    if pick in items {
        return pick;
    }
    return item_from_text(category, title) or "other";
}

"""The goods category whose list has `item` or matches `title` ("" if none), for an extra item the
AI didn't give a category."""
def category_for(item: str, title: str) -> str {
    for (category, items) in STANDARD_ITEMS.items() {
        if item in items {
            return category;
        }
    }
    for category in STANDARD_ITEMS {
        if item_from_text(category, title) {
            return category;
        }
    }
    return "";
}

test "an extra item's category comes from the item list" {
    assert category_for("mattress", "Twin mattress") == "furniture";
    assert category_for("", "Floor lamp") == "essentials";
    assert category_for("", "Kayak") == "";
}

test "titles map to standard items" {
    assert standard_item("furniture", "Study table") == "desk";
    assert standard_item("furniture", "IKEA MALM desk") == "desk";
    assert standard_item("furniture", "Desk chair") == "chair";
    assert standard_item("essentials", "Mini fridge") == "fridge";
    assert standard_item("essentials", "Desk lamp") == "lamp";
    assert standard_item("furniture", "Twin mattress") == "mattress";
    assert standard_item("furniture", "IKEA bookshelves") == "shelf";
    assert standard_item("furniture", "Kayak") == "other";
    assert standard_item("housing", "Room") == "";
}

test "the AI's pick is used only when listed for the final category" {
    assert standard_item("furniture", "Wooden thing", "desk") == "desk";
    assert standard_item("furniture", "Floor lamp", "lamp") == "other";
    assert standard_item("essentials", "Floor lamp", "gizmo") == "lamp";
}

test "the drafting prompt names every standard item" {
    with open("ai/draft.jac") as f {
        source = f.read();
    }
    line = [
        l
        for l in source.splitlines()
        if l.startswith("sem PostDraft.item ")
    ][0];
    for items in STANDARD_ITEMS.values() {
        for item in items {
            assert item in line , item;
        }
    }
}
