"""Whether an ai/ model glob can be called, and the one switch that turns real AI off.

`UARRIVED_AI_OFF=1` switches every real model off for the whole process (tests set it through
market/testkit.jac): it has to be process-wide, because a served test app loads its own copies
of these modules, so assigning a test's module glob would not reach the server. A model glob
may also be set to None to switch that one model off. Test doubles (MockLLM) keep working, so a
test can still install scripted replies.
"""

import os;
import from jaclang.byllm.lib { Model }

"""Whether real AI is switched off for this process."""
def ai_switched_off -> bool {
    return os.environ.get("UARRIVED_AI_OFF", "") == "1";
}

"""False for a switched-off model (None), and for the real (Anthropic) model when AI is switched
off or ANTHROPIC_API_KEY is unset, so callers skip it at once instead of paying a failed network
call. A test double (MockLLM) is always ready."""
def model_ready(model: any) -> bool {
    if model is None {
        return False;
    }
    if not isinstance(model, Model) {
        return True;
    }
    return not ai_switched_off()
        and bool(os.environ.get("ANTHROPIC_API_KEY", "").strip());
}
