"""UArrived - entry point.

Serves every endpoint module imported here, plus the client app. A server module that is not
imported here is not served.
"""

import from core.auth { start_verification, confirm_verification, my_verification }
import from core.profile { get_my_profile, update_my_profile }

# Client-side UI
import from core.screens.welcome { Welcome }

def:pub app -> JsxElement {
    <Welcome/>
}
