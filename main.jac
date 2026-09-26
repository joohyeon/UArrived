"""UArrived - entry point.

Serves every endpoint module imported here, plus the client app. A server module that is not
imported here is not served.
"""

import from core.auth { start_verification, confirm_verification, my_verification }
import from core.profile { get_my_profile, update_my_profile }
import from market.drafting { draft_from_message }
import from market.suggestions { list_my_suggestions, stop_suggestions }
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
import from core.screens.welcome { Welcome }

def:pub app -> JsxElement {
    <Welcome/>
}
