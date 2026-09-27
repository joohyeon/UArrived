"""Plain constants shared by server and client code. Keep this module import-free: a client
screen that imports a value from a server module pulls that whole module into the browser bundle."""

glob ANN_ARBOR_AREAS: list[str] = [
         "Central Campus",
         "North Campus",
         "South Campus",
         "Kerrytown",
         "Old West Side",
         "Downtown",
         "Other"
     ];
