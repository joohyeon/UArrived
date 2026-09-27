"""Handlers for the Welcome screen."""

impl Welcome.refresh -> None {
    state: VerificationState | None = None;
    profile: ProfileView | None = None;
    state = await my_verification();
    verified = state.verified;
    verified_email = state.email;
    if verified {
        profile = await get_my_profile();
        if not profile.onboarding_done {
            go("/onboarding");
        }
    }
}

impl Welcome.confirmFromLink -> None {
    done: VerifyResult | None = None;
    token = link_token();
    if token {
        done = await confirm_verification(token);
        status = "" if done.ok else done.error;
        window.history.replaceState(None, "", "/");
    }
    await refresh();
}

impl Welcome.signUp(e: FormEvent) -> None {
    e.preventDefault();
    result: SignupResult | None = None;
    ok: bool = False;
    result = await jacSignup(email, password);
    if not result.success {
        status = "Could not create the account. Try logging in instead.";
        return;
    }
    ok = await jacLogin(email, password);
    signed_in = ok;
    status = "" if ok else "Account created, but logging in failed.";
    if ok {
        await confirmFromLink();
    }
}

impl Welcome.logIn(e: MouseEvent) -> None {
    ok: bool = False;
    ok = await jacLogin(email, password);
    signed_in = ok;
    status = "" if ok else "Wrong email or password.";
    if ok {
        await confirmFromLink();
    }
}

impl Welcome.verify(e: FormEvent) -> None {
    e.preventDefault();
    started: VerifyResult | None = None;
    done: VerifyResult | None = None;
    started = await start_verification(umich);
    if not started.ok {
        status = started.error;
        return;
    }
    if started.dev_token {
        done = await confirm_verification(started.dev_token);
        status = "" if done.ok else done.error;
        await refresh();
        return;
    }
    status = f"Check {umich} for a verification link.";
}
