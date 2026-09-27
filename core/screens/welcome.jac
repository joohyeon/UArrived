"""Welcome: create an account or sign in with a @umich.edu address (R15, hackathon version).

Only @umich.edu addresses get past the form (checked here and again by `claim_umich_account` on
the server); there is no emailed verification link. /signup opens account creation; /login and
pages that need an account open sign-in. After signing in the student goes on to the page they
asked for, or /today. Same look as the landing page: warm canvas, indigo actions, coral accents,
a campus photo beside the form on wide screens and after it on phones.
"""

import from "@jac/runtime" { SignupResult, jacLogin, jacSignup, jacIsLoggedIn }
import from core.auth { claim_umich_account, VerifyResult }
import from core.profile { get_my_profile, ProfileView }
import from ui.tokens { color, space, text_style, RADIUS, SIZE, FONTS }
import from ui.components.base { BaseStyles, Button, Field, PasswordField }

"""Where to go after signing in: the gated page the student opened, else /today."""
def next_path -> str {
    path = window.location.pathname;  # jac:ignore[E1032,W2001]
    return "/today" if path in ["", "/", "/login", "/signup"] else path;
}

def go_to(path: str) {
    window.location.assign(path);  # jac:ignore[E1032,W2001]
}

"""Client-side copy of core.auth.is_umich_email, so a wrong address is caught before sign-up."""
def umich_ok(email: str) -> bool {
    parts = email.strip().lower().split("@");
    return len(parts) == 2
        and parts[0] != ""
        and " " not in parts[0]
        and parts[1] == "umich.edu";
}

"""Two columns (form, photo) on wide screens; one column with the photo last on phones."""
def:pub WelcomeStyles -> JsxElement {
    css = (
        ".wl-grid{display:grid;grid-template-columns:minmax(0,440px) minmax(0,1fr);gap:56px;align-items:center}"
        + "@media (max-width: 900px){.wl-grid{grid-template-columns:minmax(0,1fr);gap:32px}"
        + ".wl-photo{height:220px!important}}"
    );
    <style>{css}</style>
}

