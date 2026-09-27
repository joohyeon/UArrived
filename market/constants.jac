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
