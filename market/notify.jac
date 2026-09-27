"""Match notifications (U7, R21): an in-app unread badge, and one batched email per student.

In-app: a suggestion is unread for a student until they open it or act on it.
Email: every NOTIFY_INTERVAL_SECONDS the system user's sweep sends each student one email listing
their new, unread, open suggestions (titles and reasons, never chat text), then marks them
emailed. The student whose own post created a suggestion is never emailed about it. Addresses
come from Mailbox records on the commons, so the sweep never reads private profiles; reasons are
listed in the language copied onto each Mailbox (the student's profile language).
Topic-group invites (plan 004 G-R8) count in the badge until answered and are emailed once, with
the group's name and the reason; group chat messages never email.
The sweep only fires under `jac run --serve` with [scale.scheduler] enabled.
"""

import from core.clock { today_iso as clock_today }
import os;
import from datetime { date }
import from interop.email_sender { send }
import from core.auth { verified_profile }
import from core.profile { Mailbox }
import from market.constants { reasons_for }
import from market.graph {
    Post,
    Suggestion,
    all_posts,
    all_suggestions,
    commons_or_shared,
    all_replies,
    Reply
}
import from market.suggestions { suggestion_status }
import from core.groups { ChatGroup }
import from market.topics { Invite }

glob NOTIFY_INTERVAL_SECONDS: float = float(
         os.environ.get("UARRIVED_NOTIFY_INTERVAL", "600")
     );

"""One student's pending notification: the post of theirs that matched, and what it matched."""
obj Pending {
    has suggestion: Suggestion,
        side: str,
        my_title: str,
        other_title: str,
        reasons: list[str],
        reason_codes: list[dict[str, any]] = [];
}

"""Unread, un-emailed, open suggestions grouped by the student to notify, as of `today`."""
def pending_by_student(today: str, commons: any = None) -> dict[str, list[Pending]] {
    posts: dict[str, Post] = {jid(p): p for p in all_posts(commons)};
    out: dict[str, list[Pending]] = {};
    for s in all_suggestions(commons) {
        (a, b) = (posts.get(s.post_a), posts.get(s.post_b));
        if a is None or b is None or suggestion_status(s, a, b, today) != "open" {
            continue;
        }
        if not (s.emailed_a or s.seen_a) {
            out.setdefault(s.root_a, []).append(
                Pending(
                    suggestion=s,
                    side="a",
                    my_title=a.title,
                    other_title=b.title,
                    reasons=s.reasons,
                    reason_codes=s.reason_codes
                )
            );
        }
        if not (s.emailed_b or s.seen_b) {
            out.setdefault(s.root_b, []).append(
                Pending(
                    suggestion=s,
                    side="b",
                    my_title=b.title,
                    other_title=a.title,
                    reasons=s.reasons,
                    reason_codes=s.reason_codes
                )
            );
        }
    }
    return out;
}

"""The digest email text, with each match's reasons in `lang`."""
def digest_body(items: list[Pending], lang: str = "en") -> str {
    base = os.environ.get("UARRIVED_PUBLIC_URL", "http://localhost:8000");
    lines = [
        f"You have {len(items)} new match{'es'
            if len(items) != 1
            else ''} on UArrived:",
        ""
    ];
    for it in items {
        lines.append(f"- \"{it.other_title}\" for your post \"{it.my_title}\"");
        reasons = reasons_for(it.reasons, it.reason_codes, lang);
        if reasons {
            lines.append(f"  {'; '.join(reasons)}");
        }
    }
    lines.extend(
        [
            "",
            f"Open your matches to connect: {base}/market/matches",
            "",
            "Turn these emails off in Profile."
        ]
    );
    return "\n".join(lines);
}

def mark_emailed(items: list[Pending]) {
    for it in items {
        if it.side == "a" {
            it.suggestion.emailed_a = True;
        } else {
            it.suggestion.emailed_b = True;
        }
    }
}

"""Send one digest per student with pending matches. Returns how many emails were sent.

A student with email turned off (or no Mailbox) is marked emailed without sending, so turning
email back on doesn't flood them with old matches. A failed send leaves items for next time.
"""
def sweep(today: str, commons: any = None) -> int {
    boxes: dict[str, Mailbox] = {
        m.owner_root: m for m in [commons_or_shared(commons)-->][?:Mailbox]
    };
    sent = 0;
    for (student, items) in pending_by_student(today, commons).items() {
        box = boxes.get(student);
        if box is None or not box.enabled {
            mark_emailed(items);
            continue;
        }
        subject = "New match on UArrived"
            if len(items) == 1
            else f"{len(items)} new matches on UArrived";
        ok = False;
        try {
            ok = send(box.email, subject, digest_body(items, box.language));
        } except Exception {
            ok = False;
        }
        if ok {
            mark_emailed(items);
            sent += 1;
        }
    }
    return sent;
}

glob NOTIFY_REPLY_KINDS: list[str] = ["question", "offer", "answer"];

"""Unseen, un-emailed questions, offers and answers, grouped by the student they are for.
Reactions never email; they only show as counts."""
def pending_replies(commons: any = None) -> dict[str, list[Reply]] {
    out: dict[str, list[Reply]] = {};
    for r in all_replies(commons) {
        if r.kind in NOTIFY_REPLY_KINDS and not r.emailed and not r.seen_by_to {
            out.setdefault(r.to_root, []).append(r);
        }
    }
    return out;
}

