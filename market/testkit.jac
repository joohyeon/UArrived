"""Shared test helpers for the marketplace tests (not a test file itself; see CLAUDE.md for why
it is not named test_*.jac).

`served()` is the one way a test starts the served app: dev mode on and real AI switched off,
so no test can reach a real provider even though the repo `.env` holds a real API key. A test
that needs AI replies installs a MockLLM on the model glob (test doubles keep working).
"""

import os;
import tempfile;
import ai.decide;
import ai.draft;
import ai.translate;
import from jaclang.testing.testing { JacTestClient }

"""Switch real AI off for this process (ai/models.jac), and reset this process's drafter,
advisor and translator globs to None so no earlier test's MockLLM leaks into the next test."""
def ai_off {
    os.environ["UARRIVED_AI_OFF"] = "1";
    ai.draft.drafter = None;
    ai.decide.advisor = None;
    ai.translate.translator = None;
}

"""A fresh served app in dev mode with real AI off."""
def served -> JacTestClient {
    os.environ["UARRIVED_DEV_MODE"] = "1";
    ai_off();
    return JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
}
