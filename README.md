# Uarrived

Hackathon project, built mostly in [Jac](https://jaclang.org/) (with Python where needed).

## Setup

```bash
pip install jaclang        # or: uv tool install jaclang
jac run main.jac           # runs the entry point
```

## Check before opening a PR

```bash
jac fmt --check .                       # formatting (fix with: jac fmt --lintfix <file>)
jac check .                             # type check
jac test $(git ls-files '*.jac')        # tests (Jac `test "name" { ... }` blocks)
```

CI runs the same three commands on every PR.

## Working as a team

See [CONTRIBUTING.md](CONTRIBUTING.md). Short version: branch off `main`, open a PR, get one
review, squash-merge. Nobody pushes to `main` directly.
