"""Group chats (plan 004 G1-G2): cohort groups every verified student belongs to, and topic groups
the marketplace creates. Shared by both features, so it lives in core/.

Access: a group is a Jac access group. Members connect to it with a `MemberOf` edge, and each
message is shared with the group once (`allow_group`), so joining or leaving touches no message.
Non-members can't read a group's messages. A student can only see their own `MemberOf` edge, so
each join also leaves a public `Membership` record: that is how anyone counts a group's members.
"""

import from uuid { UUID }
import from jaclang { JacRuntime as Jac }
import from core.clock { now_iso, now_precise }
import from core.profile { Profile, my_profile }

glob MONTHS: list[str] = [
         "Jan",
         "Feb",
         "Mar",
         "Apr",
         "May",
         "Jun",
         "Jul",
         "Aug",
         "Sep",
         "Oct",
         "Nov",
         "Dec"
     ],
     NEW_ARRIVALS_KEY: str = "cohort:new";

"""A group chat. `kind` is "cohort" or "topic"; `key` identifies it for reuse."""
node ChatGroup {
    has kind: str,
        key: str,
        name: str,
        created_at: str,
        reason: str = "";

    def __jac_access__ -> AccessLevel | None {
        return AccessLevel.CONNECT;
    }
}

edge MemberOf: Root --> ChatGroup {}

"""Public record that `member_root` is in `group_id` (no content), kept beside the MemberOf edge."""
node Membership {
    has group_id: str,
        member_root: str;

    def __jac_access__ -> AccessLevel | None {
        return AccessLevel.READ;
    }
}

"""Public, content-free record that `member_root` left `group_id` at `left_at`. Lets the next
matching post invite them back once (market/topics.jac)."""
node LeftGroup {
    has group_id: str,
        member_root: str,
        left_at: str;

    def __jac_access__ -> AccessLevel | None {
        return AccessLevel.READ;
    }
}

"""One message in a group. `ai` marks the assistant's messages; `post_id` links a market post."""
node GroupMessage {
    has group_id: str,
        author_root: str,
        author_name: str,
        text: str,
        created_at: str,
        ai: bool = False,
        post_id: str = "",
        post_ids: list[str] = [];
}

def cohort_key(p: Profile) -> str {
    return f"cohort:{p.arrival_date[:7]}"
        if len(p.arrival_date) >= 7
        else NEW_ARRIVALS_KEY;
}

def cohort_name(key: str) -> str {
    if key == NEW_ARRIVALS_KEY or not key.startswith("cohort:") {
        return "New arrivals";
    }
    (year, month) = key[7:].split("-");
    return f"Arriving {MONTHS[int(month) - 1]} {year}";
}

def all_groups(commons: any = None) -> list[ChatGroup] {
    shared = commons if commons is not None else root.shared;
    return [shared-->][?:ChatGroup];
}

"""Groups with this key, oldest first (normally one; a creation race may leave two)."""
def groups_with_key(key: str, commons: any = None) -> list[ChatGroup] {
    found = [
        g
        for g in all_groups(commons)
        if g.key == key
    ];
    found.sort(key=lambda (g: ChatGroup) -> str { return g.created_at + jid(g); });
    return found;
}

def group_by_id(group_id: str) -> ChatGroup | None {
    for g in all_groups() {
        if jid(g) == group_id {
            return g;
        }
    }
    return None;
}

def my_group_ids -> list[str] {
    return [jid(g) for g in [root->:MemberOf:->]];
}

def is_member(g: ChatGroup) -> bool {
    return jid(g) in my_group_ids();
}

def memberships(group_id: str) -> list[Membership] {
    return [
        m
        for m in [root.shared-->][?:Membership]
        if m.group_id == group_id
    ];
}

def join(g: ChatGroup) {
    if not is_member(g) {
        root +>:MemberOf():+> g;
        root.shared ++> Membership(group_id=jid(g), member_root=jid(root));
    }
}

def leave(g: ChatGroup) {
    if is_member(g) {
        del [edge root->:MemberOf:->g];
    }
    me = jid(root);
    for m in memberships(jid(g)) {
        if m.member_root == me {
            del m;
        }
    }
    root.shared ++> LeftGroup(group_id=jid(g), member_root=me, left_at=now_precise());
}

"""When `member_root` last left `group_id` ("" if never)."""
def last_left(group_id: str, member_root: str) -> str {
    times = [
        l.left_at
        for l in [root.shared-->][?:LeftGroup]
        if l.group_id == group_id and l.member_root == member_root
    ];
    return max(times) if times else "";
}

"""Root ids of the group's members."""
def member_ids(g: ChatGroup) -> list[str] {
    return sorted(set([m.member_root for m in memberships(jid(g))]));
}

def member_count(g: ChatGroup) -> int {
    return len(member_ids(g));
}

"""The group with `key`, created (named `name`) if it doesn't exist yet."""
def ensure_group(kind: str, key: str, name: str, reason: str = "") -> ChatGroup {
    found = groups_with_key(key);
    if found {
        return found[0];
    }
    return root.shared ++> ChatGroup(
        kind=kind, key=key, name=name, created_at=now_iso(), reason=reason
    );
}

"""Put the caller in their cohort group (by arrival month) and out of any other cohort group."""
def sync_cohort(p: Profile) -> ChatGroup {
    key = cohort_key(p);
    for g in [root->:MemberOf:->] {
        if g.kind == "cohort" and g.key != key {
            leave(g);
        }
    }
    g = ensure_group("cohort", key, cohort_name(key));
    join(g);
    return g;
}

"""Post a message in `g` as the caller, shared with the group's members. `post_ids` links several
posts (the first is also kept as `post_id`)."""
def add_message(
    g: ChatGroup,
    text: str,
    ai: bool = False,
    post_id: str = "",
    post_ids: list[str] = []
) -> GroupMessage {
    ids = list(post_ids) if post_ids else ([post_id] if post_id else []);
    name = "UArrived assistant" if ai else (my_profile().display_name or "Student");
    msg = root.shared ++> GroupMessage(
        group_id=jid(g),
        author_root=jid(root),
        author_name=name,
        text=text,
        created_at=now_precise(),
        ai=ai,
        post_id=ids[0] if ids else "",
        post_ids=ids
    );
    Jac.allow_group(msg, UUID(jid(g)), AccessLevel.READ);  # jac:ignore[E1053]
    return msg;
}

def messages_in(group_id: str) -> list[GroupMessage] {
    msgs = [
        m
        for m in [root.shared-->][?:GroupMessage]
        if m.group_id == group_id
    ];
    msgs.sort(key=lambda (m: GroupMessage) -> str { return m.created_at; });
    return msgs;
}

test "cohorts follow the arrival month, or fall back to new arrivals" {
    assert cohort_key(Profile(arrival_date="2026-08-20")) == "cohort:2026-08";
    assert cohort_name("cohort:2026-08") == "Arriving Aug 2026";
    assert cohort_key(Profile()) == "cohort:new"
        and cohort_name("cohort:new") == "New arrivals";
}
