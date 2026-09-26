"""Uarrived entry point."""

def greet(name: str) -> str {
    return f"Hello, {name}!";
}

with entry {
    print(greet("Uarrived"));
}


test "greet names the user" {
    assert greet("Ada") == "Hello, Ada!";
}
