"""Welcome: create an account or log in with a @umich.edu address (R15, hackathon version).

Only @umich.edu addresses get past the form (checked here and again by `claim_umich_account` on
the server); there is no emailed verification link. After signing in the student goes on to the
page they asked for, or /today.
"""

import from "@jac/runtime" { SignupResult, jacLogin, jacSignup, jacIsLoggedIn }
import from core.auth { claim_umich_account, VerifyResult }
import from ui.tokens { color, space, text_style, RADIUS }
import from ui.components.base { BaseStyles, Badge, Button, Field, PasswordField }

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

def:pub Welcome -> JsxElement {
    has mode: str = "signup",
        name: str = "",
        email: str = "",
        password: str = "",
        error: str = "",
        busy: bool = False;

    can with entry {
        if window.location.pathname == "/login" {  # jac:ignore[E1032,W2001]
            mode = "login";
        }
        if jacIsLoggedIn() {
            go_to(next_path());
        }
    }

    async def submit(e: FormEvent) -> None;

    def switchTo(m: str) {
        mode = m;
        error = "";
    }

    signup = mode == "signup";
    sub = text_style("body");

    <div style={{"minHeight": "100vh", "background": color("ground")}}>
        <BaseStyles/>
        <main
            style={{
                "maxWidth": "420px",
                "minHeight": "100vh",
                "margin": "0 auto",
                "padding": space("8") + " " + space("4") + " " + space("6"),
                "boxSizing": "border-box",
                "display": "flex",
                "flexDirection": "column",
                "gap": space("4")
            }}
        >
            <Badge
                kind={"action" if signup else "warning"}
                label={"ONE LAST STEP BEFORE YOU SETTLE IN"
                    if signup
                    else "WELCOME BACK"}
            />
            <div
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("2")
                }}
            >
                <h1
                    style={{
                        ** text_style("screen-title"),
                        "margin": "0",
                        "color": color("text")
                    }}
                >
                    {"Create your account" if signup else "Let's log you in"}
                </h1>
                <p style={{** sub, "margin": "0", "color": color("text-2")}}>
                    {"Save your setup progress, collect XP, and unlock personalized campus tips."
                        if signup
                        else "Continue your Ann Arbor journey right where you left off."}
                </p>
            </div>
            <form
                onSubmit={submit}
                noValidate={True}
                style={{
                    "display": "flex",
                    "flexDirection": "column",
                    "gap": space("4")
                }}
            >
                <section
                    style={{
                        "background": color("card"),
                        "border": "1px solid " + color("border"),
                        "borderRadius": f"{RADIUS['card']}px",
                        "padding": space("4"),
                        "display": "flex",
                        "flexDirection": "column",
                        "gap": space("4")
                    }}
                >
                    {(
                        <Field
                            label="Full name"
                            value={name}
                            placeholder="e.g. Katty Wolverine"
                            caps={True}
                            autocomplete="name"
                            onChange={lambda (v: str) { name = v; }}
                        />
                    )
                        if signup
                        else None}
                    <Field
                        label="University email"
                        value={email}
                        input_type="email"
                        placeholder="username@umich.edu"
                        caps={True}
                        autocomplete="email"
                        onChange={lambda (v: str) { email = v; }}
                    />
                    <PasswordField
                        label="Password"
                        value={password}
                        placeholder={"Create a secure password"
                            if signup
                            else "Enter your password"}
                        caps={True}
                        autocomplete={"new-password" if signup else "current-password"}
                        onChange={lambda (v: str) { password = v; }}
                    />
                </section>
                {<p
                    role="alert"
                    style={{
                        ** text_style("small"),
                        "margin": "0",
                        "color": color("danger")
                    }}
                >
                    {error}
                </p>
                    if error
                    else None}
                <Button
                    label={("Creating your account…" if signup else "Logging in…")
                        if busy
                        else ("Create Account →" if signup else "Log In →")}
                    button_type="submit"
                    full={True}
                    disabled={busy}
                />
            </form>
            <p
                style={{
                    ** text_style("small"),
                    "marginTop": "auto",
                    "textAlign": "center",
                    "color": color("sub")
                }}
            >
                {"Already have an account? " if signup else "New here? "}
                <a
                    href={"/login" if signup else "/signup"}
                    onClick={lambda (e: MouseEvent) {
                        e.preventDefault();
                        switchTo("login" if signup else "signup");
                    }}
                    style={{
                        "color": color("action"),
                        "fontWeight": "600",
                        "textDecoration": "none"
                    }}
                >
                    {"Log in" if signup else "Create an account"}
                </a>
            </p>
        </main>
    </div>
}

impl Welcome.submit(e: FormEvent) -> None {
    e.preventDefault();
    address = email.strip().lower();
    if not umich_ok(address) {
        error = "Use your @umich.edu email address.";
        return;
    }
    if len(password) < 8 and mode == "signup" {
        error = "Use a password of at least 8 characters.";
        return;
    }
    if mode == "signup" and name.strip() == "" {
        error = "Tell us your name.";
        return;
    }
    busy = True;
    error = "";
    if mode == "signup" {
        created: SignupResult | None = None;
        created = await jacSignup(address, password);
        if not created.success {
            busy = False;
            error = "That email already has an account. Log in instead.";
            return;
        }
    }
    ok: bool = False;
    ok = await jacLogin(address, password);
    if not ok {
        busy = False;
        error = "Wrong email or password.";
        return;
    }
    claimed: VerifyResult | None = None;
    claimed = await claim_umich_account(address, name if mode == "signup" else "");
    if not claimed.ok {
        busy = False;
        error = claimed.error;
        return;
    }
    go_to(next_path());
}
