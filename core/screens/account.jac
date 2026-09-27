"""/profile (minimal): who is signed in, and Log out. The full profile editor is still to come."""

import from "@jac/runtime" { jacLogout }
import from core.profile { get_my_profile, ProfileView }
import from ui.tokens { color, text_style }
import from ui.components.base { AppShell, Button, Card }
import from ui.components.blocks { Avatar, KeyValueRow }

def:pub Account -> JsxElement {
    has me: ProfileView | None = None;

    async def load {
        fresh: ProfileView | None = None;
        fresh = await get_my_profile();
        me = fresh;
    }

    can with entry {
        load();
    }

    def logOut(e: MouseEvent) {
        jacLogout();
        window.location.assign("/login");  # jac:ignore[E1032,W2001]
    }

    <AppShell title="Profile" active="profile">
        {(
            <Card>
                <div style={{"display": "flex", "alignItems": "center", "gap": "12px"}}>
                    <Avatar
                        initials={(me.display_name or me.umich_email or "U")[:1].upper()}
                    />
                    <strong style={text_style("card-title")}>
                        {me.display_name or "Student"}
                    </strong>
                </div>
                <KeyValueRow label="Email" value={me.umich_email or "-"}/>
            </Card>
        )
            if me is not None
            else <p style={{"color": color("sub")}}>Loading…</p>}
        <Button label="Log out" variant="secondary" full={True} onClick={logOut}/>
    </AppShell>
}