def reply_line(r: Reply, titles: dict[str, str]) -> str {
    title = titles.get(r.post_id, "your message");
    if r.kind == "offer" {
        amount = f"${r.offer_price:,.0f}" if r.offer_price is not None else "an offer";
        return f"- {amount} offered on \"{title}\"";
    }
    return f"- A question about \"{title}\""
        if r.kind == "question"
        else f"- An answer about \"{title}\"";
}

"""One email per student listing new replies to them (never the reply text itself)."""
def reply_sweep(commons: any = None) -> int {
    boxes: dict[str, Mailbox] = {
        m.owner_root: m for m in [commons_or_shared(commons)-->][?:Mailbox]
    };
    titles: dict[str, str] = {jid(p): p.title for p in all_posts(commons)};
    base = os.environ.get("UARRIVED_PUBLIC_URL", "http://localhost:8000");
    sent = 0;
    for (student, items) in pending_replies(commons).items() {
        box = boxes.get(student);
        ok = False;
        if box is not None and box.enabled {
            body = "\n".join(
                ["You have new replies on UArrived:", ""]
                    + [reply_line(r, titles) for r in items]
                    + [
                        "",
                        f"Open them: {base}/market",
                        "",
                        "Turn these emails off in Profile."
                    ]
            );
            try {
                ok = send(box.email, "New replies on UArrived", body);
            } except Exception {
                ok = False;
            }
            sent += 1 if ok else 0;
        }
        if ok or box is None or not box.enabled {
            for r in items {
                r.emailed = True;
            }
        }
    }
    return sent;
}

"""One email per student listing new topic-group invites (group name and why they were invited)."""
def invite_sweep(commons: any = None) -> int {
    shared = commons_or_shared(commons);
    boxes: dict[str, Mailbox] = {m.owner_root: m for m in [shared-->][?:Mailbox]};
    names: dict[str, str] = {jid(g): g.name for g in [shared-->][?:ChatGroup]};
    pending: dict[str, list[Invite]] = {};
    for i in [shared-->][?:Invite] {
        if i.status == "pending" and not i.emailed {
            pending.setdefault(i.invitee_root, []).append(i);
        }
    }
    base = os.environ.get("UARRIVED_PUBLIC_URL", "http://localhost:8000");
    sent = 0;
    for (student, items) in pending.items() {
        box = boxes.get(student);
        ok = False;
        if box is not None and box.enabled {
            lines = ["The UArrived assistant invited you to a group:", ""];
            for i in items {
                lines.append(f"- \"{names.get(i.group_id, 'A group')}\"");
                lines.append(f"  {i.reason}");
            }
            lines.extend(
                [
                    "",
                    f"Join or dismiss: {base}/market",
                    "",
                    "Turn these emails off in Profile."
                ]
            );
            subject = "You're invited to a group on UArrived"
                if len(items) == 1
                else f"{len(items)} group invites on UArrived";
            try {
                ok = send(box.email, subject, "\n".join(lines));
            } except Exception {
                ok = False;
            }
            sent += 1 if ok else 0;
        }
        if ok or box is None or not box.enabled {
            for i in items {
                i.emailed = True;
            }
        }
    }
    return sent;
}

@schedule(trigger=ScheduleTrigger.STATIC, interval=NOTIFY_INTERVAL_SECONDS)
def email_sweep {
    sweep(clock_today());
    reply_sweep();
    invite_sweep();
}

"""How many of the caller's suggestions are unread (the inbox badge)."""
def unread_count(today: str) -> int {
    me = jid(root);
    posts: dict[str, Post] = {jid(p): p for p in all_posts()};
    n = 0;
    for s in all_suggestions() {
        if suggestion_status(s, posts.get(s.post_a), posts.get(s.post_b), today)
            != "open" {
            continue;
        }
        if (s.root_a == me and not s.seen_a) or (s.root_b == me and not s.seen_b) {
            n += 1;
        }
    }
    n += len(
        [
            r
            for r in all_replies()
            if r.to_root == me and r.kind in NOTIFY_REPLY_KINDS and not r.seen_by_to
        ]
    );
    n += len(
        [
            i
            for i in [root.shared-->][?:Invite]
            if i.invitee_root == me and i.status == "pending"
        ]
    );
    return n;
}

"""Mark the caller's side of these suggestions as seen. Unknown ids are ignored."""
def mark_seen(ids: list[str]) -> int {
    me = jid(root);
    wanted = set(ids);
    n = 0;
    for s in all_suggestions() {
        if jid(s) not in wanted {
            continue;
        }
        if s.root_a == me {
            s.seen_a = True;
            n += 1;
        } elif s.root_b == me {
            s.seen_b = True;
            n += 1;
        }
    }
    return n;
}

def:protect unread_suggestions -> int {
    if verified_profile() is None {
        return 0;
    }
    return unread_count(clock_today());
}

def:protect mark_suggestions_seen(suggestion_ids: list[str]) -> int {
    if verified_profile() is None {
        return 0;
    }
    return mark_seen(suggestion_ids);
}
