"""Plain marketplace constants shared by server and client code (import-free; see
core/constants.jac for why)."""

glob ARRANGEMENTS: list[str] = [
         "roommate opening",
         "sublet",
         "lease assignment",
         "new lease"
     ];

"""Category-specific safety guidance shown while composing (R16). Plain advice only; never a
claim that a post or person is safe."""
glob SAFETY_TIPS: dict[str, str] = {
         "service": "Rides and moving help: share your trip or visit with a friend, agree on the route and cost before you go, and keep your phone charged.",
         "vehicle": "Vehicles: meet in daylight somewhere public, test drive with a friend, check that the title and registration match the seller's name, and never pay before you have the title.",
         "housing": "Housing: never send a deposit or rent before you have seen the room and read the lease. Check that the lease allows a sublet or transfer.",
         "furniture": "Pickups: meet in a public place or bring a friend, and pay only when you have the item.",
         "essentials": "Pickups: meet in a public place or bring a friend, and pay only when you have the item."
     };

"""Standard item names per goods category (topic grouping, plan 2026-09-27-001 U1), each with the
words students use for it. A post's standard item picks its topic group, so "study table" and
"desk" meet in one group. Items not listed file as "other". Keep ai/draft.jac's `PostDraft.item`
sem in step with this list (a test in market/items.jac checks it)."""
glob STANDARD_ITEMS: dict[str, dict[str, list[str]]] = {
         "furniture": {
             "desk": ["desk", "study table", "writing table", "computer table"],
             "chair": ["chair", "office chair", "desk chair", "stool", "armchair"],
             "bed": ["bed", "bed frame", "bedframe", "bunk bed", "loft bed"],
             "mattress": ["mattress", "topper", "mattress topper", "futon mattress"],
             "sofa": ["sofa", "couch", "futon", "loveseat", "sectional"],
             "shelf": [
                 "shelf",
                 "shelves",
                 "bookshelf",
                 "bookshelves",
                 "bookcase",
                 "shelving"
             ],
             "table": [
                 "table",
                 "dining table",
                 "coffee table",
                 "side table",
                 "nightstand"
             ],
             "dresser": ["dresser", "drawers", "chest of drawers", "wardrobe", "closet"]
         },
         "essentials": {
             "lamp": ["lamp", "floor lamp", "desk lamp", "light"],
             "fridge": [
                 "fridge",
                 "mini fridge",
                 "minifridge",
                 "refrigerator",
                 "freezer"
             ],
             "microwave": ["microwave"],
             "kitchenware": [
                 "pots",
                 "pans",
                 "pot",
                 "pan",
                 "kitchenware",
                 "cookware",
                 "dishes",
                 "plates",
                 "utensils",
                 "rice cooker",
                 "kettle",
                 "air fryer"
             ],
             "bedding": [
                 "bedding",
                 "sheets",
                 "comforter",
                 "duvet",
                 "pillow",
                 "pillows",
                 "blanket"
             ],
             "fan": ["fan", "heater", "space heater", "air conditioner", "humidifier"],
             "monitor": ["monitor", "tv", "television", "screen"],
             "textbook": ["textbook", "textbooks", "book", "books"]
         },
         "vehicle": {
             "bike": ["bike", "bicycle", "e-bike", "ebike"],
             "scooter": ["scooter", "e-scooter", "moped"],
             "car": ["car", "sedan", "suv", "vehicle"]
         }
     };
