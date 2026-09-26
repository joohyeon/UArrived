# market/ — Feature B: Student Buy & Sell Marketplace

**Owner: Feature B lead.** Imports only from `core/`, `ui/`, `ai/` — never from `journey/`.

```
market/
├── graph.jac      # Listing (item | housing), Report nodes; Matches/Saved edges
├── walkers.jac    # PostListing, FindMatches (+ plain-language explanation), Report, ExpireListings
├── screens/       # Housing Hub, Market browse/compare/save/post, listing detail
└── tests          # in-file `test "..." { }` blocks: matching, expiry, verified-facts vs seller claims
```

Housing listings must state their arrangement type (roommate opening, sublet, lease assignment,
new lease). No payments, no lease signing.
