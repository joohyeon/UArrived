# journey/ — Feature A: First-Week Journey

**Owner: Feature A lead.** Imports only from `core/`, `ui/`, `ai/` — never from `market/`.

```
journey/
├── graph.jac      # Task, Milestone, Resource nodes; Prerequisite/Applies edges
├── walkers.jac    # GenerateJourney, NextTasks, SetTaskStatus (deterministic, auditable)
├── screens/       # Welcome+onboarding, Today, Journey, task detail  (Jac JSX)
└── tests        # in-file `test "..." { }` blocks: applicability, prerequisite order,
                   #   user progress != official completion
```

Task rules and official links come from `data/tasks` and `data/resources`; they are data, not code,
and never come from an LLM.
