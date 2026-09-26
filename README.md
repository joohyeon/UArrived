# Uarrived

Hackathon project, built mostly in [Jac](https://jaclang.org/) (with Python where needed).

## Setup

```bash
# macOS only, once per clone: jac 0.37.23's bundled Python can't create venvs
# (`_posixsubprocess ... symbol not found`), so create it with Homebrew Python 3.14 first:
python3.14 -m venv .jac/venv
jac install                # npm + Python deps for the web app
UARRIVED_DEV_MODE=1 jac run main.jac   # app on :8000, API on :8001; dev mode skips email

curl -fsSL https://jaclang.org/install.sh | bash -s -- --version 0.37.23   # NOT pip: PyPI stops at 0.16
jac run main.jac           # runs the entry point
```

## Structure

Web app (mobile-first), all Jac: `core/` shared model · `journey/` Feature A · `market/` Feature B · `ui/` design system · `ai/` · `interop/` · `data/` · `docs/`. Rules: [docs/ENGINEERING_RULES.md](docs/ENGINEERING_RULES.md).

## Check before opening a PR

```bash
bash scripts/check_rules.sh             # Jac share ≥ 40%, boundaries, design tokens
jac fmt --check .                       # formatting (fix with: jac fmt --lintfix <file>)
jac check .                             # type check
jac test -d .                           # every test "name" { ... } block in the repo
```

CI runs the same three commands on every PR.

## Working as a team

See [CONTRIBUTING.md](CONTRIBUTING.md). Short version: branch off `main`, open a PR, get one
review, squash-merge. Nobody pushes to `main` directly.
