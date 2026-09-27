"""Group chats (plan 2026-09-27-002): the themed groups students browse and join. Shared by both
features, so it lives in core/.

Access: members connect to a group with a `MemberOf` edge; only members post (checked by callers).
Every message is readable by every signed-in student (read-only preview), like posts. A student
can only see their own `MemberOf` edge, so each join also leaves a public `Membership` record: that
is how anyone counts a group's members.
"""

import from core.clock { now_iso, now_precise }
import from core.profile { my_profile }

"""A group chat. `kind` is "theme"; `key` identifies it for reuse ("theme:furniture")."""
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

"""One message in a group. `ai` marks the assistant's messages. `post_ids` are the market posts
filed from this message (its Buying/Selling tags) or, on an assistant note, the posts it points
to. `untagged` is set when the author says the message was just chat."""
node GroupMessage {
    has group_id: str,
        author_root: str,
        author_name: str,
        text: str,
        created_at: str,
        ai: bool = False,
        post_id: str = "",
        post_ids: list[str] = [],
        untagged: bool = False;
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

"""Post a message in `g` as the caller, readable by every signed-in student. `post_ids` links several
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
    grant(msg, level=AccessLevel.READ);
    return msg;
}

def message_by_id(message_id: str) -> GroupMessage | None {
    for m in [root.shared-->][?:GroupMessage] {
        if jid(m) == message_id {
            return m;
        }
    }
    return None;
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
