"""Mutual opt-in and per-post chat (U6, R8, R9, R11).

A chat opens only when both students accept. Each side writes only its own acceptance; the chat
is created by whichever call redeems the suggestion's single-use `open_token` (atomic, one
winner), so there is never a second chat. If both accepts race past each other, the next call
that sees both acceptances opens it (every chat listing heals), so there is never zero either.

A chat is closed whenever its suggestion is (either post done or expired): read-only, derived on
read, nothing written.
"""

import from core.clock { today_iso as clock_today }
import from datetime { date, datetime, timezone }
import from uuid { UUID }
import from jaclang { JacRuntime as Jac }
import from jaclang.server.identity.app_tokens { token_consume }
import from core.auth { verified_profile }
import from market.graph {
    Post,
    Suggestion,
    Chat,
    Message,
    all_posts,
    all_suggestions,
    all_chats
}
import from market.matching { CHAT_OPEN_PURPOSE }
import from market.suggestions { suggestion_status }

glob MAX_MESSAGE_CHARS: int = 2000;

obj ConnectResult {
    has ok: bool,
        error: str = "",
        connected: bool = False,
        chat_id: str = "";
}

obj MessageView {
    has mine: bool,
        text: str,
        sent_at: str;
}

obj ChatView {
    has id: str,
        open: bool,
        my_post_title: str,
        other_post_title: str,
        last_message: str,
        last_at: str;
}

obj ChatThread {
    has ok: bool,
        error: str = "",
        chat: ChatView | None = None,
        messages: list[MessageView] = [];
}

obj SendResult {
    has ok: bool,
        error: str = "";
}

def today_iso -> str {
    return clock_today();
}

def now_iso -> str {
    return datetime.now(timezone.utc).isoformat(timespec="seconds");
}

def posts_by_id -> dict[str, Post] {
    return {jid(p): p for p in all_posts()};
}

"""The caller's suggestion with this id, or None if it isn't theirs."""
def my_suggestion(suggestion_id: str) -> Suggestion | None {
    me = jid(root);
    for s in all_suggestions() {
        if jid(s) == suggestion_id and me in [s.root_a, s.root_b] {
            return s;
        }
    }
    return None;
}

def chat_for(suggestion_id: str) -> Chat | None {
    for c in all_chats() {
        if c.suggestion_id == suggestion_id {
            return c;
        }
    }
    return None;
}

"""The chat for `s` if both students accepted: the existing one, or a new one if this call wins
the single-use open token. None if not both accepted, or another call is creating it."""
def ensure_chat(s: Suggestion) -> Chat | None {
    existing = chat_for(jid(s));
    if existing is not None or not (s.accepted_a and s.accepted_b) {
        return existing;
    }
    if token_consume(CHAT_OPEN_PURPOSE, s.open_token) is None {
        return chat_for(jid(s));
    }
    chat = root.shared ++> Chat(
        suggestion_id=jid(s), root_a=s.root_a, root_b=s.root_b, created_on=today_iso()
    );
    other = s.root_b if jid(root) == s.root_a else s.root_a;
    Jac.allow_root(chat, UUID(other), AccessLevel.WRITE);  # jac:ignore[E1053]
    return chat;
}

"""Accept the caller's side of a suggestion; opens the chat once both sides have accepted."""
def connect_to(suggestion_id: str) -> ConnectResult {
    s = my_suggestion(suggestion_id);
    if s is None {
        return ConnectResult(ok=False, error="That suggestion isn't available.");
    }
    posts = posts_by_id();
    status = suggestion_status(
        s, posts.get(s.post_a), posts.get(s.post_b), today_iso()
    );
    if status not in ["open", "connected"] {
        return ConnectResult(
            ok=False, error="That suggestion isn't available any more."
        );
    }
    if jid(root) == s.root_a {
        s.accepted_a = True;
        s.seen_a = True;
    } else {
        s.accepted_b = True;
        s.seen_b = True;
    }
    chat = ensure_chat(s);
    return ConnectResult(
        ok=True,
        connected=chat is not None,
        chat_id=jid(chat) if chat is not None else ""
    );
}

"""Decline a suggestion. The pairing is hidden for good and the other student is not told."""
def decline_suggestion(suggestion_id: str) -> bool {
    s = my_suggestion(suggestion_id);
    if s is None or s.accepted_a and s.accepted_b {
        return False;
    }
    s.declined = True;
    return True;
}

