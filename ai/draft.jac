"""AI drafting: one free-text message in any language -> its language plus one or more
structured post drafts, each with an English copy (R1, R2, R5, R19, R22, R25).

Knows nothing about the graph or the marketplace rules; `market/drafting.jac` validates and
normalizes what comes back. The model is `drafter`, a module glob so tests can swap in MockLLM,
or None to switch drafting off.
"""

import from jaclang.byllm.lib { Model }
import from ai.models { model_ready }

glob drafter: any = Model(model_name="claude-haiku-4-5-20251001");

"""Whether a drafting call can be made (see ai/models.jac `model_ready`)."""
def drafter_ready -> bool {
    return model_ready(drafter);
}

enum PostKind { OFFER, REQUEST }

sem PostKind.OFFER = "The student has something: selling, giving away, offering a room, a ride seat or help.";
sem PostKind.REQUEST = "The student is looking for something: to buy, rent, find a room, a ride or help.";

enum Category { FURNITURE, ESSENTIALS, HOUSING, VEHICLE, SERVICE }

sem Category.FURNITURE = "Desks, beds, mattresses, chairs, shelves, sofas, tables.";
sem Category.ESSENTIALS = "Kitchenware, bedding, lamps, small appliances, books, other household items.";
sem Category.HOUSING = "Rooms, sublets, roommate openings, lease transfers, apartments.";
sem Category.VEHICLE = "Cars, bikes, scooters, e-bikes.";
sem Category.SERVICE = "Rides (including airport rides), help moving, storage, other favors.";

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
        title_en: str = "",
        description_en: str = "",
        item: str = "",
        condition: str = "";
}


sem PostDraft.about_market = "True only if the student says they want to buy, sell, give away, rent, find or offer housing, share a ride, or get moving help. False for greetings, introductions, asking who else is arriving or on a flight, and questions about campus life.";
sem PostDraft.condition = "The item's condition only if the student states it: one of 'new', 'like new', 'good', 'fair'. Empty otherwise; never guess.";
sem PostDraft.item = "The item as one standard name. furniture: desk, chair, bed, mattress, sofa, shelf, table, dresser. essentials: lamp, fridge, microwave, kitchenware, bedding, fan, monitor, textbook. vehicle: bike, scooter, car. Map synonyms (study table -> desk, mini fridge -> fridge, bookcase -> shelf). 'other' if none fits; empty for housing and services.";
sem PostDraft.title = "The item or need itself in a few words, like 'Bike', 'Wooden desk' or 'Ride from DTW', in the student's own language. Never start with 'Selling', 'Looking for' or 'Need'; the post type already says that. At most 8 words.";
sem PostDraft.description = "One or two plain sentences in the student's own voice (first person, e.g. 'I need a desk near campus this weekend.') in the student's own language, restating only what they said. Never invent condition, brand or features. Keep every number as digits.";
sem PostDraft.title_en = "The title in English. Keep every number as digits exactly as written.";
sem PostDraft.description_en = "The description in English, adding and removing nothing. Keep every number as digits exactly as written.";
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

"""What one message becomes: its language and one draft per distinct need."""
obj DraftSet {
    has language: str,
        drafts: list[PostDraft] = [];
}

sem DraftSet.language = "ISO 639-1 code of the language the student wrote in, for example 'en', 'ko', 'zh'.";
sem DraftSet.drafts = "One draft per distinct need in the message (for example a ride, a room and a desk are three drafts; a bike, a lamp and a mattress for sale are three drafts). A message about one thing is one draft.";

sem draft_posts = "Turn a student's marketplace message, in any language, into structured draft posts. Detect the language. Split distinct needs and distinct items into separate drafts. Write each title and description in the student's language and the English copy separately. Keep every number as digits. Only use facts in the message; mark anything inferred in guessed.";
sem draft_posts.message = "The student's message, exactly as typed.";
sem draft_posts.today = "Today's date, YYYY-MM-DD, for resolving words like 'sat' or 'next week'.";

def draft_posts(message: str, today: str) -> DraftSet by drafter();
