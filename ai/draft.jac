"""AI drafting: one free-text message -> a structured post draft (R1, R2, R5, R19).

Knows nothing about the graph or the marketplace rules; `market/drafting.jac` validates and
normalizes what comes back. The model is `drafter`, a module glob so tests can swap in MockLLM.
"""

import from jaclang.byllm.lib { Model }

glob drafter: any = Model(model_name="claude-haiku-4-5-20251001");

enum PostKind { OFFER, REQUEST }

sem PostKind.OFFER = "The student has something: selling, giving away, offering a room, a ride seat or help.";
sem PostKind.REQUEST = "The student is looking for something: to buy, rent, find a room, a ride or help.";

enum Category { FURNITURE, ESSENTIALS, HOUSING, VEHICLE, SERVICE }

sem Category.FURNITURE = "Desks, beds, mattresses, chairs, shelves, sofas, tables.";
sem Category.ESSENTIALS = "Kitchenware, bedding, lamps, small appliances, books, other household items.";
sem Category.HOUSING = "Rooms, sublets, roommate openings, lease transfers, apartments.";
sem Category.VEHICLE = "Cars, bikes, scooters, e-bikes.";
sem Category.SERVICE = "Rides (including airport rides), help moving, storage, other favors.";

"""Another item in the same message (a moving-out sale lists several)."""
obj ExtraItem {
    has title: str,
        category: Category | None = None,
        item: str = "",
        price: float | None = None;
}

sem ExtraItem.title = "The item in a few words, like 'Floor lamp'.";
sem ExtraItem.category = "Its own category when it differs from the main item's (a lamp is essentials, a bike is vehicle); None if the same.";
sem ExtraItem.item = "Its standard name, from the same list as PostDraft.item.";
sem ExtraItem.price = "Its own price in US dollars if the student gave one for this item; otherwise None.";

obj PostDraft {
    has kind: PostKind,
        category: Category,
        title: str,
        description: str,
        price: float | None = None,
        free: bool = False,
        available_from: str = "",
        available_until: str = "",
        time_from: str = "",
        time_to: str = "",
        area: str = "",
        route_from: str = "",
        route_to: str = "",
        arrangement: str = "",
        constraints: list[str] = [],
        guessed: list[str] = [],
        suggested_price: float | None = None,
        price_reason: str = "",
        about_market: bool = True,
        item: str = "",
        extra_items: list[ExtraItem] = [];
}

sem PostDraft.extra_items = "When the message offers or asks for several different items (e.g. 'selling a bike, a lamp and a mattress'), the main fields describe the first item and this lists all the others in the order written. Only items the student names; never split one item into parts. Empty for a single item.";

sem PostDraft.about_market = "True only if the student says they want to buy, sell, give away, rent, find or offer housing, share a ride, or get moving help. False for greetings, introductions, asking who else is arriving or on a flight, and questions about campus life.";
sem PostDraft.item = "The item as one standard name. furniture: desk, chair, bed, mattress, sofa, shelf, table, dresser. essentials: lamp, fridge, microwave, kitchenware, bedding, fan, monitor, textbook. vehicle: bike, scooter, car. Map synonyms (study table -> desk, mini fridge -> fridge, bookcase -> shelf). 'other' if none fits; empty for housing and services.";
sem PostDraft.title = "The item or need itself in a few words, like 'Bike', 'Wooden desk' or 'Ride from DTW', in the student's own language. Never start with 'Selling', 'Looking for' or 'Need'; the post type already says that.";
sem PostDraft.description = "One or two plain sentences in the student's own voice (first person, e.g. 'I need a desk near campus this weekend.'), restating only what they said. Never invent condition, brand or features.";
sem PostDraft.price = "For an offer: the asking price in US dollars. For a request: the maximum budget. None if not stated.";
sem PostDraft.free = "True only if the student says it is free or a giveaway.";
sem PostDraft.available_from = "First date it is available or needed, YYYY-MM-DD, resolved against today. Empty if unknown.";
sem PostDraft.available_until = "Last date it is available or needed, YYYY-MM-DD, resolved against today (for example 'gone by sat' is the coming Saturday). Empty if unknown.";
sem PostDraft.time_from = "Earliest time on that date, HH:MM 24-hour, for rides and time-bound help. Empty if unknown.";
sem PostDraft.time_to = "Latest time, HH:MM 24-hour. Empty if unknown.";
sem PostDraft.area = "Ann Arbor area as the student wrote it, for example 'north campus' or 'kerrytown'. Empty if not stated.";
sem PostDraft.route_from = "For rides only: where the ride starts, for example 'DTW'. Empty otherwise.";
sem PostDraft.route_to = "For rides only: where the ride ends, for example 'Ann Arbor'. Empty otherwise.";
sem PostDraft.arrangement = "For housing only: one of 'roommate opening', 'sublet', 'lease assignment', 'new lease', or empty if the student did not say.";
sem PostDraft.constraints = "Conditions the student stated, as short phrases, e.g. 'Pickup only', 'Cash only', 'Must go by 2026-09-10', 'Can deliver'. Empty if none. Never invent one.";
sem PostDraft.guessed = "Names of the fields above that you inferred rather than read directly from the message.";
sem PostDraft.suggested_price = "For offers of items only: a fair secondhand price in US dollars for Ann Arbor students. None for requests, housing and services.";
sem PostDraft.price_reason = "One short sentence explaining suggested_price. Empty if suggested_price is None.";

sem draft_post = "Turn a student's marketplace message into a structured draft post. Only use facts in the message; mark anything inferred in guessed.";
sem draft_post.message = "The student's message, exactly as typed.";
sem draft_post.today = "Today's date, YYYY-MM-DD, for resolving words like 'sat' or 'next week'.";

def draft_post(message: str, today: str) -> PostDraft by drafter();