def chat_view(c: Chat, s: Suggestion, posts: dict[str, Post]) -> ChatView {
    mine_is_a = jid(root) == s.root_a;
    (a, b) = (posts.get(s.post_a), posts.get(s.post_b));
    msgs = sorted_messages(c);
    return ChatView(
        id=jid(c),
        open=suggestion_status(s, a, b, today_iso()) == "connected",
        my_post_title=(a if mine_is_a else b).title
            if a and b
            else (a.title if a and mine_is_a else ""),
        other_post_title=(b if mine_is_a else a).title
            if a and b
            else (a.title if a and not mine_is_a else "Your reply"),
        last_message=msgs[-1].text if msgs else "",
        last_at=msgs[-1].sent_at if msgs else c.created_on
    );
}

def sorted_messages(c: Chat) -> list[Message] {
    msgs = [c-->][?:Message];
    msgs.sort(key=lambda (m: Message) -> str { return m.sent_at; });
    return msgs;
}

"""The caller's chats, most recent first. Opens any chat both sides accepted but no call created."""
def my_chats -> list[ChatView] {
    me = jid(root);
    posts = posts_by_id();
    views: list[ChatView] = [];
    for s in all_suggestions() {
        if me not in [s.root_a, s.root_b]
            or not (s.accepted_a and s.accepted_b)
            or s.declined {
            continue;
        }
        c = ensure_chat(s);
        if c is not None {
            views.append(chat_view(c, s, posts));
        }
    }
    views.sort(key=lambda (v: ChatView) -> str { return v.last_at; }, reverse=True);
    return views;
}

"""The caller's chat with this id and its suggestion, or None if it isn't theirs."""
def my_chat(chat_id: str) -> tuple[Chat, Suggestion] | None {
    me = jid(root);
    for c in all_chats() {
        if jid(c) == chat_id and me in [c.root_a, c.root_b] {
            s = my_suggestion(c.suggestion_id);
            if s is not None {
                return (c, s);
            }
        }
    }
    return None;
}

def read_thread(chat_id: str) -> ChatThread {
    found = my_chat(chat_id);
    if found is None {
        return ChatThread(ok=False, error="That chat isn't available.");
    }
    (c, s) = found;
    me = jid(root);
    return ChatThread(
        ok=True,
        chat=chat_view(c, s, posts_by_id()),
        messages=[
            MessageView(mine=m.author_root == me, text=m.text, sent_at=m.sent_at)
            for m in sorted_messages(c)
        ]
    );
}

def send(chat_id: str, text: str) -> SendResult {
    found = my_chat(chat_id);
    if found is None {
        return SendResult(ok=False, error="That chat isn't available.");
    }
    (c, s) = found;
    body = text.strip();
    if body == "" {
        return SendResult(ok=False, error="Type a message.");
    }
    if len(body) > MAX_MESSAGE_CHARS {
        return SendResult(
            ok=False, error=f"Keep messages under {MAX_MESSAGE_CHARS} characters."
        );
    }
    posts = posts_by_id();
    if suggestion_status(s, posts.get(s.post_a), posts.get(s.post_b), today_iso())
        != "connected" {
        return SendResult(ok=False, error="This post is closed.");
    }
    msg = c ++> Message(author_root=jid(root), text=body, sent_at=now_iso());
    other = s.root_b if jid(root) == s.root_a else s.root_a;
    Jac.allow_root(msg, UUID(other), AccessLevel.READ);  # jac:ignore[E1053]
    return SendResult(ok=True);
}

def:protect connect(suggestion_id: str) -> ConnectResult {
    if verified_profile() is None {
        return ConnectResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    return connect_to(suggestion_id);
}

def:protect decline(suggestion_id: str) -> bool {
    return verified_profile() is not None and decline_suggestion(suggestion_id);
}

def:protect list_my_chats -> list[ChatView] {
    if verified_profile() is None {
        return [];
    }
    return my_chats();
}

def:protect read_chat(chat_id: str) -> ChatThread {
    if verified_profile() is None {
        return ChatThread(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    return read_thread(chat_id);
}

def:protect send_message(chat_id: str, text: str) -> SendResult {
    if verified_profile() is None {
        return SendResult(
            ok=False, error="Verify your UMich email to use the marketplace."
        );
    }
    return send(chat_id, text);
}
