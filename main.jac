"""UArrived - entry point.

Serves every endpoint module imported here, plus the client app. A server module that is not
imported here is not served.
"""

import from core.auth { start_verification, confirm_verification, my_verification }
import from core.profile { get_my_profile, update_my_profile }
import from market.drafting { draft_from_message }
import from market.suggestions { list_my_suggestions, stop_suggestions }
import from market.feed { for_you_feed, heartbeat }
import from market.notify { unread_suggestions, mark_suggestions_seen, email_sweep }
import from market.connect { connect, decline, list_my_chats, read_chat, send_message }
import from market.lifecycle {
    publish_post,
    edit_post,
    mark_post_done,
    renew_post,
    list_live_posts,
    list_my_posts
}

# Client-side UI
import from "@jac/runtime" { jacIsLoggedIn }
import from core.screens.welcome { Welcome }
import from ui.components.gallery { Gallery }
import from market.screens.inbox { MatchesInbox }
import from market.screens.compose { Compose }
import from market.screens.chats { ChatList, ChatScreen }
import from market.screens.mine { MyPosts, ForYou }
import from market.screens.common { current_path }

"""Path-based routing; every market page also works as a direct link (e.g. from an email)."""
def:pub app -> JsxElement {
    path = current_path().rstrip("/") or "/";
    if path == "/ui" {
        return <Gallery/>;
    }
    if path.startswith("/market") and not jacIsLoggedIn() {
        return <Welcome/>;
    }
    if path == "/market" {
        return <MatchesInbox/>;
    }
    if path == "/market/new" {
        return <Compose/>;
    }
    if path == "/market/chats" {
        return <ChatList/>;
    }
    if path == "/market/chat" {
        return <ChatScreen/>;
    }
    if path == "/market/mine" {
        return <MyPosts/>;
    }
    if path == "/market/feed" {
        return <ForYou/>;
    }
    return <Welcome/>;
}