def:pub Welcome -> JsxElement {
    has mode: str = "login",
        name: str = "",
        email: str = "",
        password: str = "",
        errors: dict[str, str] = {},
        error: str = "",
        busy: bool = False;

    can with entry {
        if window.location.pathname == "/signup" {  # jac:ignore[E1032,W2001]
            mode = "signup";
        }
        if jacIsLoggedIn() {
            routeAfterAuth();
        }
    }

    async def submit(e: FormEvent) -> None;
    async def routeAfterAuth -> None;

    def switchTo(m: str) {
        mode = m;
        error = "";
        errors = {};
        window.history.replaceState(None, "", "/" + m);  # jac:ignore[E1032,W2001]
    }

    signup = mode == "signup";
    small = text_style("small");

    <div
        style={{
            "minHeight": "100vh",
            "background": color("canvas"),
            "color": color("text")
        }}
    >
        <BaseStyles/>
        <WelcomeStyles/>
        <header
            style={{
                "maxWidth": "1160px",
                "margin": "0 auto",
                "padding": "0 " + space("4"),
                "minHeight": "68px",
                "display": "flex",
                "alignItems": "center",
                "justifyContent": "space-between",
                "gap": space("3")
            }}
        >
            <a
                href="/"
                style={{
                    "fontFamily": FONTS["display"],
                    "fontSize": "24px",
                    "fontWeight": "700",
                    "color": color("action"),
                    "textDecoration": "none",
                    "minHeight": f"{SIZE['touch-min']}px",
                    "display": "inline-flex",
                    "alignItems": "center"
                }}
            >
                UMade
                <span style={{"color": color("coral-ink")}}>It</span>
            </a>
            <span style={{** small, "color": color("text-2")}}>
                {"Have an account? " if signup else "New here? "}
                <a
                    href={"/login" if signup else "/signup"}
                    onClick={lambda (e: MouseEvent) {
                        e.preventDefault();
                        switchTo("login" if signup else "signup");
                    }}
                    style={{"color": color("action"), "fontWeight": "700"}}
                >
                    {"Sign in" if signup else "Create account"}
                </a>
            </span>
        </header>
        <main
            style={{
                "maxWidth": "1160px",
                "margin": "0 auto",
                "padding": space("6") + " " + space("4") + " " + space("8"),
                "boxSizing": "border-box"
            }}
        >
            <div className="wl-grid">
                <div
                    style={{
                        "display": "flex",
                        "flexDirection": "column",
                        "gap": space("4")
                    }}
                >
                    <span
                        style={{
                            ** text_style("label"),
                            "display": "inline-flex",
                            "alignItems": "center",
                            "gap": space("2"),
                            "color": color("coral-ink"),
                            "textTransform": "uppercase",
                            "letterSpacing": "0.08em"
                        }}
                    >
                        <span
                            aria-hidden="true"
                            style={{
                                "width": "8px",
                                "height": "8px",
                                "borderRadius": "50%",
                                "background": color("coral")
                            }}
                        />
                        {"One last step before you settle in"
                            if signup
                            else "Welcome back"}
                    </span>
                    <h1
                        style={{
                            "margin": "0",
                            "fontFamily": FONTS["display"],
                            "fontSize": "clamp(32px, 5vw, 44px)",
                            "fontWeight": "700",
                            "lineHeight": "1.08"
                        }}
                    >
                        {"Create your account" if signup else "Sign in to UMadeIt"}
                    </h1>
                    <p
                        style={{
                            ** text_style("body"),
                            "margin": "0",
                            "color": color("text-2")
                        }}
                    >
                        {"Save your first-week progress and connect with students around campus."
                            if signup
                            else "Pick up your first week, matches and messages where you left off."}
                    </p>
                    <form
                        onSubmit={submit}
                        noValidate={True}
                        aria-busy={busy}
                        style={{
                            "background": color("card"),
                            "border": "1px solid " + color("border"),
                            "borderRadius": "20px",
                            "padding": space("6") + " " + space("4"),
                            "display": "flex",
                            "flexDirection": "column",
                            "gap": space("4"),
                            "boxShadow": "0 16px 40px " + color("shadow")
                        }}
                    >
                        {(
                            <Field
                                label="Full name"
                                value={name}
                                placeholder="e.g. Katty Wolverine"
                                caps={True}
                                autocomplete="name"
                                error={errors.get("name", "")}
                                onChange={lambda (v: str) { name = v; }}
                            />
                        )
                            if signup
                            else None}
                        <Field
                            label="University email"
                            value={email}
                            input_type="email"
                            placeholder="uniqname@umich.edu"
                            caps={True}
                            autocomplete="email"
                            hint="Only @umich.edu addresses can join."
                            error={errors.get("email", "")}
                            onChange={lambda (v: str) { email = v; }}
                        />
                        <PasswordField
                            label="Password"
                            value={password}
                            placeholder={"At least 8 characters"
                                if signup
                                else "Your password"}
                            caps={True}
                            autocomplete={"new-password"
                                if signup
                                else "current-password"}
                            error={errors.get("password", "")}
                            onChange={lambda (v: str) { password = v; }}
                        />
                        {<p
                            role="alert"
                            style={{** small, "margin": "0", "color": color("danger")}}
                        >
                            {error}
                        </p>
                            if error
                            else None}
                        <Button
                            label={(
                                "Creating your account…" if signup else "Signing in…"
                            )
                                if busy
                                else ("Create account" if signup else "Sign in")}
                            button_type="submit"
                            full={True}
                            disabled={busy}
                        />
                        {(
                            <details style={{** small, "color": color("text-2")}}>
                                <summary
                                    style={{
                                        "cursor": "pointer",
                                        "minHeight": f"{SIZE['touch-min']}px",
                                        "display": "flex",
                                        "alignItems": "center",
                                        "fontWeight": "600",
                                        "color": color("action")
                                    }}
                                >
                                    Trouble signing in?
                                </summary>
                                <ul
                                    style={{
                                        "margin": "0",
                                        "paddingLeft": "20px",
                                        "display": "flex",
                                        "flexDirection": "column",
                                        "gap": space("1")
                                    }}
                                >
                                    <li>
                                        Use the @umich.edu email you joined with, in full.
                                    </li>
                                    <li>
                                        Passwords are case-sensitive; tap Show to check what you typed.
                                    </li>
                                    <li>
                                        Password reset by email isn't available yet in this pilot.
                                    </li>
                                    <li>
                                        Never joined?{" "}
                                        <a
                                            href="/signup"
                                            onClick={lambda (e: MouseEvent) {
                                                e.preventDefault();
                                                switchTo("signup");
                                            }}
                                        >
                                            Create an account
                                        </a>
                                    </li>
                                </ul>
                            </details>
                        )
                            if not signup
                            else None}
                    </form>
                    <p
                        style={{
                            ** small,
                            "margin": "0",
                            "color": color("sub"),
                            "textAlign": "center"
                        }}
                    >
                        {"Already have an account? " if signup else "New to UMadeIt? "}
                        <a
                            href={"/login" if signup else "/signup"}
                            onClick={lambda (e: MouseEvent) {
                                e.preventDefault();
                                switchTo("login" if signup else "signup");
                            }}
                            style={{"color": color("action"), "fontWeight": "700"}}
                        >
                            {"Sign in" if signup else "Create an account"}
                        </a>
                    </p>
                </div>
                <figure
                    style={{
                        "margin": "0",
                        "display": "flex",
                        "flexDirection": "column",
                        "gap": space("2")
                    }}
                >
                    <img
                        className="wl-photo"
                        src="/static/assets/images/diag-walk.jpg"
                        alt="A shaded path across the Diag under tall trees"
                        style={{
                            "width": "100%",
                            "height": "560px",
                            "objectFit": "cover",
                            "borderRadius": "24px",
                            "background": color("panel"),
                            "display": "block"
                        }}
                    />
                    <figcaption
                        style={{** text_style("caption"), "color": color("sub")}}
                    >
                        The Diag. Photo:{" "}
                        <a
                            href="https://commons.wikimedia.org/wiki/File:The_Diag,_University_of_Michigan,_University_Avenue,_Ann_Arbor,_MI.jpg"
                            style={{"color": color("sub")}}
                        >
                            w_lemay
                        </a>
                        {", "}
                        <a
                            href="https://creativecommons.org/licenses/by-sa/2.0/"
                            style={{"color": color("sub")}}
                        >
                            CC BY-SA 2.0
                        </a>
                    </figcaption>
                </figure>
            </div>
        </main>
    </div>
}

