"""Reports, blocks and moderation (U11, R17).

- Report a post or a chat: stored on the commons, shared only with moderators (WRITE, so they can
  resolve it). The reporter is never shown to the other student.
- Block the other student in a suggestion or chat: every suggestion between the two is declined
  (their chat closes and disappears for both), and matching never pairs them again. The blocked
  student is not told. Blocks are stored as a salted one-way key of the pair.
- Moderators (verified, listed in UARRIVED_MODERATORS) see open reports, hide posts (hidden is a
  post status like done or expired, so it leaves feeds, matching and chats), and resolve reports.
"""

import from datetime { date, datetime, timezone }
import from uuid { UUID }
import from jaclang { JacRuntime as Jac }
import from core.auth { verified_profile }
import from core.profile { my_profile, is_moderator, moderator_roots }
import from market.graph {
    Post,
    Suggestion,
    Chat,
    Block,
    Report,
    all_posts,
    all_suggestions,
    all_chats,
    all_blocks,
    all_reports,
    pair_key,
    blocked_keys
}
import from market.matching { withdraw_pending }

glob MAX_REASON_CHARS: int = 500;

obj ReportView {
    has id: str,
        post_id: str,
        post_title: str,
        chat_id: str,
        reason: str,
        created_at: str;
}

"""Block `other` for the caller: decline every suggestion between them, record the block."""
def block_root(other: str) -> bool {
    me = jid(root);
    if other == me or not other {
        return False;
    }
    for s in all_suggestions() {
        if {s.root_a, s.root_b} == {me, other} {
            s.declined = True;
        }
    }
    key = pair_key(me, other);
    if key not in blocked_keys() {
        root.shared ++> Block(pair_key=key);
    }
    return True;
}

def other_in(s: Suggestion) -> str {
    return s.root_b if jid(root) == s.root_a else s.root_a;
}

def block_from_suggestion(suggestion_id: str) -> bool {
    me = jid(root);
    for s in all_suggestions() {
        if jid(s) == suggestion_id and me in [s.root_a, s.root_b] {
            return block_root(other_in(s));
        }
    }
    return False;
}

def block_from_chat(chat_id: str) -> bool {
    me = jid(root);
    for c in all_chats() {
        if jid(c) == chat_id and me in [c.root_a, c.root_b] {
            return block_root(c.root_b if me == c.root_a else c.root_a);
        }
    }
    return False;
}

"""File a report about a post (and optionally the chat it happened in)."""
def file_report(post_id: str, chat_id: str, reason: str) -> bool {
    text = reason.strip()[:MAX_REASON_CHARS];
    if not text {
        return False;
    }
    me = jid(root);
    if not any([jid(p) == post_id for p in all_posts()]) {
        return False;
    }
    if chat_id
        and not any(
            [jid(c) == chat_id and me in [c.root_a, c.root_b] for c in all_chats()]
        ) {
        return False;
    }
    r = root.shared ++> Report(
        reporter_root=me,
        post_id=post_id,
        chat_id=chat_id,
        reason=text,
        created_at=datetime.now(timezone.utc).isoformat(timespec="seconds")
    );
    for m in moderator_roots() {
        if m != me {
            Jac.allow_root(r, UUID(m), AccessLevel.WRITE);  # jac:ignore[E1053]
        }
    }
    return True;
}

def caller_is_moderator -> bool {
    p = verified_profile();
    return p is not None and is_moderator(p);
}

def queue -> list[ReportView] {
    if not caller_is_moderator() {
        return [];
    }
    titles: dict[str, str] = {jid(p): p.title for p in all_posts()};
    views = [
        ReportView(
            id=jid(r),
            post_id=r.post_id,
            post_title=titles.get(r.post_id, "(post not available)"),
            chat_id=r.chat_id,
            reason=r.reason,
            created_at=r.created_at
        )
        for r in all_reports()
        if not r.resolved
    ];
    views.sort(key=lambda (v: ReportView) -> str { return v.created_at; });
    return views;
}

def hide(post_id: str) -> bool {
    if not caller_is_moderator() {
        return False;
    }
    for p in all_posts() {
        if jid(p) == post_id {
            p.hidden = True;
            withdraw_pending(post_id);
            return True;
        }
    }
    return False;
}

def resolve(report_id: str) -> bool {
    if not caller_is_moderator() {
        return False;
    }
    for r in all_reports() {
        if jid(r) == report_id {
            r.resolved = True;
            return True;
        }
    }
    return False;
}

def:protect report_post(post_id: str, reason: str) -> bool {
    return verified_profile() is not None and file_report(post_id, "", reason);
}

"""Report the other student's post in this chat, with the chat attached for context."""
def:protect report_chat(chat_id: str, reason: str) -> bool {
    if verified_profile() is None {
        return False;
    }
    me = jid(root);
    for c in all_chats() {
        if jid(c) == chat_id and me in [c.root_a, c.root_b] {
            for s in all_suggestions() {
                if jid(s) == c.suggestion_id {
                    return file_report(
                        s.post_b if me == s.root_a else s.post_a, chat_id, reason
                    );
                }
            }
        }
    }
    return False;
}

def:protect block_in_suggestion(suggestion_id: str) -> bool {
    return verified_profile() is not None and block_from_suggestion(suggestion_id);
}

def:protect block_in_chat(chat_id: str) -> bool {
    return verified_profile() is not None and block_from_chat(chat_id);
}

def:protect moderation_queue -> list[ReportView] {
    return queue();
}

def:protect hide_post(post_id: str) -> bool {
    return hide(post_id);
}

def:protect resolve_report(report_id: str) -> bool {
    return resolve(report_id);
}

test "a pair's block key is the same in either order and differs across pairs" {
    assert pair_key("a", "b") == pair_key("b", "a");
    assert pair_key("a", "b") != pair_key("a", "c");
    assert len(pair_key("a", "b")) == 64;
}
