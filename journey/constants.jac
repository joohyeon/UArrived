"""Plain journey constants shared by server and client code. Keep this module import-free: a client
screen that imports a value from a server module pulls that whole module into the browser bundle."""

glob XP_PER_LEVEL: int = 300,
     # Event categories, in chip order ("All" first).
     EVENT_CATEGORIES: list[str] = [
         "All",
         "Learning",
         "Arts",
         "Social",
         "Careers",
         "Well-being",
         "Sports",
         "Tours",
         "Community",
         "Other"
     ],
     # Ann Arbor in Web Mercator world pixels at zoom 18 (min x, min y, max x, max y): journey maps
     # pan inside it. Computed from 42.3230 N, 83.8500 W to 42.2220 N, 83.6750 W.
     ANN_ARBOR_BOUNDS: list[float] = [17923659.0, 24830724.0, 17956281.0, 24856169.0],
     # The Diag, Central Campus (42.2770 N, 83.7390 W): where journey maps start.
     CAMPUS_CENTER: list[float] = [17944351.0, 24842318.0],
     # Task status -> the words shown for it. Done is the student's own claim, never official.
     STATUS_LABELS: dict[str, str] = {
         "todo": "Not started",
         "started": "In progress",
         "done": "Marked done by you"
     };