impl Welcome.submit(e: FormEvent) -> None {
    e.preventDefault();
    address = email.strip().lower();
    found: dict[str, str] = {};
    if mode == "signup" and name.strip() == "" {
        found["name"] = "Enter your name.";
    }
    if address == "" {
        found["email"] = "Enter your @umich.edu email.";
    } elif not umich_ok(address) {
        found["email"] = "Use your @umich.edu email address.";
    }
    if password == "" {
        found["password"] = "Enter your password.";
    } elif mode == "signup" and len(password) < 8 {
        found["password"] = "Use at least 8 characters.";
    }
    errors = found;
    error = "";
    if len(found) > 0 {
        return;
    }
    busy = True;
    if mode == "signup" {
        created: SignupResult | None = None;
        created = await jacSignup(address, password);
        if not created.success {
            busy = False;
            error = "That email already has an account. Sign in instead.";
            return;
        }
    }
    ok: bool = False;
    ok = await jacLogin(address, password);
    if not ok {
        busy = False;
        error = "That email and password don't match. Check both and try again.";
        return;
    }
    claimed: VerifyResult | None = None;
    claimed = await claim_umich_account(address, name if mode == "signup" else "");
    if not claimed.ok {
        busy = False;
        error = claimed.error;
        return;
    }
    await routeAfterAuth();
}

"""Go to `next_path()`, or /onboarding first if the student hasn't finished the arrival wizard."""
impl Welcome.routeAfterAuth -> None {
    profile: ProfileView | None = None;
    profile = await get_my_profile();
    go_to(next_path() if profile.onboarding_done else "/onboarding");
}
