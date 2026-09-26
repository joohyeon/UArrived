import from ui.components { get_component_specs }

def main {
    specs = get_component_specs();
    print(f"UArrived component catalog: {len(specs)} token-backed specifications");
    for spec in specs {
        print(f"{spec.family}/{spec.name} [{spec.variant}]");
    }
}

with entry:__main__ {
    main();
}
