"""UMich verification: only verified @umich.edu students use the marketplace (R15).

A student proves control of a @umich.edu address by opening a single-use link
emailed to it. The link carries a long random token from the platform token store
(single-winner consume, server-side expiry), so it cannot be guessed.

Dev mode (UARRIVED_DEV_MODE=1, off by default) returns the token in the response
instead of requiring email, for demos and tests. Never enable it in the pilot.
"""

import os;
import from jaclang.server.identity.app_tokens { token_create, token_consume }
import from interop.email_sender { send }
import from core.profile {
    Profile,
    my_profile,
    sync_mailbox,
    sync_moderator_membership
}

"""Outcome of a verification step, returned to the client."""
obj VerifyResult {
    has ok: bool,
        error: str = "",
        sent: bool = False,
        dev_token: str = "",
        email: str = "";
}

"""The caller's verification state."""
obj VerificationState {
    has email: str,
        verified: bool;
}

glob VERIFY_PURPOSE: str = "umich-verify",
     VERIFY_TTL_SECONDS: int = 86400,
     UMICH_DOMAIN: str = "umich.edu";

"""True only for a single `name@umich.edu` address (case-insensitive)."""
def is_umich_email(email: str) -> bool {
    parts = email.strip().lower().split("@");
    if len(parts) != 2 {
        return False;
    }
    (local, domain) = (parts[0], parts[1]);
    return local != "" and domain == UMICH_DOMAIN and " " not in local;
}

def dev_mode -> bool {
    return os.environ.get("UARRIVED_DEV_MODE", "") == "1";
}

"""Start verifying `email` for the caller: send a single-use link, or in dev mode return the token."""
def:protect start_verification(email: str) -> VerifyResult {
    if not is_umich_email(email) {
        return VerifyResult(ok=False, error="Use your @umich.edu email address.");
    }
    address = email.strip().lower();
    profile = my_profile();
    profile.pending_email = address;
    token = token_create(
        VERIFY_PURPOSE,
        subject=jid(root),
        ttl_seconds=VERIFY_TTL_SECONDS,
        payload={"email": address}
    );
    if dev_mode() {
        print(
            "WARNING: UARRIVED_DEV_MODE=1 - verification token returned in the response."
        );
        return VerifyResult(ok=True, dev_token=token);
    }
    base = os.environ.get("UARRIVED_PUBLIC_URL", "http://localhost:8000");
    sent = False;
    try {
        sent = send(
            address,
            "Verify your UMadeIt account",
            f"Open this link to verify your UMich email:\n\n{base}/verify?token={token}\n\nIt expires in 24 hours. If you didn't ask for this, ignore this email."
        );
    } except Exception {
        return VerifyResult(
            ok=False, error="We couldn't send the email. Try again in a few minutes."
        );
    }
    if not sent {
        return VerifyResult(ok=False, error="Email is not configured on this server.");
    }
    return VerifyResult(ok=True, sent=True);
}

"""Finish verification with the token from the emailed link."""
def:protect confirm_verification(token: str) -> VerifyResult {
    got = token_consume(VERIFY_PURPOSE, token);
    if got is None {
        return VerifyResult(
            ok=False, error="This link is invalid, expired or already used."
        );
    }
    profile = my_profile();
    if got["subject"] != jid(root)
        or got["payload"]["email"] != profile.pending_email {
        return VerifyResult(
            ok=False,
            error="This link belongs to a different sign-up. Request a new one."
        );
    }
    profile.umich_email = profile.pending_email;
    profile.pending_email = "";
    profile.verified = True;
    sync_mailbox(profile);
    sync_moderator_membership(profile);
    return VerifyResult(ok=True, email=profile.umich_email);
}

"""Hackathon sign-in: accept the caller's @umich.edu address without an emailed link. The domain
is the only check (rejects anything that isn't a single name@umich.edu), and `display_name`, when
given, becomes the profile name. Replace with start/confirm_verification before a real pilot."""
def:protect claim_umich_account(email: str, display_name: str) -> VerifyResult {
    if not is_umich_email(email) {
        return VerifyResult(ok=False, error="Use your @umich.edu email address.");
    }
    profile = my_profile();
    profile.umich_email = email.strip().lower();
    profile.pending_email = "";
    profile.verified = True;
    name = display_name.strip()[:60];
    if name {
        profile.display_name = name;
    }
    sync_mailbox(profile);
    sync_moderator_membership(profile);
    return VerifyResult(ok=True, email=profile.umich_email);
}

"""The caller's verification state, for the client."""
def:protect my_verification -> VerificationState {
    profile = my_profile();
    return VerificationState(email=profile.umich_email, verified=profile.verified);
}

"""Guard for every marketplace endpoint: the caller's profile, or None if not verified."""
def verified_profile -> Profile | None {
    profile = my_profile();
    return profile if profile.verified else None;
}

test "only single @umich.edu addresses pass the domain check" {
    assert is_umich_email("mina@umich.edu");
    assert is_umich_email("  MINA@UMICH.EDU ");
    assert not is_umich_email("mina@gmail.com");
    assert not is_umich_email("mina@umich.edu.evil.com");
    assert not is_umich_email("mina@sub.umich.edu.org");
    assert not is_umich_email("mina@evil.com@umich.edu");
    assert not is_umich_email("@umich.edu");
    assert not is_umich_email("mina@med.umich.edu");
}
