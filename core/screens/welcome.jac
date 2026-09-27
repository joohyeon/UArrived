"""Welcome: sign up or log in, then verify a @umich.edu address (R15)."""

import from "@jac/runtime" {
    SignupResult,
    jacLogin,
    jacSignup,
    jacLogout,
    jacIsLoggedIn
}
import from core.auth {
    start_verification,
    confirm_verification,
    my_verification,
    VerifyResult,
    VerificationState
}
import from core.profile { get_my_profile, ProfileView }
import from ui.tokens { color, space }

"""The `token` query parameter from an emailed verification link, or ""."""
def link_token -> str {
    params = new(URLSearchParams, window.location.search);  # jac:ignore[E1053]
    return params.get("token") or "";  # jac:ignore[E1032,E1002]
}

def go(path: str) {
    window.location.assign(path);  # jac:ignore[E1032,W2001]
}

def:pub Welcome -> JsxElement {
    has email: str = "",
        password: str = "",
        umich: str = "",
        status: str = "",
        signed_in: bool = False,
        verified: bool = False,
        verified_email: str = "";

    can with entry {
        signed_in = jacIsLoggedIn();
        if signed_in {
            confirmFromLink();
        }
    }

    async def refresh -> None;
    async def confirmFromLink -> None;
    async def signUp(e: FormEvent) -> None;
    async def logIn(e: MouseEvent) -> None;
    async def verify(e: FormEvent) -> None;

    <main
        style={{
            "maxWidth": "420px",
            "margin": "0 auto",
            "padding": space("4"),
            "fontFamily": "'Source Sans 3', system-ui, sans-serif",
            "color": color("text"),
            "background": color("ground"),
            "minHeight": "100vh"
        }}
    >
        <h1 style={{"fontFamily": "Fraunces, Georgia, serif"}}>Welcome to UArrived</h1>
        {<p role="status">{status}</p> if status else None}
        {(
            <form onSubmit={signUp}>
                <label>
                    Email
                    <input
                        type="email"
                        value={email}
                        required={True}
                        onChange={lambda (e: ChangeEvent) { email = e.target.value; }}
                    />
                </label>
                <label>
                    Password
                    <input
                        type="password"
                        value={password}
                        required={True}
                        onChange={lambda (e: ChangeEvent) { password = e.target.value; }}
                    />
                </label>
                <button type="submit">Create account</button>
                <button type="button" onClick={logIn}>Log in</button>
            </form>
        )
            if not signed_in
            else None}
        {(
            <form onSubmit={verify}>
                <label>
                    Your @umich.edu email
                    <input
                        type="email"
                        value={umich}
                        required={True}
                        onChange={lambda (e: ChangeEvent) { umich = e.target.value; }}
                    />
                </label>
                <button type="submit">Send verification link</button>
            </form>
        )
            if signed_in and not verified
            else None}
        {(
            <section>
                <p>Verified as {verified_email}.</p>
                <p>
                    <a href="/market">Go to the marketplace</a>
                    {" · "}
                    <a href="/today">Today</a>
                </p>
                <button
                    type="button"
                    onClick={lambda {
                        jacLogout();
                        signed_in = False;
                        verified = False;
                    }}
                >
                    Log out
                </button>
            </section>
        )
            if verified
            else None}
    </main>
}
