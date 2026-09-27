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

"""Pilot languages for the native-language marketplace (ISO 639-1 codes). Content in any other
language is accepted and translated into these; readers outside this set get English."""
glob PILOT_LANGUAGES: list[str] = ["en", "ko", "zh"],
     DEFAULT_LANGUAGE: str = "en";

"""Each pilot language's name written in that language, for the language picker."""
glob LANGUAGE_NAMES: dict[str, str] = {"en": "English", "ko": "한국어", "zh": "中文"};
