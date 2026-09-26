"""The student's profile: one per student, on their own root.

U1 owns identity and verification state; U2 adds the first-week journey fields.
"""

node Profile {
    has display_name: str = "",
        umich_email: str = "",
        verified: bool = False;
}

"""The caller's profile, created on first use."""
def my_profile -> Profile {
    found = [root-->][?:Profile];
    if found {
        return found[0];
    }
    return root ++> Profile();
}
