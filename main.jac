"""UMadeIt - entry point.

Serves every endpoint module imported here, plus the client app. A server module that is not
imported here is not served.
"""

import from core.auth {
    start_verification,
    confirm_verification,
    my_verification,
    claim_umich_account
}
import from core.profile { get_my_profile, update_my_profile }
import from market.drafting { draft_from_message }
import from market.suggestions { list_my_suggestions, stop_suggestions }
import from market.feed { for_you_feed, heartbeat }
import from journey.prompts { my_journey_prompts }
import from journey.walkers {
    my_journey,
    toggle_task_step,
    mark_task_done,
    reopen_task
}
import from journey.events { upcoming_events, preview_events }
import from journey.events_refresh { scheduled_events_refresh }
import from journey.interests { my_interests, has_interests, set_interests }
import from journey.guide { ask_about_task, translate_journey_texts }
import from market.decide { help_me_decide }
import from market.themes {
    list_groups_for_me,
    group_view,
    post_in_group,
    answer_group_followup,
    join_group,
    leave_group,
    untag_group_message,
    close_group_post,
    answer_detail
}
import from market.threads {
    start_thread,
    get_thread,
    list_threads,
    thread_send,
    thread_action
}
import from market.messages {
    send_market_message,
    market_stream,
    message_thread,
    react_to_message,
    ask_about_message,
    offer_on_message,
    answer_reply,
    accept_reply,
    confirm_available,
    apply_assistant_choice,
    close_message,
    nudge_sweep
}
import from market.moderation {
    report_post,
    report_chat,
    block_in_suggestion,
    block_in_chat,
    moderation_queue,
    suspend_poster,
    hide_post,
    resolve_report
}
import from market.drafting { ride_prefill }
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
import from core.screens.landing { Landing }
import from core.screens.account { Account }
import from ui.components.gallery { Gallery }
import from market.screens.preview { MarketPreview }
import from market.screens.inbox { MatchesInbox }
import from market.screens.groups { GroupList, GroupChat }
import from market.screens.compose { Compose }
import from market.screens.chats { ChatList, ChatScreen }
import from market.screens.mine { MyPosts, ForYou }
import from market.screens.decide { Compare }
import from market.screens.moderate { Moderate }
import from market.screens.common { current_path }
import from journey.screens.today { Today }
import from journey.screens.journey { JourneyHome }
import from journey.screens.task { TaskDetail }
import from journey.screens.ask { AskGuide }
import from journey.screens.events { Events }
import from journey.screens.onboarding { Onboarding }
import from journey.screens.interests { InterestsGate }

"""Path-based routing; every market page also works as a direct link (e.g. from an email)."""
def:pub app -> JsxElement {
    path = current_path().rstrip("/") or "/";
    if path == "/ui" {
        return <Gallery/>;
    }
    if path == "/market/preview" {
        return <MarketPreview/>;
    }
    if (
        path.startswith("/market")
        or path.startswith("/journey")
        or path in ["/today", "/profile", "/onboarding", "/interests", "/events"]
    )
        and not jacIsLoggedIn() {
        return <Welcome/>;
    }
    if path == "/" {
        return <Landing/>;
    }
    if path in ["/login", "/signup"] {
        return <Welcome/>;
    }
    if path == "/profile" {
        return <Account/>;
    }
    if path == "/today" {
        return <Today/>;
    }
    if path == "/onboarding" {
        return <Onboarding/>;
    }
    if path == "/interests" {
        return <InterestsGate/>;
    }
    if path == "/journey" {
        return <JourneyHome/>;
    }
    if path == "/journey/task" {
        return <TaskDetail/>;
    }
    if path == "/journey/ask" {
        return <AskGuide/>;
    }
    if path == "/events" {
        return <Events/>;
    }
    if path == "/market" {
        return <GroupList/>;
    }
    if path == "/market/g" {
        return <GroupChat/>;
    }
    if path == "/market/matches" {
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
    if path == "/market/compare" {
        return <Compare/>;
    }
    if path == "/market/moderate" {
        return <Moderate/>;
    }
    return <Welcome/>;
}
