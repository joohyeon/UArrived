#!/usr/bin/env bash
# One-time project setup: install the web app's npm and Python dependencies.
#
# On macOS, jac 0.37.23's bundled Python can't create a venv (`_posixsubprocess ... symbol not
# found '_PyExc_MemoryError'`), so `jac install` fails. Creating .jac/venv first with a system
# Python 3.14 (same minor version as jac's runtime) works around it. Linux/CI don't need this.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [ "$(uname)" = "Darwin" ] && [ ! -x .jac/venv/bin/python ]; then
  py="$(command -v python3.14 || true)"
  if [ -z "$py" ]; then
    echo "Python 3.14 is needed on macOS (jac's venv bug). Install it: brew install python@3.14" >&2
    exit 1
  fi
  echo "macOS: creating .jac/venv with $py (works around the jac 0.37 venv bug)"
  "$py" -m venv .jac/venv
fi

jac install
